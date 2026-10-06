class_name FloorLevel
extends Node2D
## One dungeon floor: generates the layout from FloorData + seed, paints it, spawns everything
## and handles the floor-level keys (R restart, F1-F4 debug).

const TILESET: TileSet = preload("res://resources/tilesets/dungeon_tileset.tres")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy.tscn")
const TORCH_SCENE: PackedScene = preload("res://scenes/levels/wall_torch.tscn")
const PROP_SCENE: PackedScene = preload("res://scenes/levels/prop.tscn")
const PORTAL_SCENE: PackedScene = preload("res://scenes/floors/portal.tscn")
const PROP_TILES: Array[int] = [66, 66, 65, 89]  # barrel (twice as likely), tombstone, chest
const MAX_SEED: int = 1000000

## Seed for the next load. Survives scene reloads: R keeps the same layout, F1 picks a new one.
static var next_seed: int = -1
static var _command_line_seed_used: bool = false

@export var floor_data: FloorData

var layout: FloorLayout
var current_seed: int
var portal: Portal

var _current_slot: int = -1
var _rng := RandomNumberGenerator.new()

@onready var _tiles: Node2D = $Tiles
@onready var _world: Node2D = $World
@onready var _player: Player = $World/Player
@onready var _exploration: ExplorationMap = $Exploration
@onready var _activator: EnemyActivator = $EnemyActivator
@onready var _hud: Node = $HUD


func _ready() -> void:
	current_seed = _pick_seed()
	next_seed = current_seed
	var started: int = Time.get_ticks_msec()
	layout = FloorGenerator.generate(floor_data, current_seed)
	var generated: int = Time.get_ticks_msec()
	_rng.seed = current_seed
	_paint()
	_spawn_contents()
	_player.global_position = _cell_center(layout.start_cell)
	_player.get_node("Camera2D").reset_smoothing()
	get_tree().call_group("game_camera", "set_room_limits", Rect2i(Vector2i.ZERO, layout.size * TileAtlas.TILE_SIZE))
	_exploration.setup(layout, _slot_colors(), _legend())
	_exploration.update_player(_player.global_position)
	_activator.refresh()
	_hud.setup_floor(floor_data.display_name, current_seed)
	print("%s: seed %d, generated in %d ms, built in %d ms, %d enemies" % [
		floor_data.display_name, current_seed, generated - started, Time.get_ticks_msec() - generated,
		get_tree().get_nodes_in_group("enemy").size()])


func _physics_process(_delta: float) -> void:
	_exploration.update_player(_player.global_position)
	var cell: Vector2i = _exploration.world_to_cell(_player.global_position)
	var slot: int = layout.slot_at(cell.x, cell.y)
	if slot != _current_slot:
		_current_slot = slot
		_hud.show_region(_slot_name(slot), _slot_colors()[slot])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed("debug_new_seed"):
		next_seed = randi() % MAX_SEED
		get_tree().reload_current_scene()
	elif event.is_action_pressed("debug_reveal_map"):
		_exploration.reveal_all()
	elif event.is_action_pressed("debug_invincible"):
		_player.hurtbox.god_mode = not _player.hurtbox.god_mode
		_hud.set_invincible(_player.hurtbox.god_mode)
	elif event.is_action_pressed("debug_show_seed"):
		DisplayServer.clipboard_set(str(current_seed))
		print("Seed: ", current_seed)
		_hud.toggle_seed()


func _pick_seed() -> int:
	if not _command_line_seed_used:
		_command_line_seed_used = true
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--seed="):
				return int(arg.trim_prefix("--seed="))
	if next_seed >= 0:
		return next_seed
	return randi() % MAX_SEED


# --- Slots: 0 = start, 1..N = regions, N + 1 = boss arena ---

func _region(slot: int) -> RegionData:
	if slot >= 1 and slot <= floor_data.regions.size():
		return floor_data.regions[slot - 1]
	return null


func _slot_name(slot: int) -> String:
	if slot == FloorLayout.START_SLOT:
		return floor_data.start_name
	if slot == layout.boss_slot:
		return floor_data.boss_area_name
	return _region(slot).display_name


func _slot_tint(slot: int) -> Color:
	if slot == FloorLayout.START_SLOT:
		return floor_data.start_tile_tint
	if slot == layout.boss_slot:
		return floor_data.boss_tile_tint
	return _region(slot).tile_tint


func _slot_colors() -> Array[Color]:
	var colors: Array[Color] = [floor_data.start_map_color]
	for region in floor_data.regions:
		colors.append(region.map_color)
	colors.append(floor_data.boss_map_color)
	return colors


func _legend() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var colors: Array[Color] = _slot_colors()
	for slot in layout.slot_count:
		entries.append({"name": _slot_name(slot), "color": colors[slot]})
	return entries


# --- Building ---

## One TileMapLayer per region, tinted with the region's color.
func _paint() -> void:
	var layers: Array[TileMapLayer] = []
	for slot in layout.slot_count:
		var layer := TileMapLayer.new()
		layer.name = "Region%d" % slot
		layer.tile_set = TILESET
		layer.modulate = _slot_tint(slot)
		_tiles.add_child(layer)
		layers.append(layer)
	var is_wall: Callable = layout.is_wall
	for y in layout.size.y:
		for x in layout.size.x:
			if layout.is_rendered(x, y):
				var index: int = WallTiler.tile_for(is_wall, x, y, _rng.randf())
				layers[layout.slot_at(x, y)].set_cell(Vector2i(x, y), 0, TileAtlas.coords(index))


func _spawn_contents() -> void:
	for room in layout.rooms:
		_spawn_torches(room)
		match room.kind:
			FloorLayout.RoomKind.NORMAL:
				_spawn_monsters(room)
				_spawn_props(room)
			FloorLayout.RoomKind.BOSS:
				portal = PORTAL_SCENE.instantiate()
				portal.position = _cell_center(layout.portal_cell)
				_world.add_child(portal)


## Torches on the brick face above the room's top edge.
func _spawn_torches(room: FloorLayout.Room) -> void:
	var count: int = 4 if room.kind == FloorLayout.RoomKind.BOSS else _rng.randi_range(1, 2)
	var y: int = room.rect.position.y - 1
	@warning_ignore("integer_division")
	var spacing: int = room.rect.size.x / (count + 1)
	for i in count:
		var x: int = room.rect.position.x + spacing * (i + 1)
		if WallTiler.is_face(layout.is_wall, x, y):
			var torch: Node2D = TORCH_SCENE.instantiate()
			torch.position = _cell_center(Vector2i(x, y))
			_world.add_child(torch)


func _spawn_monsters(room: FloorLayout.Room) -> void:
	var region: RegionData = _region(room.slot)
	if region == null or region.monsters.is_empty():
		return
	var count: int = _rng.randi_range(region.min_monsters_per_room, region.max_monsters_per_room)
	for i in count:
		var cell: Vector2i = _random_free_cell(room, 2)
		if cell.x < 0:
			continue
		var enemy: Enemy = ENEMY_SCENE.instantiate()
		enemy.data = region.monsters[_rng.randi() % region.monsters.size()]
		enemy.position = _cell_center(cell)
		_world.add_child(enemy)


## A few props tucked into the room corners.
func _spawn_props(room: FloorLayout.Room) -> void:
	var rect: Rect2i = room.rect
	var corners: Array[Vector2i] = [
		rect.position + Vector2i(1, 1), Vector2i(rect.end.x - 2, rect.position.y + 1),
		Vector2i(rect.position.x + 1, rect.end.y - 2), rect.end - Vector2i(2, 2)]
	for corner in corners:
		if _rng.randf() < 0.4 and layout.is_floor(corner.x, corner.y) and not layout.is_corridor(corner.x, corner.y):
			var prop: Prop = PROP_SCENE.instantiate()
			prop.tile_index = PROP_TILES[_rng.randi() % PROP_TILES.size()]
			prop.position = _cell_center(corner)
			_world.add_child(prop)


## Random floor cell inside the room, `margin` tiles away from its walls. (-1, -1) if none found.
func _random_free_cell(room: FloorLayout.Room, margin: int) -> Vector2i:
	var inner: Rect2i = room.rect.grow(-margin)
	for attempt in 20:
		var cell := Vector2i(
			_rng.randi_range(inner.position.x, inner.end.x - 1),
			_rng.randi_range(inner.position.y, inner.end.y - 1))
		if layout.is_floor(cell.x, cell.y):
			return cell
	return Vector2i(-1, -1)


func _cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TileAtlas.TILE_SIZE
