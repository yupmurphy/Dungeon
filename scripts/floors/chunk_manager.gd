class_name ChunkManager
extends Node
## Streams the floor around the player. The whole floor exists as data (FloorLayout); only the
## chunks near the player get tiles and nodes (monsters, props, torches). Far chunks are cleared.
## Killed monsters stay dead when their chunk comes back; living ones respawn at their spawn point.

## Chunks (Chebyshev distance from the player's chunk) that must be loaded.
@export var load_radius: int = 2
## Loaded chunks farther than this are cleared (a gap avoids load/unload flicker at the border).
@export var unload_radius: int = 3
## Spreads the work over frames when the player crosses into a new chunk.
@export var max_loads_per_frame: int = 1

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy.tscn")
const TORCH_SCENE: PackedScene = preload("res://scenes/levels/wall_torch.tscn")
const PROP_SCENE: PackedScene = preload("res://scenes/levels/prop.tscn")

var layout: FloorLayout
## Microseconds spent loading chunks, for the performance test.
var load_time_total_usec: int = 0
var loads_done: int = 0

var _layers: Array[TileMapLayer] = []
var _world: Node2D
var _slot_tints: Array[Color] = []
var _player_chunk: Vector2i = Vector2i(-99999, -99999)
## Vector2i chunk -> Array[Node] of props and torches.
var _loaded: Dictionary = {}
var _queue: Array[Vector2i] = []
## spawn id -> Enemy
var _alive: Dictionary = {}
## spawn id -> true
var _dead: Dictionary = {}


func setup(new_layout: FloorLayout, layers: Array[TileMapLayer], world: Node2D,
		slot_tints: Array[Color], player_position: Vector2) -> void:
	layout = new_layout
	_layers = layers
	_world = world
	_slot_tints = slot_tints
	update_player(player_position)
	# Everything around the start appears at once, no pop-in on the first frame.
	while not _queue.is_empty():
		_load(_queue.pop_front())


func _process(_delta: float) -> void:
	for i in max_loads_per_frame:
		if _queue.is_empty():
			return
		_load(_queue.pop_front())


func update_player(world_position: Vector2) -> void:
	if layout == null:
		return
	var cell := Vector2i((world_position / GameScale.TILE_SIZE).floor())
	var chunk: Vector2i = layout.chunk_of(cell)
	if chunk == _player_chunk:
		return
	_player_chunk = chunk
	_refresh()


func is_loaded(chunk: Vector2i) -> bool:
	return _loaded.has(chunk)


func loaded_count() -> int:
	return _loaded.size()


func is_spawn_alive(spawn_id: int) -> bool:
	return _alive.has(spawn_id)


func is_spawn_dead(spawn_id: int) -> bool:
	return _dead.has(spawn_id)


func _refresh() -> void:
	var count: Vector2i = layout.chunk_count()
	var wanted: Array[Vector2i] = []
	for dy in range(-load_radius, load_radius + 1):
		for dx in range(-load_radius, load_radius + 1):
			var chunk: Vector2i = _player_chunk + Vector2i(dx, dy)
			if chunk.x >= 0 and chunk.y >= 0 and chunk.x < count.x and chunk.y < count.y:
				wanted.append(chunk)
	# Nearest chunks first.
	wanted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _chebyshev(a) < _chebyshev(b))
	_queue = _queue.filter(func(chunk: Vector2i) -> bool: return chunk in wanted)
	for chunk in wanted:
		if not _loaded.has(chunk) and not chunk in _queue:
			_queue.append(chunk)
	for chunk: Vector2i in _loaded.keys():
		if _chebyshev(chunk) > unload_radius:
			_unload(chunk)
	_despawn_stray_monsters()


func _chebyshev(chunk: Vector2i) -> int:
	return maxi(absi(chunk.x - _player_chunk.x), absi(chunk.y - _player_chunk.y))


func _load(chunk: Vector2i) -> void:
	if _loaded.has(chunk):
		return
	var started: int = Time.get_ticks_usec()
	var rect: Rect2i = layout.chunk_rect(chunk)
	var is_wall: Callable = layout.is_wall
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if layout.is_rendered(x, y):
				var index: int = WallTiler.tile_for(is_wall, x, y, _cell_roll(x, y))
				_layers[layout.slot_at(x, y)].set_cell(Vector2i(x, y), 0, TileAtlas.coords(index))

	var nodes: Array[Node] = []
	for spawn_id: int in layout.spawns_by_chunk.get(chunk, []):
		var spawn: FloorLayout.Spawn = layout.spawns[spawn_id]
		match spawn.kind:
			FloorLayout.SpawnKind.MONSTER:
				_spawn_monster(spawn)
			FloorLayout.SpawnKind.PROP:
				var prop: Prop = PROP_SCENE.instantiate()
				prop.tile_index = spawn.tile_index
				prop.solid = spawn.solid
				prop.modulate = _slot_tints[spawn.slot]
				prop.position = _cell_center(spawn.cell)
				_world.add_child(prop)
				nodes.append(prop)
			FloorLayout.SpawnKind.TORCH:
				var torch: Node2D = TORCH_SCENE.instantiate()
				torch.position = _cell_center(spawn.cell)
				_world.add_child(torch)
				nodes.append(torch)
	_loaded[chunk] = nodes
	load_time_total_usec += Time.get_ticks_usec() - started
	loads_done += 1


func _unload(chunk: Vector2i) -> void:
	var rect: Rect2i = layout.chunk_rect(chunk)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if layout.is_rendered(x, y):
				_layers[layout.slot_at(x, y)].erase_cell(Vector2i(x, y))
	for node: Node in _loaded[chunk]:
		if is_instance_valid(node):
			node.queue_free()
	_loaded.erase(chunk)


func _spawn_monster(spawn: FloorLayout.Spawn) -> void:
	if _dead.has(spawn.id) or _alive.has(spawn.id):
		return
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	enemy.data = spawn.monster
	enemy.position = _cell_center(spawn.cell)
	enemy.set_meta("spawn_id", spawn.id)
	enemy.died.connect(_on_monster_died.bind(spawn.id))
	_world.add_child(enemy)
	_alive[spawn.id] = enemy


## Monsters that wandered (or were left) in chunks that are no longer loaded go back to being data.
func _despawn_stray_monsters() -> void:
	for spawn_id: int in _alive.keys():
		var enemy: Enemy = _alive[spawn_id]
		if not is_instance_valid(enemy):
			_alive.erase(spawn_id)
			continue
		var cell := Vector2i((enemy.global_position / GameScale.TILE_SIZE).floor())
		if not _loaded.has(layout.chunk_of(cell)):
			enemy.queue_free()
			_alive.erase(spawn_id)


func _on_monster_died(_enemy: Enemy, spawn_id: int) -> void:
	_dead[spawn_id] = true
	_alive.erase(spawn_id)


## Stable pseudo-random number in [0, 1) per cell, so tiles look the same in whatever order chunks load.
func _cell_roll(x: int, y: int) -> float:
	return float(posmod(hash(Vector3i(x, y, layout.seed_value)), 100000)) / 100000.0


func _cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * GameScale.TILE_SIZE
