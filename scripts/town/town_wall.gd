@tool
class_name TownWall
extends Node2D
## A straight piece of the stone town wall, drawn from LPC textures: walkway on top with merlons, stone face
## below. Horizontal: the node is the bottom-left corner of the face, the wall is `length` tiles long and one
## tile thick on the ground (2 tiles of face, 1 of walkway seen above). Vertical: the node is the bottom-left
## corner, the wall goes `length` tiles up and is 2 tiles thick. A gate leaves an opening in a horizontal wall
## (the walkway bridges over it); a grate lets a stream pass under it.

const TILE: int = 32
const FACE_TILES: int = 2
const MERLON_STEP: float = 16.0
const MERLON_SIZE: Vector2 = Vector2(10, 9)
const PARAPET: float = 5.0
const OUTLINE: Color = Color(0.12, 0.11, 0.13, 1.0)
const STONE_LIGHT: Color = Color(0.78, 0.76, 0.72)
const OPENING_DARK: Color = Color(0.08, 0.07, 0.09, 0.9)
const PORTCULLIS: Color = Color(0.2, 0.2, 0.22)
const WALKWAY: Rect2i = Rect2i(32, 96, 32, 32)
const FACE_STYLE: String = "grey_stone"

@export_range(1, 120) var length: int = 10:
	set(value):
		length = value
		queue_redraw()
@export var vertical: bool = false:
	set(value):
		vertical = value
		queue_redraw()
## Gate opening (horizontal walls only): first tile and width in tiles (-1 = no gate).
@export var gate_from: int = -1:
	set(value):
		gate_from = value
		queue_redraw()
@export_range(1, 6) var gate_width: int = 3:
	set(value):
		gate_width = value
		queue_redraw()
## Rows of ground (in tiles) that block movement behind a horizontal wall: 1 = its thickness; more for a
## wall seen from behind (the south wall hides the ground behind its face, so nobody walks there).
@export_range(1, 4) var depth: int = 1
## Water grate (horizontal walls only): first tile and width in tiles (-1 = none). Still blocks movement.
@export var grate_from: int = -1:
	set(value):
		grate_from = value
		queue_redraw()
@export_range(1, 6) var grate_width: int = 2:
	set(value):
		grate_width = value
		queue_redraw()


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	if Engine.is_editor_hint():
		return
	var body := StaticBody2D.new()
	body.name = "Collision"
	add_child(body)
	if vertical:
		_add_box(body, Rect2(0, -length * TILE, 2 * TILE, length * TILE))
	elif gate_from < 0:
		_add_box(body, Rect2(0, -depth * TILE, length * TILE, depth * TILE))
	else:
		_add_box(body, Rect2(0, -depth * TILE, gate_from * TILE, depth * TILE))
		var after: float = (gate_from + gate_width) * TILE
		_add_box(body, Rect2(after, -depth * TILE, length * TILE - after, depth * TILE))


func _add_box(body: StaticBody2D, rect: Rect2) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	body.add_child(shape)


func _draw() -> void:
	if vertical:
		_draw_vertical()
	else:
		_draw_horizontal()


func _draw_horizontal() -> void:
	var w: float = length * TILE
	var face_top: float = -FACE_TILES * TILE
	var walk_top: float = face_top - TILE
	_merlons(Rect2(0, walk_top - MERLON_SIZE.y + 2, w, MERLON_SIZE.y), true)
	draw_texture_rect(TownArt.piece("floors", WALKWAY), Rect2(0, walk_top, w, TILE), true)
	draw_rect(Rect2(0, walk_top, w, PARAPET), STONE_LIGHT.darkened(0.25))
	# Face, with the openings left out.
	var rows: Array[Texture2D] = TownArt.wall_rows(FACE_STYLE)
	var spans: Array[Vector2] = [Vector2(0, w)]
	if gate_from >= 0:
		spans = [Vector2(0, gate_from * TILE), Vector2((gate_from + gate_width) * TILE, w)]
	for span in spans:
		if span.y <= span.x:
			continue
		draw_texture_rect(rows[0], Rect2(span.x, face_top, span.y - span.x, TILE), true)
		draw_texture_rect(rows[2], Rect2(span.x, face_top + TILE, span.y - span.x, TILE), true)
	if gate_from >= 0:
		_draw_gate()
	if grate_from >= 0:
		_draw_grate()
	_merlons(Rect2(0, face_top - PARAPET - MERLON_SIZE.y + 1, w, MERLON_SIZE.y), false)
	draw_texture_rect(rows[0], Rect2(0, face_top - PARAPET, w, PARAPET), true)
	draw_line(Vector2(0, face_top - PARAPET), Vector2(w, face_top - PARAPET), OUTLINE, 1.0)
	draw_line(Vector2(0, face_top), Vector2(w, face_top), Color(0, 0, 0, 0.35), 2.0)
	draw_rect(Rect2(0, walk_top - MERLON_SIZE.y + 2, w, -walk_top + MERLON_SIZE.y - 2), OUTLINE, false, 1.0)


func _draw_gate() -> void:
	var rows: Array[Texture2D] = TownArt.wall_rows(FACE_STYLE)
	var x0: float = gate_from * TILE
	var x1: float = (gate_from + gate_width) * TILE
	var face_top: float = -FACE_TILES * TILE
	var lintel: float = 14.0
	# Stone lintel over the passage and lighter jambs on both sides.
	draw_texture_rect(rows[0], Rect2(x0, face_top, x1 - x0, lintel), true)
	draw_rect(Rect2(x0, face_top + lintel - 3, x1 - x0, 3), OUTLINE)
	for x in [x0, x1 - 6.0]:
		draw_rect(Rect2(x, face_top, 6, FACE_TILES * TILE), STONE_LIGHT)
		draw_rect(Rect2(x, face_top, 6, FACE_TILES * TILE), OUTLINE, false, 1.0)
	# Raised portcullis: its spiked bottom edge shows under the lintel.
	var bar_x: float = x0 + 10.0
	while bar_x < x1 - 8.0:
		draw_rect(Rect2(bar_x, face_top + lintel, 2, 7), PORTCULLIS)
		bar_x += 8.0
	draw_rect(Rect2(x0 + 6, face_top + lintel + 2, x1 - x0 - 12, 2), PORTCULLIS)


func _draw_grate() -> void:
	var x0: float = grate_from * TILE
	var x1: float = (grate_from + grate_width) * TILE
	var top: float = -TILE * 0.9
	draw_rect(Rect2(x0 + 4, top, x1 - x0 - 8, -top), OPENING_DARK)
	draw_arc(Vector2((x0 + x1) / 2.0, top + 2), (x1 - x0) / 2.0 - 4.0, PI, TAU, 16, STONE_LIGHT, 3.0)
	var bar_x: float = x0 + 8.0
	while bar_x < x1 - 6.0:
		draw_rect(Rect2(bar_x, top, 2, -top), PORTCULLIS)
		bar_x += 7.0


func _draw_vertical() -> void:
	var h: float = length * TILE
	var lift: float = FACE_TILES * TILE
	var w: float = 2.0 * TILE
	draw_texture_rect(TownArt.piece("floors", WALKWAY), Rect2(0, -h - lift, w, h), true)
	for x in [0.0, w - PARAPET]:
		draw_rect(Rect2(x, -h - lift, PARAPET, h), STONE_LIGHT.darkened(0.2))
	var y: float = -h - lift + 4.0
	while y < -lift - MERLON_SIZE.x:
		for x in [0.0, w - MERLON_SIZE.y]:
			var merlon := Rect2(x, y, MERLON_SIZE.y, MERLON_SIZE.x)
			draw_rect(merlon, STONE_LIGHT.darkened(0.1))
			draw_rect(merlon, OUTLINE, false, 1.0)
		y += MERLON_STEP
	# The bottom end shows its face.
	var rows: Array[Texture2D] = TownArt.wall_rows(FACE_STYLE)
	draw_texture_rect(rows[0], Rect2(0, -lift, w, TILE), true)
	draw_texture_rect(rows[2], Rect2(0, -TILE, w, TILE), true)
	draw_rect(Rect2(0, -h - lift, w, h + lift), OUTLINE, false, 1.0)


## A row of merlons; `back` ones are darker (seen behind the walkway).
func _merlons(area: Rect2, back: bool) -> void:
	var color: Color = STONE_LIGHT.darkened(0.3) if back else STONE_LIGHT
	var x: float = area.position.x + 3.0
	while x + MERLON_SIZE.x <= area.end.x:
		var merlon := Rect2(x, area.position.y, MERLON_SIZE.x, area.size.y)
		draw_rect(merlon, color)
		draw_rect(Rect2(x, area.position.y, MERLON_SIZE.x, 2), color.lightened(0.2))
		draw_rect(merlon, OUTLINE, false, 1.0)
		x += MERLON_STEP
