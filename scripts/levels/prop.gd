@tool
class_name Prop
extends StaticBody2D
## Decoration taken from the tilesheet (barrel, tombstone, chest...). Choose it with `tile_index`;
## `solid` decides whether it blocks movement.

## Footprint that blocks movement, in reference pixels (see GameScale).
const COLLISION_SIZE: Vector2 = Vector2(12, 8)

@export var tile_index: int = 66:
	set(value):
		tile_index = value
		_apply()
@export var solid: bool = true:
	set(value):
		solid = value
		_apply()


func _ready() -> void:
	_apply()


func _apply() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		sprite.region_rect = TileAtlas.region(tile_index)
		# Props fill one map tile, whatever the resolution of the art.
		sprite.scale = Vector2.ONE * GameScale.TILE_SIZE / TileAtlas.TILE_SIZE
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null:
		shape.set_deferred("disabled", not solid)
		(shape.shape as RectangleShape2D).size = GameScale.world_vector(COLLISION_SIZE)
		shape.position.y = GameScale.world(3.0)
