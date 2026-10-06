class_name FloorLayout
extends RefCounted
## Result of FloorGenerator + FloorPopulator: a wall/floor grid, halls, regions, key positions and
## everything that will be spawned (monsters, props, torches), grouped by chunk for streaming.
## Pure data (no nodes), so it can be generated and checked without running the game.
##
## Region "slots": 0 = start zone, 1..N = FloorData.regions in order, N + 1 = boss arena.

enum RoomKind { START, NORMAL, BOSS }
enum SpawnKind { MONSTER, PROP, TORCH }

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

	func area() -> int:
		return rect.size.x * rect.size.y


class Spawn:
	var id: int
	var kind: int  # SpawnKind
	var cell: Vector2i
	var slot: int
	var monster: MonsterData
	var tile_index: int
	var solid: bool


var size: Vector2i
var sector_grid: Vector2i
var sector_size: Vector2i
var chunk_size: int = 32
var seed_value: int
var region_count: int
var rooms: Array[Room] = []
## Pairs of connected sectors [Vector2i, Vector2i] (corridors).
var connections: Array[Array] = []
var start_cell: Vector2i
var portal_cell: Vector2i
var boss_sector: Vector2i
var boss_room: Room
var spawns: Array[Spawn] = []
## Vector2i chunk -> Array of spawn indices.
var spawns_by_chunk: Dictionary = {}

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


# --- Chunks ---

func chunk_of(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / chunk_size), floori(float(cell.y) / chunk_size))


func chunk_rect(chunk: Vector2i) -> Rect2i:
	return Rect2i(chunk * chunk_size, Vector2i(chunk_size, chunk_size)).intersection(Rect2i(Vector2i.ZERO, size))


func chunk_count() -> Vector2i:
	return Vector2i(ceili(float(size.x) / chunk_size), ceili(float(size.y) / chunk_size))


func add_spawn(spawn: Spawn) -> void:
	spawn.id = spawns.size()
	spawns.append(spawn)
	var chunk: Vector2i = chunk_of(spawn.cell)
	if not spawns_by_chunk.has(chunk):
		spawns_by_chunk[chunk] = []
	spawns_by_chunk[chunk].append(spawn.id)


func count_spawns(kind: int) -> int:
	var count: int = 0
	for spawn in spawns:
		if spawn.kind == kind:
			count += 1
	return count


## Computes the render mask (floor dilated by RENDER_DISTANCE). Call once after carving.
## Two separable passes (rows, then columns) keep it fast on big maps.
func finalize() -> void:
	var w: int = size.x
	var h: int = size.y
	var rows := PackedByteArray()
	rows.resize(w * h)
	rows.fill(0)
	for y in h:
		var row: int = y * w
		for x in w:
			if _cells[row + x] == 1:
				for dx in range(maxi(x - RENDER_DISTANCE, 0), mini(x + RENDER_DISTANCE, w - 1) + 1):
					rows[row + dx] = 1
	_render.resize(w * h)
	_render.fill(0)
	for y in h:
		for x in w:
			if rows[y * w + x] == 1:
				for dy in range(maxi(y - RENDER_DISTANCE, 0), mini(y + RENDER_DISTANCE, h - 1) + 1):
					_render[dy * w + x] = 1


## Same seed must give the same map; this fingerprint makes that easy to check.
func fingerprint() -> int:
	return hash([_cells, _sector_slots, portal_cell, start_cell, spawns.size()])
