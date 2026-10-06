extends StaticBody2D
## Rectangular wall. Position = top-left corner; set `size` per instance.

@export var size: Vector2 = Vector2(16.0, 16.0)

@onready var _visual: ColorRect = $Visual
@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_visual.size = size
	_shape.position = size / 2.0
	(_shape.shape as RectangleShape2D).size = size
