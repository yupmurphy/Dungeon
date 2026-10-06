class_name FloorLevel
extends Node2D
## One dungeon floor: generates the whole layout from FloorData + seed (as data), lets ChunkManager
## stream tiles and nodes around the player, and handles the floor-level keys (R restart, F1-F4 debug).

const TILESET: TileSet = preload("res://resources/tilesets/dungeon_tileset.tres")
const PORTAL_SCENE: PackedScene = preload("res://scenes/floors/portal.tscn")
const MAX_SEED: int = 1000000

## Seed for the next load. Survives scene reloads: R keeps the same layout, F1 picks a new one.
static var next_seed: int = -1
static var _command_line_seed_used: bool = false

@export var floor_data: FloorData

var layout: FloorLayout
var current_seed: int
var portal: Portal
var chunks: ChunkManager

var _current_slot: int = -1

@onready var _tiles: Node2D = $Tiles
@onready var _world: Node2D = $World
@onready var _player: Player = $World/Player
@onready var _exploration: ExplorationMap = $Exploration
@onready var _activator: EnemyActivator = $EnemyActivator
@onready var _hud: Node = $HUD


func _ready() -> void:
	chunks = $ChunkManager
	current_seed = _pick_seed()
	next_seed = current_seed
	var started: int = Time.get_ticks_msec()
	layout = FloorGenerator.generate(floor_data, current_seed)
	var generated: int = Time.get_ticks_msec()

	_player.global_position = _cell_center(layout.start_cell)
	_player.get_node("Camera2D").reset_smoothing()
	get_tree().call_group("game_camera", "set_room_limits", Rect2i(Vector2i.ZERO, layout.size * GameScale.TILE_SIZE))
	chunks.setup(layout, _create_layers(), _world, _slot_tints(), _player.global_position)
	portal = PORTAL_SCENE.instantiate()
	portal.position = _cell_center(layout.portal_cell)
	_world.add_child(portal)

	_exploration.setup(layout, _slot_colors(), _legend())
	_exploration.update_player(_player.global_position)
	_activator.refresh()
	_hud.setup_floor(floor_data.display_name, current_seed)
	print("%s: seed %d, %dx%d tiles, generated in %d ms, first chunks in %d ms, %d monsters planned" % [
		floor_data.display_name, current_seed, layout.size.x, layout.size.y, generated - started,
		Time.get_ticks_msec() - generated, layout.count_spawns(FloorLayout.SpawnKind.MONSTER)])


func _physics_process(_delta: float) -> void:
	chunks.update_player(_player.global_position)
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


## One TileMapLayer per zone, tinted with the zone's color. ChunkManager fills them.
func _create_layers() -> Array[TileMapLayer]:
	var layers: Array[TileMapLayer] = []
	var tints: Array[Color] = _slot_tints()
	for slot in layout.slot_count:
		var layer := TileMapLayer.new()
		layer.name = "Region%d" % slot
		layer.tile_set = TILESET
		layer.modulate = tints[slot]
		_tiles.add_child(layer)
		layers.append(layer)
	return layers


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


func _slot_tints() -> Array[Color]:
	var tints: Array[Color] = [floor_data.start_tile_tint]
	for region in floor_data.regions:
		tints.append(region.tile_tint)
	tints.append(floor_data.boss_tile_tint)
	return tints


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


func _cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * GameScale.TILE_SIZE
