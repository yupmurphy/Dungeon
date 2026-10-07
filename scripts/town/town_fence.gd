@tool
class_name TownFence
extends Node2D
## A straight fence (wooden rails, pickets or low stone wall) from the LPC fence kit. Horizontal: the node is
## the bottom-left end and the fence runs `length` tiles to the right. Vertical: it runs `length` tiles up.

const TILE: int = 32
## Thickness of the blocking strip, in pixels.
const THICKNESS: float = 8.0

@export_range(1, 60) var length: int = 4:
	set(value):
		length = value
		queue_redraw()
@export var vertical: bool = false:
	set(value):
		vertical = value
		queue_redraw()
@export_enum("rail", "picket", "stone") var style: String = "picket":
	set(value):
		style = value
		queue_redraw()
## Leave a gap (a gate) at this tile (-1 = none).
@export var gap_at: int = -1:
	set(value):
		gap_at = value
		queue_redraw()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var body := StaticBody2D.new()
	body.name = "Collision"
	add_child(body)
	for i in length:
		if i == gap_at:
			continue
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		if vertical:
			box.size = Vector2(THICKNESS, TILE)
			shape.position = Vector2(TILE / 2.0, -(i + 0.5) * TILE)
		else:
			box.size = Vector2(TILE, THICKNESS)
			shape.position = Vector2((i + 0.5) * TILE, -THICKNESS / 2.0)
		shape.shape = box
		body.add_child(shape)


func _draw() -> void:
	var kit: Dictionary = TownArt.FENCES.get(style, TownArt.FENCES["picket"])
	var texture: Texture2D = TownArt.sheet("fence")
	for i in length:
		if i == gap_at:
			continue
		if vertical:
			draw_texture_rect_region(texture, Rect2(0, -(i + 1) * TILE, TILE, TILE), Rect2(kit["post"]))
		else:
			var piece: Rect2i = kit["mid"]
			if i == 0 or i - 1 == gap_at:
				piece = kit["left"]
			elif i == length - 1 or i + 1 == gap_at:
				piece = kit["right"]
			draw_texture_rect_region(texture, Rect2(i * TILE, -TILE, TILE, TILE), Rect2(piece))
