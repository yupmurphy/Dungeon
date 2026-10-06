class_name FloorGenerator
extends RefCounted
## Builds a FloorLayout from FloorData + seed. Same seed => same floor.
##
## 1. Zones. The first CLOSED region (the hub, Goblin Galleries) is a wobbly disc in the middle of the map,
##    closed by a rock ring. The OPEN regions share the rest as angular sectors around it; their order,
##    sizes and rotation change with the seed, and the borders between them meander (noise), so open
##    zones blend into each other without walls. Every cell belongs to a zone, there is no empty space.
## 2. Terrain. The hub becomes organic caves (cellular automata). Open zones are open ground with
##    clumps of rock (noise). The map's edge is a band of rock.
## 3. Gates. One passage through the hub's ring per open zone, in the middle of that zone's sector.
## 4. Boss arena. An enclosed ellipse at the outer edge of a random open zone, one entrance facing the
##    middle of the map, the portal at the far (outer) end.
## 5. Accessibility. Tiny pockets are filled; every other cave/pocket is joined to the start by digging
##    the cheapest tunnel through rock (never through the hub ring, the arena walls or the map edge).
## Then FloorPopulator decides what spawns where.

const CAVE_FILL: float = 0.45
const CAVE_STEPS: int = 5
const START_CAVE_RADIUS: float = 8.0
## Floor pockets smaller than this become rock instead of getting a tunnel.
const MIN_POCKET: int = 30
const OPEN_ROCK_FREQUENCY: float = 0.03
## Open ground is rock where the noise is above this (0..1).
const OPEN_ROCK_THRESHOLD: float = 0.7
const WOBBLE_FREQUENCY: float = 0.006
const BORDER_FREQUENCY: float = 0.04
## How many angles the hub edge is sampled at.
const HUB_EDGE_SAMPLES: int = 720
## How deep the gate passage reaches into the hub.
const GATE_INNER_DEPTH: float = 24.0
const CLEARING_RADIUS: float = 5.0
const ENTRANCE_HALF_WIDTH: int = 2
## Boss arena: the portal sits this far in front of the back wall.
const PORTAL_WALL_DISTANCE: float = 4.0
## The arena may drift this share of its zone's width away from the zone's middle.
const BOSS_ANGLE_JITTER: float = 0.15
const UNREACHED: int = 1 << 30


static func generate(data: FloorData, seed_value: int) -> FloorLayout:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var layout := FloorLayout.new()
	layout.setup(data.map_size, seed_value, data.regions.size())
	layout.chunk_size = data.chunk_size

	var hub_slot: int = -1
	var open_slots: Array[int] = []
	for slot in data.regions.size():
		if data.regions[slot].kind == RegionData.Kind.OPEN:
			open_slots.append(slot)
		elif hub_slot < 0:
			hub_slot = slot
	assert(hub_slot >= 0 and not open_slots.is_empty(), "A floor needs one CLOSED and at least one OPEN region")
	layout.hub_slot = hub_slot

	var sectors: Array[Dictionary] = _plan_sectors(data, open_slots, rng)
	var hub_edge: PackedFloat32Array = _hub_edge(data, layout, seed_value)
	var no_dig := PackedByteArray()
	no_dig.resize(layout.size.x * layout.size.y)
	no_dig.fill(0)

	_assign_zones(data, layout, sectors, hub_edge, no_dig, seed_value)
	_carve_caves(data, layout, hub_edge, rng)
	_carve_gates(data, layout, sectors, hub_edge)
	_carve_boss_arena(data, layout, sectors, no_dig, rng)
	_merge_zone_islands(layout)
	layout.start_cell = layout.center
	_connect_everything(layout, no_dig)
	FloorPopulator.populate(layout, data)
	return layout


# --- 1. Zones ---

## Open zones as angular sectors: [{slot, from, to, mid}] in radians, `from` may be any angle.
static func _plan_sectors(data: FloorData, open_slots: Array[int], rng: RandomNumberGenerator) -> Array[Dictionary]:
	var order: Array = open_slots.duplicate()
	_shuffle(order, rng)
	var shares: Array[float] = []
	var total: float = 0.0
	for slot in order:
		var share: float = rng.randf_range(data.open_zone_share_min, data.open_zone_share_max)
		shares.append(share)
		total += share
	var angle: float = rng.randf() * TAU
	var sectors: Array[Dictionary] = []
	for i in order.size():
		var width: float = shares[i] / total * TAU
		sectors.append({"slot": order[i], "from": angle, "to": angle + width, "mid": angle + width / 2.0})
		angle += width
	return sectors


## Hub radius per angle (HUB_EDGE_SAMPLES samples), wobbling smoothly all the way around.
static func _hub_edge(data: FloorData, layout: FloorLayout, seed_value: int) -> PackedFloat32Array:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.02
	var base: float = minf(layout.size.x, layout.size.y) * 0.5 * data.hub_radius
	var edge := PackedFloat32Array()
	edge.resize(HUB_EDGE_SAMPLES)
	for i in HUB_EDGE_SAMPLES:
		var a: float = TAU * i / HUB_EDGE_SAMPLES
		# Sampling noise on a circle keeps the edge seamless where the angle wraps around.
		var n: float = noise.get_noise_2d(cos(a) * 60.0, sin(a) * 60.0)
		edge[i] = base + clampf(n * 1.6, -1.0, 1.0) * data.hub_radius_variation
	return edge


static func _hub_radius(hub_edge: PackedFloat32Array, angle: float) -> float:
	var i: int = posmod(roundi(angle / TAU * HUB_EDGE_SAMPLES), HUB_EDGE_SAMPLES)
	return hub_edge[i]


static func _assign_zones(data: FloorData, layout: FloorLayout, sectors: Array[Dictionary],
		hub_edge: PackedFloat32Array, no_dig: PackedByteArray, seed_value: int) -> void:
	var w: int = layout.size.x
	var h: int = layout.size.y
	var wobble: PackedByteArray = _noise_bytes(seed_value + 1, WOBBLE_FREQUENCY, w, h)
	var rocks: PackedByteArray = _noise_bytes(seed_value + 2, OPEN_ROCK_FREQUENCY, w, h)
	var border: PackedByteArray = _noise_bytes(seed_value + 3, BORDER_FREQUENCY, w, h)
	var cells: PackedByteArray = layout.cells_raw()
	var slots: PackedByteArray = layout.slots_raw()
	var rock_limit: int = roundi(OPEN_ROCK_THRESHOLD * 255.0)
	var center := Vector2(layout.center) + Vector2(0.5, 0.5)
	var first_angle: float = sectors[0]["from"]

	for y in h:
		for x in w:
			var i: int = y * w + x
			var offset := Vector2(x + 0.5, y + 0.5) - center
			var distance: float = offset.length()
			var angle: float = offset.angle()
			var hub_r: float = _hub_radius(hub_edge, angle)
			if distance < hub_r + data.hub_ring:
				slots[i] = layout.hub_slot
				if distance >= hub_r - 1.0:
					no_dig[i] = 1  # the ring that closes the hub
				continue
			# Open zones: wobbled angle -> sector.
			var bent: float = angle + (wobble[i] / 127.5 - 1.0) * data.open_zone_wobble
			var t: float = fposmod(bent - first_angle, TAU) + first_angle
			var slot: int = sectors[sectors.size() - 1]["slot"]
			for sector in sectors:
				if t < sector["to"]:
					slot = sector["slot"]
					break
			slots[i] = slot
			var edge_distance: int = mini(mini(x, y), mini(w - 1 - x, h - 1 - y))
			var border_width: float = lerpf(data.border_min, data.border_max, border[i] / 255.0)
			if edge_distance < border_width:
				no_dig[i] = 1
			elif rocks[i] < rock_limit:
				cells[i] = 1
	layout.set_cells_raw(cells)


## FastNoiseLite as a byte per cell (0..255 for -1..1); much faster than sampling cell by cell.
static func _noise_bytes(noise_seed: int, frequency: float, w: int, h: int) -> PackedByteArray:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = noise_seed
	noise.frequency = frequency
	var image: Image = noise.get_image(w, h, false, false, true)
	image.convert(Image.FORMAT_L8)
	return image.get_data()


# --- 2. Hub caves ---

static func _carve_caves(data: FloorData, layout: FloorLayout, hub_edge: PackedFloat32Array,
		rng: RandomNumberGenerator) -> void:
	var w: int = layout.size.x
	var cells: PackedByteArray = layout.cells_raw()
	var center := Vector2(layout.center) + Vector2(0.5, 0.5)
	var reach: int = ceili(hub_edge[0] + data.hub_radius_variation + 2)
	var area := Rect2i(layout.center - Vector2i(reach, reach), Vector2i(reach, reach) * 2).intersection(
		Rect2i(Vector2i(1, 1), layout.size - Vector2i(2, 2)))

	# Cells inside the hub (not the ring) start as random rock/floor.
	var inside := PackedByteArray()
	inside.resize(cells.size())
	inside.fill(0)
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var offset := Vector2(x + 0.5, y + 0.5) - center
			if offset.length() < _hub_radius(hub_edge, offset.angle()) - 1.0:
				var i: int = y * w + x
				inside[i] = 1
				cells[i] = 1 if rng.randf() >= CAVE_FILL else 0

	# Smooth: a cell becomes rock with 5+ rock neighbors, floor with 3 or fewer.
	for step in CAVE_STEPS:
		var next: PackedByteArray = cells.duplicate()
		for y in range(area.position.y, area.end.y):
			for x in range(area.position.x, area.end.x):
				var i: int = y * w + x
				if inside[i] == 0:
					continue
				var floors: int = cells[i - w - 1] + cells[i - w] + cells[i - w + 1] + cells[i - 1] \
					+ cells[i + 1] + cells[i + w - 1] + cells[i + w] + cells[i + w + 1]
				if floors <= 3:
					next[i] = 0
				elif floors >= 5:
					next[i] = 1
		cells = next

	# A guaranteed open cave around the start.
	_carve_disc(layout, cells, center, START_CAVE_RADIUS)
	layout.set_cells_raw(cells)


static func _carve_disc(layout: FloorLayout, cells: PackedByteArray, at: Vector2, radius: float,
		protect: bool = false) -> void:
	var r: int = ceili(radius)
	var base := Vector2i(at.floor())
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var cell: Vector2i = base + Vector2i(dx, dy)
			if not layout.in_bounds(cell.x, cell.y) or (Vector2(cell) + Vector2(0.5, 0.5)).distance_to(at) > radius:
				continue
			cells[cell.y * layout.size.x + cell.x] = 1
			if protect:
				layout.protect(cell.x, cell.y)


# --- 3. Gates ---

static func _carve_gates(data: FloorData, layout: FloorLayout, sectors: Array[Dictionary],
		hub_edge: PackedFloat32Array) -> void:
	var cells: PackedByteArray = layout.cells_raw()
	var center := Vector2(layout.center) + Vector2(0.5, 0.5)
	for sector in sectors:
		var angle: float = sector["mid"]
		var direction := Vector2.from_angle(angle)
		var hub_r: float = _hub_radius(hub_edge, angle)
		var outer: float = hub_r + data.hub_ring
		var distance: float = hub_r - GATE_INNER_DEPTH
		while distance <= outer + 2.0:
			# Protected from the ring on, so no prop or tunnel ever blocks the passage.
			_carve_disc(layout, cells, center + direction * distance, data.gate_width / 2.0, distance >= hub_r - 3.0)
			distance += 1.0
		var outside: Vector2 = center + direction * (outer + CLEARING_RADIUS)
		_carve_disc(layout, cells, outside, CLEARING_RADIUS)
		var gate := FloorLayout.Gate.new()
		gate.cell = Vector2i((center + direction * (hub_r + data.hub_ring / 2.0)).floor())
		gate.outside = Vector2i(outside.floor())
		gate.slot = sector["slot"]
		layout.gates.append(gate)
	layout.set_cells_raw(cells)


# --- 4. Boss arena ---

static func _carve_boss_arena(data: FloorData, layout: FloorLayout, sectors: Array[Dictionary],
		no_dig: PackedByteArray, rng: RandomNumberGenerator) -> void:
	var sector: Dictionary = sectors[rng.randi() % sectors.size()]
	var width: float = sector["to"] - sector["from"]
	var angle: float = sector["mid"] + rng.randf_range(-BOSS_ANGLE_JITTER, BOSS_ANGLE_JITTER) * width
	var direction := Vector2.from_angle(angle)
	var radii := Vector2(data.boss_arena_radii)
	var wall: float = data.boss_arena_wall
	var outer_radii: Vector2 = radii + Vector2(wall, wall)

	# As far out as possible: the arena's outer wall just inside the map-edge rock.
	var half := Vector2(layout.size) / 2.0
	var margin: Vector2 = outer_radii + Vector2(data.border_max + 2, data.border_max + 2)
	var reach_x: float = (half.x - margin.x) / maxf(absf(direction.x), 0.001)
	var reach_y: float = (half.y - margin.y) / maxf(absf(direction.y), 0.001)
	var arena_center: Vector2 = Vector2(layout.center) + Vector2(0.5, 0.5) + direction * minf(reach_x, reach_y)
	layout.boss_zone = sector["slot"]
	layout.boss_center = Vector2i(arena_center.floor())

	var cells: PackedByteArray = layout.cells_raw()
	var slots: PackedByteArray = layout.slots_raw()
	var w: int = layout.size.x
	var box := Rect2i(Vector2i((arena_center - outer_radii).floor()), Vector2i((outer_radii * 2.0).ceil()) + Vector2i.ONE)
	layout.boss_rect = box
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			var offset := Vector2(x + 0.5, y + 0.5) - arena_center
			if (offset / outer_radii).length_squared() > 1.0:
				continue
			var i: int = y * w + x
			slots[i] = layout.boss_slot
			if (offset / radii).length_squared() <= 1.0:
				cells[i] = 1
			else:
				cells[i] = 0
				no_dig[i] = 1

	# One entrance, facing the middle of the map; the portal at the opposite (outer) end.
	var inward: Vector2 = -direction
	var inner_reach: float = 1.0 / (inward / radii).length()
	var outer_reach: float = 1.0 / (inward / outer_radii).length()
	var distance: float = inner_reach - 2.0
	while distance <= outer_reach + 1.0:
		var at: Vector2 = arena_center + inward * distance
		for side in range(-ENTRANCE_HALF_WIDTH, ENTRANCE_HALF_WIDTH + 1):
			var cell := Vector2i((at + inward.orthogonal() * side).floor())
			if layout.in_bounds(cell.x, cell.y):
				cells[cell.y * w + cell.x] = 1
				layout.protect(cell.x, cell.y)
		distance += 0.5
	layout.boss_entrance = Vector2i((arena_center + inward * (inner_reach + wall / 2.0)).floor())
	_carve_disc(layout, cells, arena_center + inward * (outer_reach + CLEARING_RADIUS), CLEARING_RADIUS)
	layout.portal_cell = Vector2i((arena_center + direction * (inner_reach - PORTAL_WALL_DISTANCE)).floor())
	layout.set_cells_raw(cells)


## The meandering borders can leave small islands of one zone inside another. Every zone keeps only
## its biggest piece; the other pieces join the zone around them.
static func _merge_zone_islands(layout: FloorLayout) -> void:
	var w: int = layout.size.x
	var slots: PackedByteArray = layout.slots_raw()
	var piece := PackedInt32Array()
	piece.resize(slots.size())
	piece.fill(-1)
	var piece_cells: Array[PackedInt32Array] = []
	var biggest: Dictionary = {}  # slot -> piece id
	var stack := PackedInt32Array()
	for first in slots.size():
		if piece[first] >= 0:
			continue
		var id: int = piece_cells.size()
		var cells := PackedInt32Array([first])
		piece[first] = id
		stack.append(first)
		while not stack.is_empty():
			var i: int = stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			var x: int = i % w
			for j: int in [i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w, i + w]:
				if j >= 0 and j < slots.size() and piece[j] < 0 and slots[j] == slots[first]:
					piece[j] = id
					cells.append(j)
					stack.append(j)
		piece_cells.append(cells)
		var slot: int = slots[first]
		if not biggest.has(slot) or piece_cells[biggest[slot]].size() < cells.size():
			biggest[slot] = id
	for id in piece_cells.size():
		var cells: PackedInt32Array = piece_cells[id]
		var slot: int = slots[cells[0]]
		if biggest[slot] == id:
			continue
		# Adopt the slot of the first neighbor outside the island (never the hub or the arena,
		# whose borders are walls).
		var new_slot: int = slot
		for i in cells:
			var x: int = i % w
			for j: int in [i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w, i + w]:
				if j >= 0 and j < slots.size() and piece[j] != id and slots[j] != layout.hub_slot \
						and slots[j] != layout.boss_slot:
					new_slot = slots[j]
					break
			if new_slot != slot:
				break
		for i in cells:
			slots[i] = new_slot


# --- 5. Accessibility ---

## Fills tiny pockets, then joins every other floor pocket to the start with the cheapest tunnel
## (fewest rock cells dug). Cells marked in `no_dig` (hub ring, arena walls, map edge) are never dug,
## so the hub stays closed except for its gates and the arena keeps a single entrance.
static func _connect_everything(layout: FloorLayout, no_dig: PackedByteArray) -> void:
	var w: int = layout.size.x
	var cells: PackedByteArray = layout.cells_raw()
	var start: int = layout.start_cell.y * w + layout.start_cell.x

	var labels: PackedInt32Array = _label_pockets(layout, cells)
	var pocket_sizes: Dictionary = {}
	for label in labels:
		if label >= 0:
			pocket_sizes[label] = pocket_sizes.get(label, 0) + 1
	var start_label: int = labels[start]
	var protected: PackedByteArray = layout.protected_raw()
	for i in cells.size():
		var label: int = labels[i]
		if label >= 0 and label != start_label and pocket_sizes[label] < MIN_POCKET and protected[i] == 0:
			cells[i] = 0
			labels[i] = -1

	# Dial's algorithm: walking on floor is free, digging one rock cell costs 1.
	var cost := PackedInt32Array()
	cost.resize(cells.size())
	cost.fill(UNREACHED)
	var parent := PackedInt32Array()
	parent.resize(cells.size())
	parent.fill(-1)
	cost[start] = 0
	var buckets: Array[PackedInt32Array] = [PackedInt32Array([start])]
	var level: int = 0
	while level < buckets.size():
		var bucket: PackedInt32Array = buckets[level]
		var k: int = 0
		while k < bucket.size():
			var i: int = bucket[k]
			k += 1
			if cost[i] != level:
				continue
			var x: int = i % w
			for j: int in [i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w, i + w]:
				if j < 0 or j >= cells.size():
					continue
				var floor_cell: bool = cells[j] == 1
				if not floor_cell and no_dig[j] == 1:
					continue
				var next_cost: int = level + (0 if floor_cell else 1)
				if next_cost >= cost[j]:
					continue
				cost[j] = next_cost
				parent[j] = i
				if next_cost == level:
					bucket.append(j)
				else:
					while buckets.size() <= next_cost:
						buckets.append(PackedInt32Array())
					buckets[next_cost].append(j)
		buckets[level] = bucket
		level += 1

	# For each pocket not joined yet: dig back from its cheapest cell to the start.
	var entry: Dictionary = {}
	for i in cells.size():
		var label: int = labels[i]
		if label < 0 or label == start_label or cells[i] == 0:
			continue
		if not entry.has(label) or cost[i] < cost[entry[label]]:
			entry[label] = i
	for label: int in entry:
		var i: int = entry[label]
		if cost[i] == UNREACHED:
			continue
		while i >= 0:
			if cells[i] == 0:
				_dig(layout, cells, no_dig, i)
			i = parent[i]

	# Safety net: whatever is still unreachable (should not happen) becomes rock.
	labels = _label_pockets(layout, cells)
	start_label = labels[start]
	for i in cells.size():
		if labels[i] >= 0 and labels[i] != start_label:
			cells[i] = 0
	layout.set_cells_raw(cells)


## Digs one tunnel cell, widened to its 4 neighbors so tunnels are 3 tiles wide.
static func _dig(layout: FloorLayout, cells: PackedByteArray, no_dig: PackedByteArray, i: int) -> void:
	var w: int = layout.size.x
	cells[i] = 1
	var x: int = i % w
	for j: int in [i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w, i + w]:
		if j >= 0 and j < cells.size() and no_dig[j] == 0:
			cells[j] = 1


## Connected floor pockets (4-neighborhood): label per cell, -1 for rock.
static func _label_pockets(layout: FloorLayout, cells: PackedByteArray) -> PackedInt32Array:
	var w: int = layout.size.x
	var labels := PackedInt32Array()
	labels.resize(cells.size())
	labels.fill(-1)
	var next_label: int = 0
	var stack := PackedInt32Array()
	for seed_index in cells.size():
		if cells[seed_index] == 0 or labels[seed_index] >= 0:
			continue
		labels[seed_index] = next_label
		stack.append(seed_index)
		while not stack.is_empty():
			var i: int = stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			var x: int = i % w
			for j: int in [i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w, i + w]:
				if j >= 0 and j < cells.size() and cells[j] == 1 and labels[j] < 0:
					labels[j] = next_label
					stack.append(j)
		next_label += 1
	return labels


## Seeded Fisher-Yates (Array.shuffle() would use the global, unseeded RNG).
static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var temp: Variant = items[i]
		items[i] = items[j]
		items[j] = temp
