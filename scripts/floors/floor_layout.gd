class_name FloorLayout
extends RefCounted
## Result of FloorGenerator: a wall/floor grid plus rooms, regions and key positions.
## Pure data (no nodes), so it can be generated and checked without running the game.
##
## Region "slots": 0 = start zone, 1..N = FloorData.regions in order, N + 1 = boss arena.

enum RoomKind { START, NORMAL, BOSS }

const START_SLOT: int = 0
## Walls this close to a floor cell are drawn; deeper rock stays empty (black).
const RENDER_DISTANCE: int = 2


class Room:
	var rect: Rect2i
	var slot: int
	var kind: int  # RoomKind
	var sector: Vector2i

	func center() -> Vector2i:
		return rect.position + rect.size / 2


var size: Vector2i
var sector_grid: Vector2i
var sector_size: Vector2i
var seed_value: int
var region_count: int
var rooms: Array[Room] = []
## Pairs of connected sectors [Vector2i, Vector2i] (corridors).
var connections: Array[Array] = []
var start_cell: Vector2i
var portal_cell: Vector2i
var boss_sector: Vector2i
var boss_room: Room

var _cells: PackedByteArray
var _corridor: PackedByteArray
var _render: PackedByteArray
var _sector_slots: PackedInt32Array


func setup(map_size: Vector2i, grid: Vector2i, new_seed: int, regions: int) -> void:
	size = map_size
	sector_grid = grid
	@warning_ignore("integer_division")
	sector_size = Vector2i(map_size.x / grid.x, map_size.y / grid.y)
	seed_value = new_seed
	region_count = regions
	_cells.resize(size.x * size.y)
	_cells.fill(0)
	_corridor.resize(size.x * size.y)
	_corridor.fill(0)
	_sector_slots.resize(grid.x * grid.y)
	_sector_slots.fill(-1)


var boss_slot: int:
	get:
		return region_count + 1


var slot_count: int:
	get:
		return region_count + 2


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < size.x and y < size.y


func is_floor(x: int, y: int) -> bool:
	return in_bounds(x, y) and _cells[y * size.x + x] == 1


## Out-of-bounds counts as wall (solid rock around the map).
func is_wall(x: int, y: int) -> bool:
	return not is_floor(x, y)


func set_floor(x: int, y: int, value: bool) -> void:
	if in_bounds(x, y):
		_cells[y * size.x + x] = 1 if value else 0


func mark_corridor(x: int, y: int) -> void:
	if in_bounds(x, y):
		_corridor[y * size.x + x] = 1


func is_corridor(x: int, y: int) -> bool:
	return in_bounds(x, y) and _corridor[y * size.x + x] == 1


## Floor, or a wall close enough to floor to be seen.
func is_rendered(x: int, y: int) -> bool:
	return in_bounds(x, y) and _render[y * size.x + x] == 1


func sector_of(cell: Vector2i) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(
		clampi(cell.x / sector_size.x, 0, sector_grid.x - 1),
		clampi(cell.y / sector_size.y, 0, sector_grid.y - 1))


func sector_slot(sector: Vector2i) -> int:
	return _sector_slots[sector.y * sector_grid.x + sector.x]


func set_sector_slot(sector: Vector2i, slot: int) -> void:
	_sector_slots[sector.y * sector_grid.x + sector.x] = slot


func slot_at(x: int, y: int) -> int:
	return sector_slot(sector_of(Vector2i(x, y)))


func all_sectors() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in sector_grid.y:
		for x in sector_grid.x:
			result.append(Vector2i(x, y))
	return result


func sector_neighbors(sector: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var other: Vector2i = sector + offset
		if other.x >= 0 and other.y >= 0 and other.x < sector_grid.x and other.y < sector_grid.y:
			result.append(other)
	return result


func floor_cell_count() -> int:
	return _cells.count(1)


## Computes the render mask. Call once after carving.
func finalize() -> void:
	_render.resize(size.x * size.y)
	_render.fill(0)
	for y in size.y:
		for x in size.x:
			if _cells[y * size.x + x] != 1:
				continue
			for dy in range(-RENDER_DISTANCE, RENDER_DISTANCE + 1):
				for dx in range(-RENDER_DISTANCE, RENDER_DISTANCE + 1):
					if in_bounds(x + dx, y + dy):
						_render[(y + dy) * size.x + x + dx] = 1


## Same seed must give the same map; this fingerprint makes that easy to check.
func fingerprint() -> int:
	return hash([_cells, _sector_slots, portal_cell, start_cell])
