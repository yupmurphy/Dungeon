@tool
class_name Prop
extends StaticBody2D
## Decoration: either a tile of the Kenney sheet (`tile_index`: barrel, tombstone, chest...) or, when
## `art` is set, a NatureArt prop (tree, tent, crystal, bones...) that may cover several tiles and give
## light. The node stands in the middle of the prop's footprint; `solid` decides whether it blocks.

## Footprint that blocks movement for a one-tile Kenney prop, in reference pixels (see GameScale).
const COLLISION_SIZE: Vector2 = Vector2(12, 8)
const FOG_DRIFT: float = 6.0

@export var tile_index: int = 66:
	set(value):
		tile_index = value
		_apply()
@export var art: String = "":
	set(value):
		art = value
		_apply()
@export var solid: bool = true:
	set(value):
		solid = value
		_apply()

var _time: float = 0.0


func _ready() -> void:
	_apply()
	set_process(art == "fog")
	_time = randf() * 20.0


func _process(delta: float) -> void:
	# Fog drifts slowly back and forth.
	_time += delta
	var sprite := $Sprite2D as Sprite2D
	sprite.position.x = sin(_time * 0.3) * GameScale.world(FOG_DRIFT)


func _apply() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if sprite == null or shape == null:
		return
	var pixel: float = float(GameScale.TILE_SIZE) / TileAtlas.TILE_SIZE
	sprite.scale = Vector2.ONE * pixel
	shape.set_deferred("disabled", not solid)
	if art.is_empty():
		sprite.texture = load(TileAtlas.TEXTURE_PATH)
		sprite.region_enabled = true
		sprite.region_rect = TileAtlas.region(tile_index)
		sprite.position = Vector2.ZERO
		(shape.shape as RectangleShape2D).size = GameScale.world_vector(COLLISION_SIZE)
		shape.position = Vector2(0, GameScale.world(3.0))
		return
	var info: Dictionary = NatureArt.prop_info(art)
	var footprint := Vector2(info["footprint"]) * GameScale.TILE_SIZE
	var size := Vector2(info["size"]) * pixel
	sprite.texture = NatureArt.prop_texture(art)
	sprite.region_enabled = false
	# The picture stands on the bottom edge of the footprint (tall things rise above it).
	sprite.position = Vector2(0, footprint.y / 2.0 - size.y / 2.0)
	(shape.shape as RectangleShape2D).size = footprint * 0.8
	shape.position = Vector2.ZERO
	if art == "fog":
		z_index = 5
		sprite.position.y = 0.0
	if info.has("light") and get_node_or_null("Light") == null:
		_add_light(info["light"])


func _add_light(color: Color) -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 128
	texture.height = 128
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	var light := PointLight2D.new()
	light.name = "Light"
	light.color = color
	light.energy = 0.8
	light.texture = texture
	light.texture_scale = GameScale.world(56.0) * 2.0 / 128.0
	add_child(light)
