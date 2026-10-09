class_name ZoneBuilder
extends RefCounted
## Base class of the per-zone terrain generators. FloorGenerator calls, in this order:
##   plan()       global layout of the zone (river path, lakes, oasis, cave chambers...)
##   paint()      ground type of one cell (called for every cell of the zone, and for cells of neighboring
##                zones near the border, so zones blend)
##   shape()      changes after painting (clearings around nests...), before accessibility is fixed
##   decorate()   props and notable places, after accessibility (props never block a path)
## and asks ground(), passage(), filler(), open_cost() when it carves gates and fixes accessibility.

enum Biome { CAVES, FOREST, SWAMP, DESERT }

var layout: FloorLayout
var data: FloorData
var region: RegionData
var slot: int
var seed_value: int
var rng: RandomNumberGenerator
var hub_edge: PackedFloat32Array
## This zone's angular sector {from, to, mid} (empty for the hub).
var sector: Dictionary
## Every planned gate: [{slot, angle}].
var gate_plan: Array[Dictionary]
## Boss arena plan {center, direction}.
var arena: Dictionary


static func create(biome: int) -> ZoneBuilder:
	match biome:
		Biome.CAVES:
			return GalleriesBuilder.new()
		Biome.FOREST:
			return ForestBuilder.new()
		Biome.SWAMP:
			return SwampBuilder.new()
		Biome.DESERT:
			return DesertBuilder.new()
	return ZoneBuilder.new()


func setup(new_layout: FloorLayout, new_data: FloorData, new_slot: int, new_seed: int,
		new_hub_edge: PackedFloat32Array, new_sector: Dictionary, new_gate_plan: Array[Dictionary],
		new_arena: Dictionary) -> void:
	layout = new_layout
	data = new_data
	slot = new_slot
	region = data.regions[slot]
	seed_value = new_seed
	rng = RandomNumberGenerator.new()
	rng.seed = new_seed * 131 + new_slot * 7907 + 3
	hub_edge = new_hub_edge
	sector = new_sector
	gate_plan = new_gate_plan
	arena = new_arena


# --- Overridden by every zone ---

func plan() -> void:
	pass


func paint(_x: int, _y: int, _i: int) -> int:
	return ground()


func shape() -> void:
	pass


func decorate(_used: Dictionary) -> void:
	pass


## Plain walkable ground of the zone (gates, cleared passages).
func ground() -> int:
	return Terrain.Type.CAVE


## What a blocked cell becomes when a passage is opened through it.
func passage(old: int) -> int:
	if old == Terrain.Type.WATER_DEEP:
		return Terrain.Type.WATER_SHALLOW
	return ground()


## What an unreachable floor cell becomes.
func filler(_old: int) -> int:
	return Terrain.Type.ROCK


## Cost of opening a blocked cell of this type (0 = never). Low cost = preferred way through.
func open_cost(type: int) -> int:
	match type:
		Terrain.Type.TREE:
			return 1
		Terrain.Type.THICKET:
			return 2
		Terrain.Type.WATER_DEEP:
			return 2
		Terrain.Type.ROCK:
			return 3
	return 0


# --- Helpers for the zones ---

func center() -> Vector2:
	return Vector2(layout.center) + Vector2(0.5, 0.5)


func hub_outer_radius(angle: float) -> float:
	return FloorGenerator.hub_radius(hub_edge, angle) + data.hub_ring


## A random cell of this zone (any terrain) matching `accept` (Callable(cell) -> bool), or (-1, -1).
func random_zone_cell(accept: Callable = Callable(), tries: int = 400) -> Vector2i:
	for attempt in tries:
		var cell := Vector2i(rng.randi_range(0, layout.size.x - 1), rng.randi_range(0, layout.size.y - 1))
		if layout.slot_at(cell.x, cell.y) != slot:
			continue
		if accept.is_valid() and not accept.call(cell):
			continue
		return cell
	return Vector2i(-1, -1)


## Distance (tiles) from a cell to the nearest gate opening of the hub ring.
func distance_to_gates(cell: Vector2i) -> float:
	var best: float = INF
	for gate in gate_plan:
		var angle: float = gate["angle"]
		var mouth: Vector2 = center() + Vector2.from_angle(angle) * hub_outer_radius(angle)
		best = minf(best, mouth.distance_to(Vector2(cell)))
	return best


## Places a NatureArt prop with its top-left footprint cell at `cell`. Solid props need free ground all
## around them, so they never close a path. Returns false if it doesn't fit.
func place_prop(art: String, cell: Vector2i, used: Dictionary) -> bool:
	var info: Dictionary = NatureArt.prop_info(art)
	var footprint: Vector2i = info["footprint"]
	var solid: bool = info["solid"]
	var rect := Rect2i(cell, footprint)
	if not _fits(rect, used, solid):
		return false
	var spawn := FloorLayout.Spawn.new()
	spawn.kind = FloorLayout.SpawnKind.PROP
	spawn.cell = cell
	spawn.slot = layout.slot_at(cell.x, cell.y)
	spawn.art = art
	spawn.solid = solid
	layout.add_spawn(spawn)
	_claim(rect, used, solid)
	return true


## Places a Tiny Dungeon prop (barrel, chest...) the same way.
func place_tile_prop(tile_index: int, solid: bool, cell: Vector2i, used: Dictionary) -> bool:
	var rect := Rect2i(cell, Vector2i.ONE)
	if not _fits(rect, used, solid):
		return false
	var spawn := FloorLayout.Spawn.new()
	spawn.kind = FloorLayout.SpawnKind.PROP
	spawn.cell = cell
	spawn.slot = layout.slot_at(cell.x, cell.y)
	spawn.tile_index = tile_index
	spawn.solid = solid
	layout.add_spawn(spawn)
	_claim(rect, used, solid)
	return true


func _fits(rect: Rect2i, used: Dictionary, solid: bool) -> bool:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if not layout.is_floor(x, y) or used.has(Vector2i(x, y)):
				return false
	# Keep gates and the arena entrance free.
	for y in range(rect.position.y - 2, rect.end.y + 2):
		for x in range(rect.position.x - 2, rect.end.x + 2):
			if layout.is_protected(x, y):
				return false
	if not solid:
		return true
	# A solid prop must not cut a path: walking around it, the open cells must form one unbroken run
	# (so it may lean against a wall, but never plug a passage).
	var ring: Array[Vector2i] = _ring_around(rect)
	var runs: int = 0
	var last_open: bool = _open_for_prop(ring[ring.size() - 1], used)
	var any_open: bool = false
	for cell in ring:
		var open: bool = _open_for_prop(cell, used)
		any_open = any_open or open
		if open and not last_open:
			runs += 1
		last_open = open
	return any_open and runs <= 1


func _open_for_prop(cell: Vector2i, used: Dictionary) -> bool:
	return layout.is_floor(cell.x, cell.y) and not used.get(cell, false)


## Cells around a rectangle, walked clockwise (each one touches the next by a side).
func _ring_around(rect: Rect2i) -> Array[Vector2i]:
	var ring: Array[Vector2i] = []
	var outer: Rect2i = rect.grow(1)
	for x in range(outer.position.x, outer.end.x):
		ring.append(Vector2i(x, outer.position.y))
	for y in range(outer.position.y + 1, outer.end.y):
		ring.append(Vector2i(outer.end.x - 1, y))
	for x in range(outer.end.x - 2, outer.position.x - 1, -1):
		ring.append(Vector2i(x, outer.end.y - 1))
	for y in range(outer.end.y - 2, outer.position.y, -1):
		ring.append(Vector2i(outer.position.x, y))
	return ring


func _claim(rect: Rect2i, used: Dictionary, solid: bool) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			used[Vector2i(x, y)] = solid
			if solid:
				# Blocked for the map, sight and monsters too (the prop's body blocks physically).
				layout.set_floor(x, y, false)


## Small decoration scattered over ground of the given types: [[art, chance per cell], ...].
func scatter(floors: PackedInt32Array, types: Array, props: Array, used: Dictionary, step: int = 1) -> void:
	var w: int = layout.size.x
	var terrain: PackedByteArray = layout.terrain_raw()
	var k: int = 0
	while k < floors.size():
		var i: int = floors[k]
		k += step
		if not terrain[i] in types:
			continue
		for entry: Array in props:
			if rng.randf() < entry[1]:
				@warning_ignore("integer_division")
				place_prop(entry[0], Vector2i(i % w, i / w), used)
				break


## Walkable cells of this zone (after accessibility is fixed).
func floor_cells() -> PackedInt32Array:
	var result := PackedInt32Array()
	var cells: PackedByteArray = layout.cells_raw()
	var slots: PackedByteArray = layout.slots_raw()
	var i: int = cells.find(1)
	while i >= 0:
		if slots[i] == slot:
			result.append(i)
		i = cells.find(1, i + 1)
	return result


## Stable pseudo-random number in [0, 1) for a cell.
func roll(x: int, y: int, salt: int = 0) -> float:
	return float(posmod(hash(Vector3i(x, y, seed_value * 31 + salt)), 100003)) / 100003.0
