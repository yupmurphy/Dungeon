class_name ChargeBar
extends Node2D
## Small bar above a character showing how charged an ability is (the player's dash).
## Sizes are reference pixels (GameScale). Hidden while not charging.

const WIDTH: float = 16.0
const HEIGHT: float = 2.0
## Above the character's center.
const OFFSET_Y: float = -22.0
const BACK_COLOR: Color = Color(0.0, 0.0, 0.0, 0.6)
const FILL_COLOR: Color = Color(0.85, 0.9, 1.0)
const FULL_COLOR: Color = Color(1.0, 0.85, 0.3)

## 0..1
var ratio: float = 0.0:
	set(value):
		ratio = clampf(value, 0.0, 1.0)
		queue_redraw()


func _ready() -> void:
	z_index = 5
	hide()


func _draw() -> void:
	var size := GameScale.world_vector(Vector2(WIDTH, HEIGHT))
	var top_left := Vector2(-size.x * 0.5, GameScale.world(OFFSET_Y))
	draw_rect(Rect2(top_left, size), BACK_COLOR)
	draw_rect(Rect2(top_left, Vector2(size.x * ratio, size.y)), FULL_COLOR if ratio >= 1.0 else FILL_COLOR)
