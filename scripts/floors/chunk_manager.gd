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

const NATURE_SOURCE: int = FloorTiles.NATURE_SOURCE
## Share of dense-forest border cells that get a tree crown.
const THICKET_CANOPY_SHARE: float = 0.45

## One tinted layer per zone for rock and cave floor (dungeon tiles); one untinted layer for nature.
var _layers: Array[TileMapLayer] = []
var _nature: TileMapLayer
## Tree canopies (big pictures), y-sorted with the player and monsters.
var _canopies: TileMapLayer
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


func setup(new_layout: FloorLayout, layers: Array[TileMapLayer], nature: TileMapLayer, canopies: TileMapLayer,
		world: Node2D, slot_tints: Array[Color], player_position: Vector2) -> void:
	layout = new_layout
	_layers = layers
	_nature = nature
	_canopies = canopies
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
	var is_rock: Callable = layout.is_rock
	var terrain: PackedByteArray = layout.terrain_raw()
	var slots: PackedByteArray = layout.slots_raw()
	var w: int = layout.size.x
	var deep_rock: Vector2i = TileAtlas.coords(WallTiler.WALL_FILL)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			var i: int = y * w + x
			var type: int = terrain[i]
			if type == Terrain.Type.ROCK:
				# Natural hub rock uses a complete neighbor mask, not the masonry edge priority.
				var layer: TileMapLayer = _layers[slots[i]]
				if slots[i] == layout.hub_slot and not layout.is_masonry(x, y):
					var mask: int = 0 if _is_deep_rock(terrain, w, x, y) else CaveArt.open_mask(is_rock, x, y)
					var tile: int = CaveArt.wall_index(mask, _cell_roll(x, y))
					layer.set_cell(cell, FloorTiles.CAVE_WALL_SOURCE, CaveArt.atlas_coords(tile))
				elif _is_deep_rock(terrain, w, x, y):
					layer.set_cell(cell, 0, deep_rock)  # fast path, no autotiling needed
				else:
					layer.set_cell(cell, 0, TileAtlas.coords(WallTiler.tile_for(is_rock, x, y, _cell_roll(x, y))))
			elif type == Terrain.Type.CAVE:
				if slots[i] == layout.hub_slot:
					var index: int = CaveArt.floor_index(is_rock, x, y, _cell_roll(x, y))
					_layers[slots[i]].set_cell(cell, FloorTiles.CAVE_FLOOR_SOURCE, CaveArt.atlas_coords(index))
				else:
					var index: int = WallTiler.floor_tile(_cell_roll(x, y))
					if y > 0 and terrain[i - w] == Terrain.Type.ROCK and WallTiler.is_face(is_rock, x, y - 1):
						index = WallTiler.FLOOR_UNDER_WALL
					_layers[slots[i]].set_cell(cell, 0, TileAtlas.coords(index))
			else:
				# Nature ground from the procedural atlas, not tinted.
				var roll: float = _cell_roll(x, y)
				_nature.set_cell(cell, NATURE_SOURCE, NatureArt.atlas_coords(Terrain.art_tile(type, roll)))
				# Dense forest in the border gets crowns too (not on every cell, so it doesn't turn into one blob).
				if type == Terrain.Type.TREE or (type == Terrain.Type.THICKET and roll < THICKET_CANOPY_SHARE):
					var variant: int = int(roll * 1000.0) % NatureArt.CANOPY_VARIANTS
					_canopies.set_cell(cell, FloorTiles.CANOPY_SOURCE, Vector2i(variant, 0))

	var nodes: Array[Node] = []
	for spawn_id: int in layout.spawns_by_chunk.get(chunk, []):
		var spawn: FloorLayout.Spawn = layout.spawns[spawn_id]
		match spawn.kind:
			FloorLayout.SpawnKind.MONSTER:
				_spawn_monster(spawn)
			FloorLayout.SpawnKind.PROP:
				var prop: Prop = PROP_SCENE.instantiate()
				prop.tile_index = spawn.tile_index
				prop.art = spawn.art
				prop.solid = spawn.solid
				var footprint := Vector2i.ONE
				if spawn.art.is_empty():
					prop.modulate = _slot_tints[spawn.slot]
				else:
					footprint = NatureArt.prop_info(spawn.art)["footprint"]
				# Centered on its footprint (big props cover several tiles from their top-left cell).
				prop.position = (Vector2(spawn.cell) + Vector2(footprint) / 2.0) * GameScale.TILE_SIZE
				_world.add_child(prop)
				nodes.append(prop)
			FloorLayout.SpawnKind.TORCH:
				var torch := TORCH_SCENE.instantiate() as WallTorch
				torch.mount_direction = spawn.wall_direction
				torch.position = _cell_center(spawn.cell)
				_world.add_child(torch)
				nodes.append(torch)
			FloorLayout.SpawnKind.WALL_DECOR:
				var decoration := WallDecoration.new()
				decoration.kind = spawn.art
				decoration.mount_direction = spawn.wall_direction
				decoration.position = _cell_center(spawn.cell)
				_world.add_child(decoration)
				nodes.append(decoration)
	_loaded[chunk] = nodes
	load_time_total_usec += Time.get_ticks_usec() - started
	loads_done += 1


func _unload(chunk: Vector2i) -> void:
	var rect: Rect2i = layout.chunk_rect(chunk)
	var slots: PackedByteArray = layout.slots_raw()
	var w: int = layout.size.x
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			_layers[slots[y * w + x]].erase_cell(Vector2i(x, y))
			_nature.erase_cell(Vector2i(x, y))
			_canopies.erase_cell(Vector2i(x, y))
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


## True if the cell and everything WallTiler looks at around it (x-1..x+1, y-1..y+2) is rock.
func _is_deep_rock(terrain: PackedByteArray, w: int, x: int, y: int) -> bool:
	if x < 1 or y < 1 or x >= w - 1 or y >= layout.size.y - 2:
		return false
	const ROCK: int = Terrain.Type.ROCK
	for dy in range(-1, 3):
		var row: int = (y + dy) * w + x
		if terrain[row - 1] != ROCK or terrain[row] != ROCK or terrain[row + 1] != ROCK:
			return false
	return true


## Stable pseudo-random number in [0, 1) per cell, so tiles look the same in whatever order chunks load.
func _cell_roll(x: int, y: int) -> float:
	return float(posmod(hash(Vector3i(x, y, layout.seed_value)), 100000)) / 100000.0


func _cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * GameScale.TILE_SIZE
