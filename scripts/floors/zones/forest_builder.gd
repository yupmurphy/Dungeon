class_name ForestBuilder
extends ZoneBuilder
## The Forest: a river winds across the floor between the start cave and the far end (2-4 bridges and fords
## cross it), so the way to the portal is never straight. Dense woods alternate with open clearings and
## thickets nothing gets through; old giant trees stand in the clearings; spider nests hide in the thickest woods
## (webs around them); 1-3 small marshes (mud, reeds, pools) are home to slimes.

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
## The river crosses the line from the start cave's edge to the far end this far along it (share), and goes this many steps
## into the border on both sides.
const RIVER_AT: Vector2 = Vector2(0.25, 0.55)
const RIVER_PAST_EDGE: int = 6
## Thickets: forest so dense nothing gets through (THICKET), where the density noise is above this. With the
## river and the clearings they make the ways through the forest wind.
const THICKET_DENSITY: float = 0.8
## Small marshes in the forest (mud, pools, reeds): how many, their radius (tiles), how far from the start cave
## (beyond its ring), the arena and each other, and the noise that splits mud, reeds and water.
const MARSH_COUNT: Vector2i = Vector2i(1, 3)
const MARSH_RADIUS: Vector2 = Vector2(13.0, 22.0)
const MARSH_HUB_DISTANCE: float = 40.0
const MARSH_ARENA_DISTANCE: float = 70.0
const MARSH_SPACING: float = 90.0
const MARSH_FREQUENCY: float = 0.12

## River cells: 1 bank, 2 shallow, 3 deep (strongest wins).
var _river: PackedByteArray
## Crossings: cell index -> terrain (bridge planks or ford).
var _crossings: Dictionary = {}
var _density: PackedByteArray
var _nests: Array[Vector2i] = []
var _river_path: PackedVector2Array = PackedVector2Array()
## Marsh cells: 0 = none, else how deep inside the marsh (255 = its middle).
var _marsh: PackedByteArray
var _marsh_noise: PackedByteArray


func plan() -> void:
	_density = FloorGenerator.noise_bytes(seed_value + 41, DENSITY_FREQUENCY, layout.size.x, layout.size.y)
	_river = PackedByteArray()
	_river.resize(layout.size.x * layout.size.y)
	_plan_river()
	_plan_marshes()


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
	if _marsh[i] > 0:
		return _marsh_ground(i)
	var density: float = _density[i] / 255.0
	if density > THICKET_DENSITY:
		return Terrain.Type.THICKET
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

## Crosses the floor from one side of the capsule to the other, somewhere between the start and the far end, so
## every way from the start to the portal meets it (and its 2-4 crossings make several routes).
## Starts in the middle of the land and winds out both ways until it runs into the border.
func _plan_river() -> void:
	if layout.shape_tips.size() < 2:
		return
	var far: Vector2 = Vector2(layout.shape_tips[1]) + Vector2(0.5, 0.5)
	# Measured from where the start cave ends (its edge toward the far end), not from its middle.
	var toward: Vector2 = (far - center()).normalized()
	var start: Vector2 = center() + toward * hub_outer_radius(toward.angle())
	var middle: Vector2 = start.lerp(far, rng.randf_range(RIVER_AT.x, RIVER_AT.y))
	var across: Vector2 = (far - start).normalized().orthogonal()
	var meander := FastNoiseLite.new()
	meander.seed = seed_value + 43
	meander.frequency = 0.02
	var width := FastNoiseLite.new()
	width.seed = seed_value + 44
	width.frequency = 0.03
	var halves: Array[PackedVector2Array] = []
	for side: float in [-1.0, 1.0]:
		var half_path := PackedVector2Array()
		var position: Vector2 = middle
		var aim: float = (across * side).angle()
		var heading: float = aim
		var outside: int = 0
		var steps: int = 0
		# Until it is a few steps into the border (or off the map).
		while _inside_map(position) and outside < RIVER_PAST_EDGE and steps < 3000:
			var noise_at: float = steps * side + 1000.0
			heading = lerp_angle(heading, aim, 0.06) + meander.get_noise_1d(noise_at) * 0.18
			position += Vector2.from_angle(heading) * RIVER_STEP
			var cell := Vector2i(position.floor())
			outside = 0 if layout.is_land_index(cell.y * layout.size.x + cell.x) else outside + 1
			var half: float = lerpf(RIVER_HALF_WIDTH.x, RIVER_HALF_WIDTH.y, width.get_noise_1d(noise_at) * 0.5 + 0.5)
			_stamp_river(position, half)
			half_path.append(position)
			steps += 1
		halves.append(half_path)
	# One path from one bank of the floor to the other.
	var first: PackedVector2Array = halves[0]
	first.reverse()
	_river_path = first
	_river_path.append(middle)
	_river_path.append_array(halves[1])
	_plan_crossings()


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
		var on_land: bool = layout.in_bounds(int(p.x), int(p.y)) and layout.is_land_index(int(p.y) * layout.size.x + int(p.x))
		if layout.slot_at(int(p.x), int(p.y)) == slot and on_land and k > 15:
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


# --- Marshes ---

## 1-3 small marshes on forest land, away from the start cave, the arena, the river and each other. Slimes live
## there (MonsterData.home_feature "marsh").
func _plan_marshes() -> void:
	_marsh = PackedByteArray()
	_marsh.resize(layout.size.x * layout.size.y)
	_marsh_noise = FloorGenerator.noise_bytes(seed_value + 45, MARSH_FREQUENCY, layout.size.x, layout.size.y)
	var edge := FastNoiseLite.new()
	edge.seed = seed_value + 46
	edge.frequency = 0.08
	var centers: Array[Vector2i] = []
	for k in rng.randi_range(MARSH_COUNT.x, MARSH_COUNT.y):
		var radius: float = rng.randf_range(MARSH_RADIUS.x, MARSH_RADIUS.y)
		var cell: Vector2i = random_zone_cell(func(c: Vector2i) -> bool:
			var at := Vector2(c)
			if not _land_around(c, radius + 4.0):
				return false
			var from_hub: float = at.distance_to(center())
			if from_hub < hub_outer_radius((at - center()).angle()) + MARSH_HUB_DISTANCE + radius:
				return false
			if at.distance_to(Vector2(layout.boss_center)) < MARSH_ARENA_DISTANCE + radius:
				return false
			for other in centers:
				if at.distance_to(Vector2(other)) < MARSH_SPACING:
					return false
			for p in _river_path:
				if p.distance_to(at) < radius + 8.0:
					return false
			return true)
		if cell.x < 0:
			continue
		centers.append(cell)
		layout.add_feature(&"marsh", cell, slot)
		var r: int = ceili(radius * 1.3)
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c: Vector2i = cell + Vector2i(dx, dy)
				if not layout.in_bounds(c.x, c.y):
					continue
				var offset := Vector2(dx, dy)
				# A wobbly blob: the edge moves in and out with the angle and a little noise.
				var reach: float = radius * (1.0 + 0.25 * edge.get_noise_2d(c.x, c.y))
				var depth: float = 1.0 - offset.length() / reach
				if depth > 0.0:
					var i: int = c.y * layout.size.x + c.x
					_marsh[i] = maxi(_marsh[i], clampi(int(depth * 255.0), 1, 255))


## Mud ground with reeds and shallow pools; deep water only in the middle.
func _marsh_ground(i: int) -> int:
	var depth: float = _marsh[i] / 255.0
	var water: float = _marsh_noise[i] / 255.0
	if depth > 0.55 and water < 0.25:
		return Terrain.Type.WATER_DEEP
	if water < 0.42:
		return Terrain.Type.WATER_SHALLOW
	if water < 0.58:
		return Terrain.Type.REEDS
	return Terrain.Type.MUD


## Every cell within `radius` of `cell` (checked on a ring and the middle) is land.
func _land_around(cell: Vector2i, radius: float) -> bool:
	for k in 13:
		var p: Vector2 = Vector2(cell) + (Vector2.ZERO if k == 0 else Vector2.from_angle(TAU * k / 12.0) * radius)
		var c := Vector2i(p.floor())
		if not layout.in_bounds(c.x, c.y) or not layout.is_land_index(c.y * layout.size.x + c.x):
			return false
	return true
