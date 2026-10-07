class_name Minimap
extends Control
## Corner minimap: the explored map around the player, 2 pixels per tile.

const PIXELS_PER_TILE: float = 2.0
const BACKGROUND: Color = Color(0, 0, 0, 0.65)
const BORDER: Color = Color(1, 1, 1, 0.35)

var exploration: MapSource
var player: Node2D
## Hidden while the big map is open.
var suppressed: bool = false


func _process(_delta: float) -> void:
	visible = exploration != null and exploration.map_texture != null and not suppressed
	if visible:
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	if exploration == null or exploration.map_texture == null or player == null:
		return
	var center: Vector2 = player.global_position / GameScale.TILE_SIZE
	var view_tiles: Vector2 = size / PIXELS_PER_TILE
	var source := Rect2(center - view_tiles / 2.0, view_tiles)
	draw_texture_rect_region(exploration.map_texture, Rect2(Vector2.ZERO, size), source)
	draw_circle(size / 2.0, 2.0, Color.WHITE)
	draw_rect(Rect2(Vector2.ZERO, size), BORDER, false, 1.0)
