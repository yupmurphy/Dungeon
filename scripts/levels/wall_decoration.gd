class_name WallDecoration
extends Node2D
## Pure wall art: no collider, light, floor reservation or per-frame work.

const MOUNT_OFFSET: float = 2.0

var kind: String = "cracks"
var mount_direction: Vector2i = Vector2i.DOWN


func _ready() -> void:
	add_to_group("wall_decoration")
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = WallArt.decoration_texture(kind)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * GameScale.TILE_SIZE / WallArt.SIZE.x
	sprite.position = GameScale.world_vector(Vector2(mount_direction) * MOUNT_OFFSET)
	add_child(sprite)
