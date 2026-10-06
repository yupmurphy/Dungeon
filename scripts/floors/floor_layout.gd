class_name FloorLayout
extends RefCounted
## Result of FloorGenerator + FloorPopulator: a rock/floor grid where every cell belongs to a zone,
## key positions (start, gates, boss arena, portal) and everything that will be spawned (monsters,
## props, torches), grouped by chunk for streaming. Pure data (no nodes), so it can be generated and
## checked without running the game.
##
## Zone "slots": 0..N-1 = FloorData.regions in order, N = boss arena.

enum SpawnKind { MONSTER, PROP, TORCH }


class Spawn:
	var id: int
	var kind: int  # SpawnKind
	var cell: Vector2i
	var slot: int
	var monster: MonsterData
	var tile_index: int
	var solid: bool


## A passage through the rock ring around the closed zone, leading into one open zone.
class Gate:
	## Cell in the middle of the ring.
	var cell: Vector2i
	## First open-zone floor cell outside the ring.
	var outside: Vector2i
	## The open zone this gate leads to.
	var slot: int


var size: Vector2i
var chunk_size: int = 32
var seed_value: int
var region_count: int
var center: Vector2i
var start_cell: Vector2i
var portal_cell: Vector2i
var boss_center: Vector2i
## Bounding box of the arena (walls included).
var boss_rect: Rect2i
## Cell in the middle of the arena's only entrance.
var boss_entrance: Vector2i
## Slot of the open zone that holds the arena.
var boss_zone: int
## Slot of the closed zone in the middle (the start zone).
var hub_slot: int
var gates: Array[Gate] = []
var spawns: Array[Spawn] = []
## Vector2i chunk -> Array of spawn indices.
var spawns_by_chunk: Dictionary = {}

## 1 = floor, 0 = rock.
var _cells: PackedByteArray
var _slots: PackedByteArray
## 1 = must stay as it is (gate passages, arena entrance): no props, no digging.
var _protected: PackedByteArray
var _floor_count: int = -1


func setup(map_size: Vector2i, new_seed: int, regions: int) -> void:
	size = map_size
	seed_value = new_seed
	region_count = regions
	@warning_ignore("integer_division")
	center = Vector2i(size.x / 2, size.y / 2)
	var cells: int = size.x * size.y
	_cells.resize(cells)
	_cells.fill(0)
	_slots.resize(cells)
	_slots.fill(255)
	_protected.resize(cells)
	_protected.fill(0)


var boss_slot: int:
	get:
		return region_count


var slot_count: int:
	get:
		return region_count + 1


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < size.x and y < size.y


func is_floor(x: int, y: int) -> bool:
	return in_bounds(x, y) and _cells[y * size.x + x] == 1


## Out-of-bounds counts as rock.
func is_wall(x: int, y: int) -> bool:
	return not is_floor(x, y)


func set_floor(x: int, y: int, value: bool) -> void:
	if in_bounds(x, y):
		_cells[y * size.x + x] = 1 if value else 0
		_floor_count = -1


## The whole map is drawn: rock is part of its zone, there is no empty space.
func is_rendered(x: int, y: int) -> bool:
	return in_bounds(x, y)


func slot_at(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return 0
	return _slots[y * size.x + x]


func set_slot(x: int, y: int, slot: int) -> void:
	if in_bounds(x, y):
		_slots[y * size.x + x] = slot


func is_protected(x: int, y: int) -> bool:
	return in_bounds(x, y) and _protected[y * size.x + x] == 1


func protect(x: int, y: int) -> void:
	if in_bounds(x, y):
		_protected[y * size.x + x] = 1


func floor_cell_count() -> int:
	if _floor_count < 0:
		_floor_count = _cells.count(1)
	return _floor_count


## Number of cells (floor + rock) per slot.
func slot_cell_counts() -> PackedInt32Array:
	var counts := PackedInt32Array()
	counts.resize(slot_count)
	counts.fill(0)
	for slot in _slots:
		if slot < slot_count:
			counts[slot] += 1
	return counts


# --- Raw access for the generator (fast loops over the whole map) ---

func cells_raw() -> PackedByteArray:
	return _cells


func set_cells_raw(cells: PackedByteArray) -> void:
	_cells = cells
	_floor_count = -1


func slots_raw() -> PackedByteArray:
	return _slots


func protected_raw() -> PackedByteArray:
	return _protected


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


## Same seed must give the same map; this fingerprint makes that easy to check.
func fingerprint() -> int:
	return hash([_cells, _slots, portal_cell, start_cell, spawns.size()])
