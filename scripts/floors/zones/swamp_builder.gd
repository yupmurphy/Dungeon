class_name SwampBuilder
extends ZoneBuilder
## The Swamp: water of every size, from puddles to big lakes. Deep water can't be crossed, shallow water
## and reeds slow you down. Lakes hold islands of mud; reeds line the shores; dead trees stand on the mud;
## patches of fog drift over the water.

## Big lakes (low frequency) and small ponds/puddles (high frequency), as noise in 0..1.
const LAKE_FREQUENCY: float = 0.011
const POND_FREQUENCY: float = 0.05
const ISLAND_FREQUENCY: float = 0.06
const LAKE_DEEP: float = 0.66
const LAKE_SHALLOW: float = 0.58
const LAKE_REEDS: float = 0.555
const POND_DEEP: float = 0.84
const POND_SHALLOW: float = 0.73
const POND_REEDS: float = 0.7
const ISLAND: float = 0.68
const ISLAND_SHORE: float = 0.63
const FOG_PER_10K: float = 6.0
const DEAD_TREE_CHANCE: float = 0.012

var _lakes: PackedByteArray
var _ponds: PackedByteArray
var _islands: PackedByteArray


func plan() -> void:
	var w: int = layout.size.x
	var h: int = layout.size.y
	_lakes = FloorGenerator.noise_bytes(seed_value + 51, LAKE_FREQUENCY, w, h)
	_ponds = FloorGenerator.noise_bytes(seed_value + 52, POND_FREQUENCY, w, h)
	_islands = FloorGenerator.noise_bytes(seed_value + 53, ISLAND_FREQUENCY, w, h)


func paint(x: int, y: int, i: int) -> int:
	var lake: float = _lakes[i] / 255.0
	var pond: float = _ponds[i] / 255.0
	if lake > LAKE_DEEP:
		var island: float = _islands[i] / 255.0
		if island > ISLAND:
			return Terrain.Type.MUD
		if island > ISLAND_SHORE:
			return Terrain.Type.REEDS if roll(x, y, 51) < 0.4 else Terrain.Type.WATER_SHALLOW
		return Terrain.Type.WATER_DEEP
	if pond > POND_DEEP:
		return Terrain.Type.WATER_DEEP
	if lake > LAKE_SHALLOW or pond > POND_SHALLOW:
		return Terrain.Type.WATER_SHALLOW
	if lake > LAKE_REEDS or pond > POND_REEDS:
		return Terrain.Type.REEDS if roll(x, y, 52) < 0.7 else Terrain.Type.MUD
	return Terrain.Type.MUD


func ground() -> int:
	return Terrain.Type.MUD


func filler(_old: int) -> int:
	return Terrain.Type.WATER_DEEP


func decorate(used: Dictionary) -> void:
	var floors: PackedInt32Array = floor_cells()
	scatter(floors, [Terrain.Type.MUD], [["dead_tree", DEAD_TREE_CHANCE], ["shrub", 0.01]], used)
	scatter(floors, [Terrain.Type.WATER_SHALLOW], [["lily", 0.03]], used)
	# Fog: big soft patches, more over water.
	var fog: int = int(floors.size() / 10000.0 * FOG_PER_10K)
	for k in fog:
		var cell: Vector2i = random_zone_cell()
		if cell.x < 0:
			continue
		var spawn := FloorLayout.Spawn.new()
		spawn.kind = FloorLayout.SpawnKind.PROP
		spawn.cell = cell
		spawn.slot = slot
		spawn.art = "fog"
		spawn.solid = false
		layout.add_spawn(spawn)
	_mark_lakes()


## One "lake" place per big body of deep water (for the elements map and, later, the spawners).
func _mark_lakes() -> void:
	var marked: Array[Vector2i] = []
	for attempt in 600:
		var cell: Vector2i = random_zone_cell(func(c: Vector2i) -> bool:
			return _lakes[c.y * layout.size.x + c.x] / 255.0 > LAKE_DEEP + 0.06)
		if cell.x < 0:
			break
		var far: bool = true
		for other in marked:
			if Vector2(other).distance_to(Vector2(cell)) < 90.0:
				far = false
		if far:
			marked.append(cell)
			layout.add_feature(&"lake", cell, slot)
