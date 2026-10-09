class_name GalleriesBuilder
extends ZoneBuilder
## Goblin Galleries (the closed hub): organic cave chambers joined by winding tunnels, inside solid rock.
## Three big halls have a role: the goblin camp (tents around a fire), the mine (rails, carts,
## barrels) and the chieftain's hall (throne, banners, bones; the mini-boss comes in a later stage).
## Always dark: only torches and the camp fire give light (no glowing crystals: user decision).

## Every cave (start, halls, chambers, the caves behind gates and mouths) is this much bigger than its radius below
## (user: +20-30%).
const CHAMBER_SCALE: float = 1.25
const START_RADIUS: float = 9.0
const HALL_RADIUS: Vector2 = Vector2(28.0, 34.0)
## Most chambers are big; a few small ones stay here and there.
const CHAMBER_RADIUS: Vector2 = Vector2(15.0, 24.0)
## A minority of ordinary caves are spacious; small caves and tunnels still exist.
const LARGE_CHAMBER_RADIUS: Vector2 = Vector2(25.0, 31.0)
const LARGE_CHAMBER_CHANCE: float = 0.25
const REINFORCEMENT_REACH: float = 1.3
const REINFORCEMENT_BACK_SHARE: float = 0.25
const SMALL_CHAMBER_RADIUS: Vector2 = Vector2(6.0, 10.0)
const SMALL_CHAMBER_CHANCE: float = 0.2
## Gap kept between chambers (tiles), so tunnels have room to wind.
const CHAMBER_GAP: float = 6.0
## Chambers stay this far inside the ring.
const RING_MARGIN: float = 10.0
const CHAMBER_TRIES: int = 1500
## Chance that a chamber also gets a tunnel to its nearest neighbor that isn't linked yet (loops).
const EXTRA_TUNNEL_CHANCE: float = 0.35
const TUNNEL_RADIUS: float = 1.6
const WIDE_TUNNEL_RADIUS: float = 2.2
## Mouths (stretches of the hub's edge without a ring): the cave behind each one, and the opening cut through.
const MOUTH_CAVE_DEPTH: float = 16.0
const MOUTH_CAVE_RADIUS: float = 9.0
const MOUTH_OPENING_RADIUS: float = 4.0
## Bigger hubs get more tries at placing chambers: one per this many tiles of hub area.
const AREA_PER_TRY: float = 40.0

## [{center: Vector2, radius: float, role: StringName, phase: float, lobes: int}]
var chambers: Array[Dictionary] = []
## 1 = cave floor (hub only).
var _cave: PackedByteArray


func plan() -> void:
	_cave = PackedByteArray()
	_cave.resize(layout.size.x * layout.size.y)
	_place_chambers()
	for chamber in chambers:
		_stamp_chamber(chamber)
	_dig_tunnels()
	_carve_mouths()


func paint(_x: int, _y: int, i: int) -> int:
	return Terrain.Type.CAVE if _cave[i] == 1 else Terrain.Type.ROCK


func ground() -> int:
	return Terrain.Type.CAVE


func passage(_old: int) -> int:
	return Terrain.Type.CAVE


func open_cost(type: int) -> int:
	return 3 if type == Terrain.Type.ROCK else 0


func decorate(used: Dictionary) -> void:
	for chamber in chambers:
		match chamber["role"]:
			&"camp":
				_decorate_camp(chamber, used)
			&"mine":
				_decorate_mine(chamber, used)
			&"chieftain":
				_decorate_chieftain(chamber, used)


# --- Plan ---

func _place_chambers() -> void:
	var c: Vector2 = center()
	chambers.append(_chamber(Vector2(layout.start_cell) + Vector2(0.5, 0.5), START_RADIUS * CHAMBER_SCALE, &"start"))
	# The three halls: chieftain deep inside (far from the start), camp and mine at middle distance,
	# in different directions.
	var base_angle: float = rng.randf() * TAU
	var roles: Array[StringName] = [&"chieftain", &"camp", &"mine"]
	for k in roles.size():
		var angle: float = base_angle + TAU * k / roles.size() + rng.randf_range(-0.4, 0.4)
		var edge: float = FloorGenerator.hub_radius(hub_edge, angle) - RING_MARGIN
		var radius: float = rng.randf_range(HALL_RADIUS.x, HALL_RADIUS.y) * CHAMBER_SCALE
		var share: float = rng.randf_range(0.62, 0.72) if roles[k] == &"chieftain" else rng.randf_range(0.4, 0.55)
		var distance: float = minf(edge * share + radius * 0.3, edge - radius)
		chambers.append(_chamber(c + Vector2.from_angle(angle) * distance, radius, roles[k]))
	# Small chambers at the inner end of every gate passage, so gates open into a cave.
	for gate in gate_plan:
		var angle: float = gate["angle"]
		var at: Vector2 = c + Vector2.from_angle(angle) * (FloorGenerator.hub_radius(hub_edge, angle)
			- FloorGenerator.GATE_INNER_DEPTH - 4.0)
		chambers.append(_chamber(at, 6.0 * CHAMBER_SCALE, &"gate"))
	# A cave at the inner end of every mouth (a stretch of the edge without a ring), so the mouth opens into a cave.
	for k in _mouth_middles():
		var angle: float = TAU * k / FloorGenerator.HUB_EDGE_SAMPLES
		var at: Vector2 = c + Vector2.from_angle(angle) * (FloorGenerator.hub_radius(hub_edge, angle) - MOUTH_CAVE_DEPTH)
		chambers.append(_chamber(at, MOUTH_CAVE_RADIUS * CHAMBER_SCALE, &"gate"))
	# Ordinary chambers fill the rest (more tries for a bigger hub).
	var area: float = 0.0
	for r in hub_edge:
		area += 0.5 * r * r * TAU / hub_edge.size()
	for attempt in maxi(CHAMBER_TRIES, int(area / AREA_PER_TRY)):
		var angle: float = rng.randf() * TAU
		var edge: float = FloorGenerator.hub_radius(hub_edge, angle) - RING_MARGIN
		var distance: float = sqrt(rng.randf()) * edge
		var size_roll: float = rng.randf()
		var size_range: Vector2 = CHAMBER_RADIUS
		if size_roll < SMALL_CHAMBER_CHANCE:
			size_range = SMALL_CHAMBER_RADIUS
		elif size_roll < SMALL_CHAMBER_CHANCE + LARGE_CHAMBER_CHANCE:
			size_range = LARGE_CHAMBER_RADIUS
		var radius: float = rng.randf_range(size_range.x, size_range.y) * CHAMBER_SCALE
		if distance + radius > edge:
			continue
		var at: Vector2 = c + Vector2.from_angle(angle) * distance
		var free: bool = true
		for other in chambers:
			if at.distance_to(other["center"]) < radius + other["radius"] + CHAMBER_GAP:
				free = false
				break
		if free:
			chambers.append(_chamber(at, radius, &"cave"))


func _chamber(at: Vector2, radius: float, role: StringName) -> Dictionary:
	return {"center": at, "radius": radius, "role": role, "phase": rng.randf() * TAU,
		"lobes": rng.randi_range(2, 5)}


## Blob: a circle whose radius waves with the angle, plus a little per-cell roughness.
func _stamp_chamber(chamber: Dictionary) -> void:
	var at: Vector2 = chamber["center"]
	var radius: float = chamber["radius"]
	var phase: float = chamber["phase"]
	var lobes: int = chamber["lobes"]
	var reach: int = ceili(radius * 1.3) + 1
	var w: int = layout.size.x
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var cell := Vector2i(at.floor()) + Vector2i(dx, dy)
			if not _inside_hub(cell):
				continue
			var offset: Vector2 = Vector2(cell) + Vector2(0.5, 0.5) - at
			var angle: float = offset.angle()
			var edge: float = radius * (1.0 + 0.22 * sin(angle * lobes + phase) + 0.1 * sin(angle * 7.0 + phase * 2.0))
			edge += (roll(cell.x, cell.y, 5) - 0.5) * 1.6
			if offset.length() <= edge:
				_cave[cell.y * w + cell.x] = 1


## Minimum spanning tree over the chambers (everything connected) plus a few extra tunnels (loops).
func _dig_tunnels() -> void:
	var count: int = chambers.size()
	var linked: Dictionary = {}
	# Prim: for every chamber outside the tree, its closest chamber inside the tree.
	var in_tree: Array[bool] = []
	in_tree.resize(count)
	in_tree.fill(false)
	var closest := PackedFloat32Array()
	closest.resize(count)
	closest.fill(INF)
	var via := PackedInt32Array()
	via.resize(count)
	via.fill(0)
	in_tree[0] = true
	for b in count:
		closest[b] = _gap(0, b)
	for added in count - 1:
		var next: int = -1
		for b in count:
			if not in_tree[b] and (next < 0 or closest[b] < closest[next]):
				next = b
		in_tree[next] = true
		linked[_key(via[next], next)] = true
		_tunnel(via[next], next)
		for b in count:
			if not in_tree[b]:
				var distance: float = _gap(next, b)
				if distance < closest[b]:
					closest[b] = distance
					via[b] = next
	for a in count:
		if rng.randf() >= EXTRA_TUNNEL_CHANCE:
			continue
		var nearest: int = -1
		var nearest_distance: float = INF
		for b in count:
			if b == a or linked.has(_key(a, b)):
				continue
			var distance: float = _gap(a, b)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = b
		if nearest >= 0 and nearest_distance < 60.0:
			linked[_key(a, nearest)] = true
			_tunnel(a, nearest)


func _gap(a: int, b: int) -> float:
	return (chambers[a]["center"] as Vector2).distance_to(chambers[b]["center"]) \
		- chambers[a]["radius"] - chambers[b]["radius"]


func _key(a: int, b: int) -> Vector2i:
	return Vector2i(mini(a, b), maxi(a, b))


## A winding tunnel: walks towards the target with a wobbling heading. Halls get wider tunnels.
func _tunnel(a: int, b: int) -> void:
	var from: Vector2 = chambers[a]["center"]
	var to: Vector2 = chambers[b]["center"]
	var wide: bool = chambers[a]["role"] in [&"start", &"camp", &"mine", &"chieftain"] \
		and chambers[b]["role"] in [&"start", &"camp", &"mine", &"chieftain"]
	var radius: float = WIDE_TUNNEL_RADIUS if wide else TUNNEL_RADIUS
	var position: Vector2 = from
	var phase: float = rng.randf() * TAU
	var frequency: float = rng.randf_range(0.08, 0.16)
	var steps: int = 0
	var limit: int = int(from.distance_to(to) * 3.0) + 20
	while position.distance_to(to) > 1.5 and steps < limit:
		var heading: float = (to - position).angle()
		# Strong wobble far from the target, none at the end, so the tunnel always arrives.
		var freedom: float = clampf(position.distance_to(to) / 12.0, 0.0, 1.0)
		heading += sin(steps * frequency + phase) * 0.75 * freedom
		position += Vector2.from_angle(heading)
		_stamp(position, radius + (0.6 if roll(steps, a, 9) < 0.15 else 0.0))
		steps += 1


func _stamp(at: Vector2, radius: float) -> void:
	var r: int = ceili(radius)
	var w: int = layout.size.x
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var cell := Vector2i(at.floor()) + Vector2i(dx, dy)
			if _inside_hub(cell) and (Vector2(cell) + Vector2(0.5, 0.5)).distance_to(at) <= radius:
				_cave[cell.y * w + cell.x] = 1


## Inside the hub, not in its ring.
func _inside_hub(cell: Vector2i) -> bool:
	if not layout.in_bounds(cell.x, cell.y) or layout.slot_at(cell.x, cell.y) != slot:
		return false
	var offset: Vector2 = Vector2(cell) + Vector2(0.5, 0.5) - center()
	return offset.length() < FloorGenerator.hub_radius(hub_edge, offset.angle()) - 1.5


# --- Decoration ---

func _decorate_camp(hall: Dictionary, used: Dictionary) -> void:
	var at := Vector2i((hall["center"] as Vector2).floor())
	var radius: float = hall["radius"]
	layout.add_feature(&"goblin_camp", at, slot)
	_place_near("campfire", at, used)
	for k in 6:
		var seat := Vector2i((Vector2(at) + Vector2.from_angle(TAU * k / 6.0) * 2.6).round())
		place_prop("log_seat", seat, used)
	var tents: int = rng.randi_range(3, 5)
	var start: float = rng.randf() * TAU
	for k in tents:
		var spot: Vector2 = Vector2(at) + Vector2.from_angle(start + TAU * k / tents) * radius * 0.6
		_place_near("tent", Vector2i(spot.floor()) - Vector2i(1, 1), used)
	for k in 8:
		var spot: Vector2 = Vector2(at) + Vector2.from_angle(rng.randf() * TAU) * radius * rng.randf_range(0.3, 0.8)
		place_tile_prop([66, 89, 73][k % 3], k % 3 != 2, Vector2i(spot.floor()), used)


func _decorate_mine(hall: Dictionary, used: Dictionary) -> void:
	var at := Vector2i((hall["center"] as Vector2).floor())
	var radius: float = hall["radius"]
	layout.add_feature(&"mine", at, slot)
	# A rail line across the hall, carts standing on it.
	var reach: int = int(radius * 0.8)
	for x in range(at.x - reach, at.x + reach + 1):
		place_prop("rails", Vector2i(x, at.y), used)
	for k in 2:
		var x: int = at.x + rng.randi_range(-reach + 2, reach - 2)
		used.erase(Vector2i(x, at.y + 1))
		_place_near("cart", Vector2i(x, at.y + 1), used)
	# The mine is lit by wall torches only; the random glowing crystals were removed (user decision).
	for k in 6:
		var spot := Vector2i((Vector2(at) + Vector2.from_angle(rng.randf() * TAU) * radius * 0.5).floor())
		place_tile_prop(66, true, spot, used)


func _decorate_chieftain(hall: Dictionary, used: Dictionary) -> void:
	var at := Vector2i((hall["center"] as Vector2).floor())
	var radius: float = hall["radius"]
	layout.add_feature(&"chieftain_hall", at, slot)
	_reinforce_hall(at, radius)
	# Throne on the side away from the start, banners on both sides, bones scattered.
	var away: Vector2 = (Vector2(at) - center()).normalized()
	var throne := Vector2i((Vector2(at) + away * radius * 0.55).floor()) - Vector2i(1, 1)
	_place_near("throne", throne, used)
	var side: Vector2 = away.orthogonal()
	for k: int in [-2, -1, 1, 2]:
		var spot := Vector2i((Vector2(throne) + Vector2(1, 1) + side * k * 3.5 - away * 1.5).floor())
		_place_near("banner", spot, used)
	for k in 10:
		var spot := Vector2i((Vector2(at) + Vector2.from_angle(rng.randf() * TAU) * radius * rng.randf_range(0.2, 0.8)).floor())
		place_prop("bone", spot, used)


## Tries the cell, then nearby cells, until the prop fits.
func _place_near(art: String, cell: Vector2i, used: Dictionary) -> bool:
	for r in 4:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) == r and place_prop(art, cell + Vector2i(dx, dy), used):
					return true
	return false


func _against_rock(cell: Vector2i) -> bool:
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if layout.is_rock(cell.x + offset.x, cell.y + offset.y):
			return true
	return false


## Only the built back wall of the chieftain hall uses masonry; cave walls stay natural.
## The reinforcement is a material mark, not an extra obstacle or a dug cell.
func _reinforce_hall(at: Vector2i, radius: float) -> void:
	var away: Vector2 = (Vector2(at) - center()).normalized()
	var reach: int = ceili(radius * REINFORCEMENT_REACH)
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var cell: Vector2i = at + Vector2i(dx, dy)
			var offset: Vector2 = Vector2(cell - at)
			if offset.length() > reach or offset.dot(away) < radius * REINFORCEMENT_BACK_SHARE \
					or layout.slot_at(cell.x, cell.y) != slot or not layout.is_rock(cell.x, cell.y):
				continue
			for neighbor in CaveArt.OFFSETS:
				var beside: Vector2i = cell + neighbor
				if layout.terrain_at(beside.x, beside.y) == Terrain.Type.CAVE:
					layout.mark_masonry(cell.x, cell.y)
					break


# --- Mouths ---

## Middle sample of every run of open edge samples (FloorLayout.hub_open).
func _mouth_middles() -> Array[int]:
	var middles: Array[int] = []
	var open: PackedByteArray = layout.hub_open
	var n: int = FloorGenerator.HUB_EDGE_SAMPLES
	if open.is_empty() or open.count(1) == 0 or open.count(1) == n:
		return middles
	# Start just after a closed sample, so no run is cut in two at the wrap.
	var first: int = open.find(0)
	var run_start: int = -1
	for step in n + 1:
		var k: int = (first + step) % n
		if open[k] == 1 and run_start < 0:
			run_start = step
		elif open[k] == 0 and run_start >= 0:
			middles.append((first + (run_start + step - 1) / 2) % n)
			run_start = -1
	return middles


## Cave floor from the mouth's cave out through where the ring would be, all along the open stretch.
func _carve_mouths() -> void:
	var c: Vector2 = center()
	var w: int = layout.size.x
	var r: int = ceili(MOUTH_OPENING_RADIUS)
	for k in FloorGenerator.HUB_EDGE_SAMPLES:
		if layout.hub_open.is_empty() or layout.hub_open[k] == 0 or k % 2 == 1:
			continue
		var angle: float = TAU * k / FloorGenerator.HUB_EDGE_SAMPLES
		var direction := Vector2.from_angle(angle)
		var edge: float = FloorGenerator.hub_radius(hub_edge, angle)
		var distance: float = edge - MOUTH_CAVE_DEPTH
		while distance <= edge + data.hub_ring + 2.0:
			var at: Vector2 = c + direction * distance
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					var cell := Vector2i(at.floor()) + Vector2i(dx, dy)
					if layout.in_bounds(cell.x, cell.y) and Vector2(dx, dy).length() <= MOUTH_OPENING_RADIUS \
							+ (roll(cell.x, cell.y, 9) - 0.5) * 2.0:
						_cave[cell.y * w + cell.x] = 1
			distance += 2.0
