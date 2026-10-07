class_name TownDecoration
extends Node2D
## One reusable prop scene; solid footprints are also included in the pure town path data.
var data: TownPropData

func _ready() -> void:
	add_to_group("town_decoration")
	var sprite := Sprite2D.new()
	sprite.texture = TownArt.prop_texture(data)
	sprite.scale = GameScale.world_vector(Vector2.ONE)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position.y = -sprite.texture.get_height() * sprite.scale.y / 2.0
	add_child(sprite)
	if data.solid:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(data.footprint.size) * GameScale.TILE_SIZE
		shape.shape = rect
		shape.position.y = -rect.size.y / 2.0
		body.add_child(shape)
		add_child(body)
