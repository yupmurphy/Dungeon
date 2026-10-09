class_name FloorLayout
extends RefCounted
## Result of FloorGenerator + FloorPopulator: a rock/floor grid where every cell belongs to a zone,
## key positions (start, gates, boss arena, portal) and everything that will be spawned (monsters,
## props, torches), grouped by chunk for streaming. Pure data (no nodes), so it can be generated and
## checked without running the game.
##
## Zone "slots": 0..N-1 = FloorData.regions in order, N = boss arena.

enum SpawnKind { MONSTER, PROP, TORCH, WALL_DECOR }


class Spawn:
	var id: int
	var kind: int  # SpawnKind
	var cell: Vector2i
	var slot: int
	var monster: MonsterData
	## Prop art: a Tiny Dungeon tile (tile_index) or, if `art` is set, a NatureArt prop.
	var tile_index: int
	var art: String = ""
	var solid: bool
	## Wall details point toward their adjacent open floor cell.
	var wall_direction: Vector2i = Vector2i.DOWN


## A notable place: camp, mine, nest, oasis, bridge... (shown on the elements map, used by spawners later).
class Feature:
	var kind: StringName
	var cell: Vector2i
	var slot: int


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
## Share of the map that is land (FloorShape), and the two ends of the floor's capsule shape (near opposite corners).
var shape_coverage: float = 1.0
var shape_tips: Array[Vector2i] = []
## 1 = inside the floor's shape (land), 0 = the impassable border around it. Empty = everything is land.
var land: PackedByteArray
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
var features: Array[Feature] = []
var spawns: Array[Spawn] = []
## Vector2i chunk -> Array of spawn indices.
var spawns_by_chunk: Dictionary = {}

## The floor the player is on, for gameplay code that asks about the ground (e.g. slowing terrain).
static var active: FloorLayout
## Blocked ground you can still see across.
const SEE_THROUGH: Array[int] = [Terrain.Type.WATER_DEEP, Terrain.Type.CHASM]
## sight_clear() looks at the line every this much of a tile.
const SIGHT_STEP: float = 0.25

## 1 = walkable, 0 = blocked. Always matches Terrain.walkable(_terrain) except under solid big props.
var _cells: PackedByteArray
## Terrain.Type per cell.
var _terrain: PackedByteArray
var _slots: PackedByteArray
## 1 = built wall (the chieftain hall's back wall): drawn as masonry instead of natural rock. Look only.
var _masonry: PackedByteArray
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
	_terrain.resize(cells)
	_terrain.fill(Terrain.Type.ROCK)
	_slots.resize(cells)
	_slots.fill(255)
	_protected.resize(cells)
	_protected.fill(0)
	_masonry.resize(cells)
	_masonry.fill(0)


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


func terrain_at(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return Terrain.Type.ROCK
	return _terrain[y * size.x + x]


## Sets the ground type; walkability follows the terrain table.
func paint(x: int, y: int, type: int) -> void:
	if in_bounds(x, y):
		var i: int = y * size.x + x
		_terrain[i] = type
		_cells[i] = 1 if Terrain.walkable(type) else 0
		_floor_count = -1


## Rock (or outside the map): what WallTiler draws as walls.
func is_rock(x: int, y: int) -> bool:
	return terrain_at(x, y) == Terrain.Type.ROCK


func is_masonry(x: int, y: int) -> bool:
	return in_bounds(x, y) and _masonry[y * size.x + x] == 1


func mark_masonry(x: int, y: int) -> void:
	if in_bounds(x, y) and is_rock(x, y):
		_masonry[y * size.x + x] = 1


## Inside the floor's shape (not the impassable border around it); `i` = y * size.x + x.
func is_land_index(i: int) -> bool:
	return land.is_empty() or land[i] == 1


func blocks_sight(x: int, y: int) -> bool:
	if not in_bounds(x, y):
		return true
	return Terrain.blocks_sight(_terrain[y * size.x + x]) or _cells[y * size.x + x] == 0 \
		and _terrain[y * size.x + x] not in SEE_THROUGH


## Movement multiplier of the ground at a world position (1.0 off the map or without an active floor).
static func speed_factor_at(world_position: Vector2) -> float:
	if active == null:
		return 1.0
	var cell := Vector2i((world_position / GameScale.TILE_SIZE).floor())
	return Terrain.speed_factor(active.terrain_at(cell.x, cell.y))


## Nothing on the floor grid hides `to` from `from` (world positions): rock, trees, reeds block sight
## (checked every SIGHT_STEP of a tile). True without an active floor.
static func sight_clear(from: Vector2, to: Vector2) -> bool:
	if active == null:
		return true
	var steps: int = maxi(1, ceili(from.distance_to(to) / (GameScale.TILE_SIZE * SIGHT_STEP)))
	for i in range(1, steps):
		var cell := Vector2i((from.lerp(to, float(i) / steps) / GameScale.TILE_SIZE).floor())
		if active.blocks_sight(cell.x, cell.y):
			return false
	return true


func add_feature(kind: StringName, cell: Vector2i, slot: int) -> void:
	var feature := Feature.new()
	feature.kind = kind
	feature.cell = cell
	feature.slot = slot
	features.append(feature)


func count_features(kind: StringName) -> int:
	var count: int = 0
	for feature in features:
		if feature.kind == kind:
			count += 1
	return count


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


func terrain_raw() -> PackedByteArray:
	return _terrain


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
	return hash([_cells, _terrain, _slots, _masonry, portal_cell, start_cell, spawns.size(), features.size()])
