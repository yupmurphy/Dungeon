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
## Gate placement: angle step when scanning the hub edge, and how far out the zone is checked.
const GATE_SCAN_STEP: float = 0.004
const GATE_ZONE_CHECK_DEPTH: float = 25.0
const ENTRANCE_HALF_WIDTH: int = 2
## Boss arena: the portal sits this far in front of the back wall.
const PORTAL_WALL_DISTANCE: float = 4.0
## The arena may drift this share of its zone's width away from the zone's middle.
const BOSS_ANGLE_JITTER: float = 0.15
const UNREACHED: int = 1 << 30
## Zones are worked out per block of this many tiles (then refined per cell near the hub).
const ZONE_BLOCK: int = 4
## Max rounds of reassigning cut-off pieces next to the hub ring or the arena (usually done after 1-2).
const STRIP_PASSES: int = 6
## Max rounds of merging zone islands on the block grid.
const ISLAND_ROUNDS: int = 4
## Tunnels may be dug this far outside the hub ring and around the arena.
const DIG_MARGIN: int = 40


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

	timings.clear()
	var clock: int = Time.get_ticks_usec()
	var arena: Dictionary = _plan_boss_arena(data, layout, sectors, rng)
	var near_walls := PackedByteArray()
	var strip: PackedInt32Array = _assign_zones(data, layout, sectors, hub_edge, no_dig, seed_value, arena, near_walls)
	_carve_boss_arena(data, layout, arena, no_dig)
	_fix_strip(layout, no_dig, strip, near_walls)
	var clearing: Vector2i = arena["clearing"]
	layout.boss_zone = layout.slot_at(clearing.x, clearing.y)
	clock = _lap("zones+arena", clock)
	_carve_caves(data, layout, hub_edge, rng)
	clock = _lap("caves", clock)
	_carve_gates(data, layout, sectors, hub_edge, rng)
	clock = _lap("gates", clock)
	layout.start_cell = layout.center
	_connect_everything(data, layout, no_dig, hub_edge)
	clock = _lap("connect", clock)
	FloorPopulator.populate(layout, data)
	_lap("populate", clock)
	return layout


## Milliseconds per phase of the last generate() call, for performance checks.
static var timings: Dictionary = {}


static func _lap(phase: String, since: int) -> int:
	var now: int = Time.get_ticks_usec()
	timings[phase] = (now - since) / 1000.0
	return now


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
		edge[i] = base * (1.0 + clampf(n * 1.6, -1.0, 1.0) * data.hub_radius_variation)
	return edge


## Interpolated between samples, so the ring has no notches.
static func _hub_radius(hub_edge: PackedFloat32Array, angle: float) -> float:
	var position: float = fposmod(angle / TAU, 1.0) * HUB_EDGE_SAMPLES
	var i: int = int(position) % HUB_EDGE_SAMPLES
	return lerpf(hub_edge[i], hub_edge[(i + 1) % HUB_EDGE_SAMPLES], position - floorf(position))


@warning_ignore("integer_division")
static func _assign_zones(data: FloorData, layout: FloorLayout, sectors: Array[Dictionary],
		hub_edge: PackedFloat32Array, no_dig: PackedByteArray, seed_value: int, arena: Dictionary,
		near_walls: PackedByteArray) -> PackedInt32Array:
	var w: int = layout.size.x
	var h: int = layout.size.y
	var bw: int = ceili(float(w) / ZONE_BLOCK)
	var open_slots: PackedByteArray = _open_zone_blocks(data, layout, sectors, hub_edge, seed_value, arena,
		near_walls)
	var rocks: PackedByteArray = _noise_bytes(seed_value + 2, OPEN_ROCK_FREQUENCY, w, h)
	var border: PackedByteArray = _noise_bytes(seed_value + 3, BORDER_FREQUENCY, w, h)
	var cells: PackedByteArray = layout.cells_raw()
	var slots: PackedByteArray = layout.slots_raw()
	var rock_limit: int = roundi(OPEN_ROCK_THRESHOLD * 255.0)
	var cx: float = layout.center.x + 0.5
	var cy: float = layout.center.y + 0.5
	var hub_min: float = Array(hub_edge).min()
	var hub_max: float = Array(hub_edge).max()
	# Squared distances: cells clearly inside / outside the hub skip the exact (angle based) test.
	var surely_inside: float = (hub_min - 1.0) * (hub_min - 1.0)
	var surely_outside: float = (hub_max + data.hub_ring) * (hub_max + data.hub_ring)
	var border_reach: int = data.border_max
	var hub_slot: int = layout.hub_slot
	# Open-zone cells in blocks that touch the hub or the arena; their zone is checked cell by cell later.
	var strip := PackedInt32Array()

	for y in h:
		var dy: float = y + 0.5 - cy
		var block_row: int = (y / ZONE_BLOCK) * bw
		for x in w:
			var i: int = y * w + x
			var dx: float = x + 0.5 - cx
			var distance_squared: float = dx * dx + dy * dy
			if distance_squared < surely_inside:
				slots[i] = hub_slot
				continue
			if distance_squared < surely_outside:
				var distance: float = sqrt(distance_squared)
				var hub_r: float = _hub_radius(hub_edge, atan2(dy, dx))
				if distance < hub_r + data.hub_ring:
					slots[i] = hub_slot
					if distance >= hub_r - 1.0:
						no_dig[i] = 1  # the ring that closes the hub
					continue
			var block: int = block_row + x / ZONE_BLOCK
			slots[i] = open_slots[block]
			if near_walls[block] == 1:
				strip.append(i)
			var edge_distance: int = mini(mini(x, y), mini(w - 1 - x, h - 1 - y))
			if edge_distance < border_reach and edge_distance < lerpf(data.border_min, data.border_max, border[i] / 255.0):
				no_dig[i] = 1
			elif rocks[i] < rock_limit:
				cells[i] = 1
	layout.set_cells_raw(cells)
	return strip


## Blocks away from the hub and the arena are already clean (islands merged on the block grid, and whole
## blocks always connect to each other). Only the strip of cells in blocks that touch the hub ring or the
## arena can hold pieces cut off from their zone. Each strip piece must touch a clean cell of its own zone;
## otherwise it joins the zone next to it (or, with no open zone next to it, becomes rock of the hub or
## arena it touches). Repeated until nothing changes.
@warning_ignore("integer_division")
static func _fix_strip(layout: FloorLayout, no_dig: PackedByteArray, strip: PackedInt32Array,
		near_walls: PackedByteArray) -> void:
	var cells: PackedByteArray = layout.cells_raw()
	var slots: PackedByteArray = layout.slots_raw()
	var w: int = layout.size.x
	var bw: int = ceili(float(w) / ZONE_BLOCK)
	var hub_slot: int = layout.hub_slot
	var boss_slot: int = layout.boss_slot
	var piece := PackedInt32Array()
	piece.resize(slots.size())
	for pass_index in STRIP_PASSES:
		piece.fill(-1)
		var changed: bool = false
		for first in strip:
			if piece[first] >= 0 or slots[first] == hub_slot or slots[first] == boss_slot:
				continue
			var slot: int = slots[first]
			var id: int = first
			var members := PackedInt32Array([first])
			piece[first] = id
			var anchored: bool = false
			var neighbor_slots: Dictionary = {}
			var fixed_neighbor: int = hub_slot
			var k: int = 0
			while k < members.size():
				var i: int = members[k]
				k += 1
				for j in _neighbors(i, w, slots.size()):
					if j < 0:
						continue
					if slots[j] == hub_slot or slots[j] == boss_slot:
						fixed_neighbor = slots[j]
						continue
					var clean: bool = near_walls[(j / w / ZONE_BLOCK) * bw + (j % w) / ZONE_BLOCK] == 0
					if slots[j] == slot:
						if clean:
							anchored = true
						elif piece[j] < 0:
							piece[j] = id
							members.append(j)
					else:
						neighbor_slots[slots[j]] = neighbor_slots.get(slots[j], 0) + 1
			if anchored:
				continue
			changed = true
			var best: int = fixed_neighbor
			var best_count: int = 0
			for other: int in neighbor_slots:
				if neighbor_slots[other] > best_count:
					best = other
					best_count = neighbor_slots[other]
			for i in members:
				slots[i] = best
				if best == hub_slot or best == boss_slot:
					cells[i] = 0
					no_dig[i] = 1
		if not changed:
			break
	layout.set_cells_raw(cells)


## Open zone per ZONE_BLOCK x ZONE_BLOCK block: wobbled angle -> sector. Blocks are cheap to compute and
## to clean up: islands of a zone inside another zone are merged here, on the small block grid.
static func _open_zone_blocks(data: FloorData, layout: FloorLayout, sectors: Array[Dictionary],
		hub_edge: PackedFloat32Array, seed_value: int, arena: Dictionary, near_walls: PackedByteArray) -> PackedByteArray:
	var bw: int = ceili(float(layout.size.x) / ZONE_BLOCK)
	var bh: int = ceili(float(layout.size.y) / ZONE_BLOCK)
	var wobble: PackedByteArray = _noise_bytes(seed_value + 1, WOBBLE_FREQUENCY * ZONE_BLOCK, bw, bh)
	var ends := PackedFloat32Array()
	var sector_slots := PackedByteArray()
	for sector in sectors:
		ends.append(sector["to"])
		sector_slots.append(sector["slot"])
	var first_angle: float = sectors[0]["from"]
	var center := Vector2(layout.center) + Vector2(0.5, 0.5)
	var blocks := PackedByteArray()
	blocks.resize(bw * bh)
	# Blocks that touch the hub (with its ring) or the arena are left out of the island merge: only some of
	# their cells are open zone, so they can't be trusted to connect. _fix_strip checks those cells one by one.
	var touch_margin: float = data.hub_ring + ZONE_BLOCK * 0.75 + 1.0
	var arena_center: Vector2 = arena["center"]
	var arena_reach: Vector2 = Vector2(data.boss_arena_radii) \
		+ Vector2.ONE * (data.boss_arena_wall + ZONE_BLOCK * 0.75 + 1.0)
	near_walls.resize(bw * bh)
	for by in bh:
		for bx in bw:
			var b: int = by * bw + bx
			var middle: Vector2 = (Vector2(bx, by) + Vector2(0.5, 0.5)) * ZONE_BLOCK
			var offset: Vector2 = middle - center
			var angle: float = offset.angle()
			var near_hub: bool = offset.length() < _hub_radius(hub_edge, angle) + touch_margin
			var near_arena: bool = ((middle - arena_center) / arena_reach).length_squared() <= 1.0
			near_walls[b] = 1 if near_hub or near_arena else 0
			var bent: float = angle + (wobble[b] / 127.5 - 1.0) * data.open_zone_wobble
			var t: float = fposmod(bent - first_angle, TAU) + first_angle
			var slot: int = sector_slots[sector_slots.size() - 1]
			for s in ends.size():
				if t < ends[s]:
					slot = sector_slots[s]
					break
			blocks[b] = slot
	# An island may first join a neighbor that is an island itself, so repeat until every zone is one piece.
	for round_index in ISLAND_ROUNDS:
		if not _merge_islands(blocks, near_walls, bw):
			break
	return blocks


## Every zone keeps only its biggest piece on the block grid; the other pieces join a neighboring zone.
## Returns true if anything changed.
static func _merge_islands(blocks: PackedByteArray, ignored: PackedByteArray, bw: int) -> bool:
	var changed: bool = false
	var piece := PackedInt32Array()
	piece.resize(blocks.size())
	piece.fill(-1)
	var pieces: Array[PackedInt32Array] = []
	var biggest: Dictionary = {}  # slot -> piece id
	for first in blocks.size():
		if piece[first] >= 0 or ignored[first] == 1:
			continue
		var id: int = pieces.size()
		var members := PackedInt32Array([first])
		piece[first] = id
		var k: int = 0
		while k < members.size():
			var i: int = members[k]
			k += 1
			for j in _neighbors(i, bw, blocks.size()):
				if j >= 0 and piece[j] < 0 and ignored[j] == 0 and blocks[j] == blocks[first]:
					piece[j] = id
					members.append(j)
		pieces.append(members)
		var slot: int = blocks[first]
		if not biggest.has(slot) or pieces[biggest[slot]].size() < members.size():
			biggest[slot] = id
	for id in pieces.size():
		var members: PackedInt32Array = pieces[id]
		var slot: int = blocks[members[0]]
		if biggest[slot] == id:
			continue
		var new_slot: int = slot
		for i in members:
			for j in _neighbors(i, bw, blocks.size()):
				if j >= 0 and piece[j] != id and ignored[j] == 0:
					new_slot = blocks[j]
					break
			if new_slot != slot:
				break
		if new_slot != slot:
			changed = true
		for i in members:
			blocks[i] = new_slot
	return changed


## The 4 neighbors of index i on a grid `w` wide (-1 where outside).
static func _neighbors(i: int, w: int, total: int) -> PackedInt32Array:
	var x: int = i % w
	return PackedInt32Array([i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1,
		i - w, i + w if i + w < total else -1])


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
	var reach: int = 0
	for radius in hub_edge:
		reach = maxi(reach, ceili(radius) + 2)
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
		hub_edge: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	var cells: PackedByteArray = layout.cells_raw()
	for sector in sectors:
		for angle in _gate_angles(data, layout, sector, hub_edge, rng):
			_carve_gate(data, layout, cells, sector["slot"], angle, hub_edge)
	layout.set_cells_raw(cells)


## 2-3 angles (FloorData.gates_per_zone) spread over the part of the hub's edge that really faces the zone
## (the zone borders meander, so the sector's nominal angles are not enough), at least gate_spacing apart.
static func _gate_angles(data: FloorData, layout: FloorLayout, sector: Dictionary,
		hub_edge: PackedFloat32Array, rng: RandomNumberGenerator) -> Array[float]:
	var center := Vector2(layout.center) + Vector2(0.5, 0.5)
	var slot: int = sector["slot"]
	# Longest run of angles whose way out lands well inside the zone.
	var best_from: float = sector["mid"]
	var best_span: float = 0.0
	var run_from: float = -1.0
	var angle: float = sector["from"]
	while angle <= sector["to"] + GATE_SCAN_STEP:
		var outer: float = _hub_radius(hub_edge, angle) + data.hub_ring
		var ok: bool = angle <= sector["to"]
		for depth: float in [CLEARING_RADIUS, GATE_ZONE_CHECK_DEPTH]:
			var probe := Vector2i((center + Vector2.from_angle(angle) * (outer + depth)).floor())
			ok = ok and layout.slot_at(probe.x, probe.y) == slot
		if ok and run_from < 0.0:
			run_from = angle
		elif not ok and run_from >= 0.0:
			if angle - run_from > best_span:
				best_span = angle - run_from
				best_from = run_from
			run_from = -1.0
		angle += GATE_SCAN_STEP
	var radius: float = _hub_radius(hub_edge, best_from + best_span / 2.0)
	var count: int = rng.randi_range(data.gates_per_zone.x, data.gates_per_zone.y)
	# Fewer gates if the shared edge is too short to keep them apart.
	# (Neighbors end up at least 0.8 slice apart because of the jitter below.)
	while count > 1 and best_span * radius * 0.8 < data.gate_spacing * count:
		count -= 1
	var angles: Array[float] = []
	var slice: float = best_span / count
	for i in count:
		angles.append(best_from + slice * (i + 0.5) + rng.randf_range(-0.1, 0.1) * slice)
	return angles


static func _carve_gate(data: FloorData, layout: FloorLayout, cells: PackedByteArray, slot: int,
		angle: float, hub_edge: PackedFloat32Array) -> void:
	var center := Vector2(layout.center) + Vector2(0.5, 0.5)
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
	gate.slot = slot
	layout.gates.append(gate)


# --- 4. Boss arena ---

## Where the arena goes: {center: Vector2, direction: Vector2 (from the map's middle outwards)}.
## Planned before the zones are drawn, so the zones can be cleaned up around it.
static func _plan_boss_arena(data: FloorData, layout: FloorLayout, sectors: Array[Dictionary],
		rng: RandomNumberGenerator) -> Dictionary:
	var sector: Dictionary = sectors[rng.randi() % sectors.size()]
	var width: float = sector["to"] - sector["from"]
	var angle: float = sector["mid"] + rng.randf_range(-BOSS_ANGLE_JITTER, BOSS_ANGLE_JITTER) * width
	var direction := Vector2.from_angle(angle)
	var outer_radii := Vector2(data.boss_arena_radii) + Vector2(data.boss_arena_wall, data.boss_arena_wall)
	# As far out as possible: the arena's outer wall just inside the map-edge rock.
	var half := Vector2(layout.size) / 2.0
	var margin: Vector2 = outer_radii + Vector2(data.border_max + 2, data.border_max + 2)
	var reach_x: float = (half.x - margin.x) / maxf(absf(direction.x), 0.001)
	var reach_y: float = (half.y - margin.y) / maxf(absf(direction.y), 0.001)
	var arena_center: Vector2 = Vector2(layout.center) + Vector2(0.5, 0.5) + direction * minf(reach_x, reach_y)
	layout.boss_center = Vector2i(arena_center.floor())
	return {"center": arena_center, "direction": direction}


static func _carve_boss_arena(data: FloorData, layout: FloorLayout, arena: Dictionary,
		no_dig: PackedByteArray) -> void:
	var arena_center: Vector2 = arena["center"]
	var direction: Vector2 = arena["direction"]
	var radii := Vector2(data.boss_arena_radii)
	var wall: float = data.boss_arena_wall
	var outer_radii: Vector2 = radii + Vector2(wall, wall)

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
	var clearing: Vector2 = arena_center + inward * (outer_reach + CLEARING_RADIUS)
	_carve_disc(layout, cells, clearing, CLEARING_RADIUS)
	arena["clearing"] = Vector2i(clearing.floor())
	layout.portal_cell = Vector2i((arena_center + direction * (inner_reach - PORTAL_WALL_DISTANCE)).floor())
	layout.set_cells_raw(cells)


# --- 5. Accessibility ---

## Fills tiny pockets, then joins every other floor pocket near the hub or the arena to the start with the
## cheapest tunnel (fewest rock cells dug); pockets elsewhere that can't be reached become rock.
## Cells marked in `no_dig` (hub ring, arena walls, map edge) are never dug, so the hub stays closed except
## for its gates and the arena keeps a single entrance.
static func _connect_everything(data: FloorData, layout: FloorLayout, no_dig: PackedByteArray,
		hub_edge: PackedFloat32Array) -> void:
	var w: int = layout.size.x
	var cells: PackedByteArray = layout.cells_raw()
	var protected: PackedByteArray = layout.protected_raw()
	var start: int = layout.start_cell.y * w + layout.start_cell.x

	var pockets := Pockets.new(cells, w)
	var start_root: int = pockets.root_of(start)
	for root: int in pockets.sizes:
		if root != start_root and pockets.sizes[root] < MIN_POCKET and not pockets.touches(root, protected):
			pockets.fill(root, cells)

	# Digging region: the hub plus a band around it, and the arena's surroundings.
	var hub_max: float = 0.0
	for radius in hub_edge:
		hub_max = maxf(hub_max, radius)
	var reach: float = hub_max + data.hub_ring + DIG_MARGIN
	var reach_squared: float = reach * reach
	var arena_area: Rect2i = layout.boss_rect.grow(DIG_MARGIN)
	var cx: float = layout.center.x + 0.5
	var cy: float = layout.center.y + 0.5

	# Dial's algorithm: walking on floor is free, digging one rock cell costs 1.
	var cost := PackedInt32Array()
	cost.resize(cells.size())
	cost.fill(UNREACHED)
	var parent := PackedInt32Array()
	parent.resize(cells.size())
	parent.fill(-1)
	cost[start] = 0
	# Pocket root -> the first (cheapest) cell where the search entered it.
	var entries: Dictionary = {start_root: start}
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
			@warning_ignore("integer_division")
			var y: int = i / w
			if cells[i] == 1 and parent[i] >= 0 and cells[parent[i]] == 0:
				# Entered a floor pocket from rock: the first time is the cheapest way in.
				var root: int = pockets.root_of(i)
				if not entries.has(root):
					entries[root] = i
			for side in 4:
				var j: int
				var nx: int = x
				var ny: int = y
				match side:
					0: nx = x - 1
					1: nx = x + 1
					2: ny = y - 1
					3: ny = y + 1
				if nx < 0 or ny < 0 or nx >= w or ny >= layout.size.y:
					continue
				j = ny * w + nx
				var floor_cell: bool = cells[j] == 1
				if not floor_cell and no_dig[j] == 1:
					continue
				var fx: float = nx + 0.5 - cx
				var fy: float = ny + 0.5 - cy
				if fx * fx + fy * fy > reach_squared and not arena_area.has_point(Vector2i(nx, ny)):
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
		level += 1

	# Dig back from every pocket's entry to the start.
	for root: int in entries:
		var i: int = entries[root]
		while i >= 0:
			if cells[i] == 0:
				_dig(layout, cells, no_dig, i)
			i = parent[i]
	# Pockets the search never entered can't be reached: they become rock.
	for root: int in pockets.sizes:
		if not entries.has(root):
			pockets.fill(root, cells)
	layout.set_cells_raw(cells)


## Digs one tunnel cell, widened to its 4 neighbors so tunnels are 3 tiles wide.
static func _dig(layout: FloorLayout, cells: PackedByteArray, no_dig: PackedByteArray, i: int) -> void:
	var w: int = layout.size.x
	cells[i] = 1
	var x: int = i % w
	for j: int in [i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w, i + w]:
		if j >= 0 and j < cells.size() and no_dig[j] == 0:
			cells[j] = 1


## Connected floor pockets (4-neighborhood), found row by row as horizontal runs joined with union-find.
## Much faster than a cell-by-cell flood fill on big maps (runs are found with native searches).
class Pockets:
	## Absolute index of each run's first cell and one past its last cell (sorted).
	var run_from := PackedInt32Array()
	var run_to := PackedInt32Array()
	## Union-find parent per run.
	var link := PackedInt32Array()
	## root run -> number of cells.
	var sizes: Dictionary = {}
	## root run -> Array of run indices.
	var members: Dictionary = {}

	func _init(cells: PackedByteArray, w: int) -> void:
		@warning_ignore("integer_division")
		var h: int = cells.size() / w
		var previous_first: int = 0
		var previous_end: int = 0
		for y in h:
			var row_start: int = y * w
			var row_end: int = row_start + w
			var first: int = run_from.size()
			var i: int = row_start
			while i < row_end:
				var from: int = cells.find(1, i)
				if from < 0 or from >= row_end:
					break
				var to: int = cells.find(0, from)
				if to < 0 or to > row_end:
					to = row_end
				run_from.append(from)
				run_to.append(to)
				link.append(run_from.size() - 1)
				i = to
			# Join with overlapping runs of the row above (shifted down by w).
			var a: int = previous_first
			var b: int = first
			while a < previous_end and b < run_from.size():
				var a_from: int = run_from[a] + w
				var a_to: int = run_to[a] + w
				if a_from < run_to[b] and run_from[b] < a_to:
					_union(a, b)
				if a_to < run_to[b]:
					a += 1
				else:
					b += 1
			previous_first = first
			previous_end = run_from.size()
		for run in run_from.size():
			var root: int = _find(run)
			sizes[root] = sizes.get(root, 0) + run_to[run] - run_from[run]
			if not members.has(root):
				members[root] = []
			members[root].append(run)

	func root_of(cell: int) -> int:
		var run: int = run_from.bsearch(cell, false) - 1
		return _find(run) if run >= 0 and cell < run_to[run] else -1

	func touches(root: int, mask: PackedByteArray) -> bool:
		for run: int in members[root]:
			for i in range(run_from[run], run_to[run]):
				if mask[i] == 1:
					return true
		return false

	func fill(root: int, cells: PackedByteArray) -> void:
		for run: int in members[root]:
			for i in range(run_from[run], run_to[run]):
				cells[i] = 0

	func _find(run: int) -> int:
		while link[run] != run:
			link[run] = link[link[run]]
			run = link[run]
		return run

	func _union(a: int, b: int) -> void:
		var root_a: int = _find(a)
		var root_b: int = _find(b)
		if root_a != root_b:
			link[maxi(root_a, root_b)] = mini(root_a, root_b)


## Seeded Fisher-Yates (Array.shuffle() would use the global, unseeded RNG).
static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var temp: Variant = items[i]
		items[i] = items[j]
		items[j] = temp
