extends CanvasLayer
## Health and exhaustion bars, minimap, big map (M), character sheet (C), region name, debug info and the death message.
## Binds to the node in group "player" and to the map (group "map_source": ExplorationMap or TownMap).

const REGION_FADE_IN: float = 0.3
const REGION_HOLD: float = 1.8
const REGION_FADE_OUT: float = 0.8
const EXHAUSTION_COLOR: Color = Color(0.95, 0.8, 0.2)
const EXHAUSTION_TIRED_COLOR: Color = Color(0.95, 0.35, 0.1)

var _seed: int = -1
var _show_seed: bool = false
var _invincible: bool = false
var _region_tween: Tween

@onready var _health_bar: StatBar = $Root/HealthBar
@onready var _exhaustion_bar: StatBar = $Root/ExhaustionBar
@onready var _death_panel: Control = $Root/DeathPanel
@onready var _minimap: Minimap = $Root/Minimap
@onready var _map_overlay: MapOverlay = $Root/MapOverlay
@onready var _region_label: Label = $Root/RegionLabel
@onready var _debug_label: Label = $Root/DebugLabel
@onready var _character_sheet: CharacterSheet = $Root/CharacterSheet


func _ready() -> void:
	_death_panel.hide()
	_map_overlay.hide()
	_refresh_debug()
	_bind.call_deferred()


func _bind() -> void:
	# The scene may already be gone again (fast restarts / scene switches).
	if not is_inside_tree():
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		push_warning("HUD: no node in group 'player' found")
		return
	player.health.health_changed.connect(_on_health_changed)
	player.exhaustion.exhaustion_changed.connect(_on_exhaustion_changed)
	player.died.connect(_death_panel.show)
	_on_health_changed(player.health.current_health, player.health.max_health)
	_on_exhaustion_changed(player.exhaustion.current, ExhaustionComponent.MAX)
	_character_sheet.player = player

	var exploration := get_tree().get_first_node_in_group("map_source") as MapSource
	_minimap.exploration = exploration
	_minimap.player = player
	_map_overlay.exploration = exploration
	_map_overlay.player = player


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map") and _map_overlay.exploration != null:
		_map_overlay.visible = not _map_overlay.visible
		_minimap.suppressed = _map_overlay.visible
		get_viewport().set_input_as_handled()


func setup_floor(floor_name: String, seed_value: int) -> void:
	_map_overlay.title = "%s - Map" % floor_name
	_seed = seed_value
	_refresh_debug()


## Title of the big map (M).
func set_map_title(title: String) -> void:
	_map_overlay.title = title


## Region name fades in under the bars when the player walks into a new region.
func show_region(region_name: String, color: Color) -> void:
	_region_label.text = region_name
	_region_label.add_theme_color_override("font_color", color.lightened(0.3))
	if _region_tween != null:
		_region_tween.kill()
	_region_tween = create_tween()
	_region_tween.tween_property(_region_label, "modulate:a", 1.0, REGION_FADE_IN)
	_region_tween.tween_interval(REGION_HOLD)
	_region_tween.tween_property(_region_label, "modulate:a", 0.0, REGION_FADE_OUT)


func toggle_seed() -> void:
	_show_seed = not _show_seed
	_refresh_debug()


func set_invincible(enabled: bool) -> void:
	_invincible = enabled
	_refresh_debug()


func _refresh_debug() -> void:
	var lines: PackedStringArray = []
	if _invincible:
		lines.append("INVINCIBLE (F3)")
	if _show_seed and _seed >= 0:
		lines.append("Seed: %d  (copied to clipboard, F4)" % _seed)
	_debug_label.text = "\n".join(lines)


func _on_health_changed(current: float, maximum: float) -> void:
	_health_bar.set_ratio(current / maximum)


## Fills up as you get tired; another color above the tired threshold.
func _on_exhaustion_changed(current: float, maximum: float) -> void:
	_exhaustion_bar.set_ratio(current / maximum)
	_exhaustion_bar.set_fill_color(EXHAUSTION_TIRED_COLOR if current > ExhaustionComponent.TIRED_THRESHOLD else EXHAUSTION_COLOR)
