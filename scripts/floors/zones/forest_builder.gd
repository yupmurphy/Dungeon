class_name ForestBuilder
extends ZoneBuilder
## The Forest: a long river springs at the galleries' rock ring and winds out to the map's edge, cutting
## the forest in two; 1-2 bridges and 1-2 fords cross it. Dense woods alternate with open clearings; old
## giant trees stand in the clearings; spider nests hide in the thickest woods (webs around them).

const RIVER_STEP: float = 1.0
## Deep middle of the river: half width varies between these (tiles).
const RIVER_HALF_WIDTH: Vector2 = Vector2(2.0, 3.5)
const SHALLOW_BAND: float = 1.3
const BANK_BAND: float = 2.5
## Forest density noise (0..1): above DENSE thick woods, above SPARSE scattered trees, below = clearing.
const DENSITY_FREQUENCY: float = 0.014
const DENSE: float = 0.6
const SPARSE: float = 0.4
## Share of TREE_GRID blocks that hold a tree.
const TREE_GRID: int = 3
const DENSE_TREE_CHANCE: float = 0.9
const SPARSE_TREE_CHANCE: float = 0.3
const CLEARING_TREE_CHANCE: float = 0.03
const NEST_COUNT: Vector2i = Vector2i(5, 8)
const NEST_CLEARING: float = 4.5
const OLD_TREES_PER_10K: float = 3.0

## River cells: 1 bank, 2 shallow, 3 deep (strongest wins).
var _river: PackedByteArray
## Crossings: cell index -> terrain (bridge planks or ford).
var _crossings: Dictionary = {}
var _density: PackedByteArray
var _nests: Array[Vector2i] = []
var _river_path: PackedVector2Array = PackedVector2Array()


func plan() -> void:
	_density = FloorGenerator.noise_bytes(seed_value + 41, DENSITY_FREQUENCY, layout.size.x, layout.size.y)
	_river = PackedByteArray()
	_river.resize(layout.size.x * layout.size.y)
	_plan_river()


func paint(x: int, y: int, i: int) -> int:
	if _crossings.has(i):
		return _crossings[i]
	match _river[i]:
		3:
			return Terrain.Type.WATER_DEEP
		2:
			return Terrain.Type.WATER_SHALLOW
		1:
			return Terrain.Type.GRASS
	var density: float = _density[i] / 255.0
	var ground_type: int = Terrain.Type.GRASS if density <= SPARSE else Terrain.Type.FOREST_FLOOR
	var chance: float = CLEARING_TREE_CHANCE
	if density > DENSE:
		chance = DENSE_TREE_CHANCE
	elif density > SPARSE:
		chance = SPARSE_TREE_CHANCE
	return Terrain.Type.TREE if _tree_spot(x, y, chance) else ground_type


## Trees are big (crown ~3 tiles), so at most one trunk per TREE_GRID x TREE_GRID block, at a random spot.
## `chance` = how many blocks have a tree.
@warning_ignore("integer_division")
func _tree_spot(x: int, y: int, chance: float) -> bool:
	var bx: int = x / TREE_GRID
	var by: int = y / TREE_GRID
	var pick: int = posmod(hash(Vector3i(bx, by, seed_value + 47)), TREE_GRID * TREE_GRID)
	if x % TREE_GRID != pick % TREE_GRID or y % TREE_GRID != pick / TREE_GRID:
		return false
	return roll(bx, by, 48) < chance


func ground() -> int:
	return Terrain.Type.FOREST_FLOOR


func filler(_old: int) -> int:
	return Terrain.Type.TREE


## Spider nests: a small clearing in thick woods, webs all around.
func shape() -> void:
	var count: int = rng.randi_range(NEST_COUNT.x, NEST_COUNT.y)
	for k in count:
		var cell: Vector2i = random_zone_cell(func(c: Vector2i) -> bool:
			if _density[c.y * layout.size.x + c.x] / 255.0 < DENSE or _river[c.y * layout.size.x + c.x] > 0:
				return false
			var edge: int = mini(mini(c.x, c.y), mini(layout.size.x - 1 - c.x, layout.size.y - 1 - c.y))
			if edge < data.border_max + 12:
				return false
			for other in _nests:
				if Vector2(other).distance_to(Vector2(c)) < 40.0:
					return false
			return distance_to_gates(c) > 30.0)
		if cell.x < 0:
			continue
		_nests.append(cell)
		var at: Vector2 = Vector2(cell) + Vector2(0.5, 0.5)
		FloorGenerator.paint_disc(layout, at, NEST_CLEARING + 2.0, Terrain.Type.WEB, false, slot)
		FloorGenerator.paint_disc(layout, at, 2.0, Terrain.Type.FOREST_FLOOR, false, slot)


func decorate(used: Dictionary) -> void:
	for cell in _nests:
		if place_prop("spider_nest", cell - Vector2i(1, 1), used):
			layout.add_feature(&"spider_nest", cell, slot)
	var floors: PackedInt32Array = floor_cells()
	# Old giant trees in the clearings.
	var old_trees: int = int(floors.size() / 10000.0 * OLD_TREES_PER_10K)
	var placed: int = 0
	for attempt in old_trees * 30:
		if placed >= old_trees:
			break
		var cell: Vector2i = random_zone_cell(func(c: Vector2i) -> bool:
			return layout.terrain_at(c.x, c.y) == Terrain.Type.GRASS)
		if cell.x >= 0 and place_prop("old_tree", cell, used):
			layout.add_feature(&"old_tree", cell, slot)
			placed += 1
	scatter(floors, [Terrain.Type.FOREST_FLOOR], [["mushroom", 0.012], ["bush", 0.02]], used)
	scatter(floors, [Terrain.Type.GRASS], [["bush", 0.012], ["boulder", 0.003]], used)


# --- River ---

## Springs just outside the hub ring, away from the gates, and winds outwards to the map's edge.
func _plan_river() -> void:
	if sector.is_empty():
		return
	var angle: float = _spring_angle()
	var position: Vector2 = center() + Vector2.from_angle(angle) * (hub_outer_radius(angle) + 1.0)
	var heading: float = angle
	var meander := FastNoiseLite.new()
	meander.seed = seed_value + 43
	meander.frequency = 0.02
	var width := FastNoiseLite.new()
	width.seed = seed_value + 44
	width.frequency = 0.03
	var steps: int = 0
	while _inside_map(position) and steps < 4000:
		var outward: float = (position - center()).angle()
		heading = lerp_angle(heading, outward, 0.06) + meander.get_noise_1d(steps) * 0.18
		position += Vector2.from_angle(heading) * RIVER_STEP
		var half: float = lerpf(RIVER_HALF_WIDTH.x, RIVER_HALF_WIDTH.y, width.get_noise_1d(steps) * 0.5 + 0.5)
		_stamp_river(position, half)
		_river_path.append(position)
		steps += 1
	_plan_crossings()


## The river's spring: inside the zone's arc of the ring, as far as possible from the gates.
func _spring_angle() -> float:
	var best: float = sector["mid"]
	var best_gap: float = -1.0
	var from: float = sector["from"]
	var span: float = sector["to"] - from
	for k in 40:
		var angle: float = from + span * (0.15 + 0.7 * k / 39.0)
		var probe: Vector2 = center() + Vector2.from_angle(angle) * (hub_outer_radius(angle) + 6.0)
		if layout.slot_at(int(probe.x), int(probe.y)) != slot:
			continue
		var gap: float = INF
		for gate in gate_plan:
			gap = minf(gap, absf(angle_difference(angle, gate["angle"])))
		gap += rng.randf() * 0.05
		if gap > best_gap:
			best_gap = gap
			best = angle
	return best


func _inside_map(position: Vector2) -> bool:
	return position.x > 2 and position.y > 2 and position.x < layout.size.x - 3 and position.y < layout.size.y - 3


func _stamp_river(at: Vector2, half: float) -> void:
	var reach: float = half + SHALLOW_BAND + BANK_BAND
	var r: int = ceili(reach)
	var w: int = layout.size.x
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var cell := Vector2i(at.floor()) + Vector2i(dx, dy)
			if not layout.in_bounds(cell.x, cell.y):
				continue
			var distance: float = (Vector2(cell) + Vector2(0.5, 0.5)).distance_to(at)
			var kind: int = 0
			if distance <= half:
				kind = 3
			elif distance <= half + SHALLOW_BAND:
				kind = 2
			elif distance <= reach:
				kind = 1
			var i: int = cell.y * w + cell.x
			_river[i] = maxi(_river[i], kind)


## 2-4 crossings spread along the part of the river inside the forest: bridges and fords.
func _plan_crossings() -> void:
	var inside := PackedInt32Array()
	for k in _river_path.size():
		var p: Vector2 = _river_path[k]
		if layout.slot_at(int(p.x), int(p.y)) == slot and k > 15:
			inside.append(k)
	if inside.is_empty():
		return
	var count: int = rng.randi_range(2, 4)
	for c in count:
		var k: int = inside[int((c + 0.5) / count * inside.size())]
		var bridge: bool = c % 2 == 0
		var at: Vector2 = _river_path[k]
		var along: Vector2 = (_river_path[mini(k + 2, _river_path.size() - 1)] - _river_path[maxi(k - 2, 0)]).normalized()
		var across: Vector2 = along.orthogonal()
		var length: float = RIVER_HALF_WIDTH.y + SHALLOW_BAND + 2.0
		var half_width: float = 1.5 if bridge else 2.5
		var w: int = layout.size.x
		for dy in range(-8, 9):
			for dx in range(-8, 9):
				var cell := Vector2i(at.floor()) + Vector2i(dx, dy)
				if not layout.in_bounds(cell.x, cell.y):
					continue
				var offset: Vector2 = Vector2(cell) + Vector2(0.5, 0.5) - at
				if absf(offset.dot(along)) > half_width or absf(offset.dot(across)) > length:
					continue
				var i: int = cell.y * w + cell.x
				if _river[i] >= 2:
					_crossings[i] = Terrain.Type.BRIDGE if bridge else Terrain.Type.WATER_SHALLOW
		layout.add_feature(&"bridge" if bridge else &"ford", Vector2i(at.floor()), slot)
