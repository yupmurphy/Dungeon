@tool
class_name TownLighting
extends CanvasModulate
## Day and night for the town. Night darkens everything (this CanvasModulate) and turns on every light in the
## "town_lights" group (lanterns, forge, lit windows: nodes with a `lit` property). N toggles (debug).

const DAY_COLOR: Color = Color(1, 1, 1, 1)
const NIGHT_COLOR: Color = Color(0.22, 0.24, 0.42, 1)
## Seconds to fade between day and night.
const FADE_TIME: float = 1.5
const LIGHT_TEXTURE_SIZE: int = 128

static var _light_texture: GradientTexture2D

@export var night: bool = false:
	set(value):
		night = value
		if is_inside_tree():
			_apply(Engine.is_editor_hint())


static func light_texture() -> Texture2D:
	if _light_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		_light_texture = GradientTexture2D.new()
		_light_texture.gradient = gradient
		_light_texture.fill = GradientTexture2D.FILL_RADIAL
		_light_texture.fill_from = Vector2(0.5, 0.5)
		_light_texture.fill_to = Vector2(1.0, 0.5)
		_light_texture.width = LIGHT_TEXTURE_SIZE
		_light_texture.height = LIGHT_TEXTURE_SIZE
	return _light_texture


func _ready() -> void:
	# Deferred: the lights and the player are later siblings, not ready yet.
	_apply.call_deferred(true)


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event.is_action_pressed("toggle_night"):
		night = not night


func _apply(instant: bool) -> void:
	var target: Color = NIGHT_COLOR if night else DAY_COLOR
	if instant:
		color = target
	else:
		create_tween().tween_property(self, "color", target, FADE_TIME)
	if Engine.is_editor_hint():
		return
	for node in get_tree().get_nodes_in_group("town_lights"):
		node.set("lit", night)
	# The player's own torch only matters in the dark.
	for player in get_tree().get_nodes_in_group("player"):
		var torch := player.get_node_or_null("Torch") as PointLight2D
		if torch != null:
			torch.visible = night
