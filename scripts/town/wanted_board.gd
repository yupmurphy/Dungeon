@tool
class_name WantedBoard
extends Node2D
## Western-style Wanted board: a plank board on two posts under a small roof, with a poster per entry
## of `posters` (WantedPoster .tres files). The node stands at the bottom center, between the posts.

const TILE: int = 32
const BOARD_SIZE: Vector2 = Vector2(118, 50)
const POST_HEIGHT: float = 78.0
const POSTER_SIZE: Vector2 = Vector2(24, 28)
const POSTER_GAP: float = 2.0
const PAPER: Color = Color(0.91, 0.84, 0.66)
const PAPER_EDGE: Color = Color(0.55, 0.42, 0.26)
const INK: Color = Color(0.23, 0.15, 0.1)
const WOOD_DARK: Color = Color(0.27, 0.17, 0.1)
## Portrait color per WantedPoster.Kind: murderer, undead, monster, player.
const KIND_COLORS: Array[Color] = [Color(0.45, 0.2, 0.15), Color(0.45, 0.55, 0.45), Color(0.4, 0.22, 0.45),
	Color(0.75, 0.15, 0.1)]
const TITLE_FONT_SIZE: int = 5
const WOOD: Rect2i = Rect2i(1280, 1984, 96, 32)

@export var posters: Array[WantedPoster] = []:
	set(value):
		posters = value
		queue_redraw()


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	if Engine.is_editor_hint():
		return
	var body := StaticBody2D.new()
	body.name = "Collision"
	for x in [-BOARD_SIZE.x / 2.0 + 4.0, BOARD_SIZE.x / 2.0 - 4.0]:
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(10, 8)
		shape.shape = box
		shape.position = Vector2(x, -4)
		body.add_child(shape)
	add_child(body)


## Puts a poster up (e.g. the player's own, when they become wanted).
func add_poster(poster: WantedPoster) -> void:
	posters.append(poster)
	queue_redraw()


func _draw() -> void:
	var half: float = BOARD_SIZE.x / 2.0
	var board := Rect2(-half, -POST_HEIGHT + 8.0, BOARD_SIZE.x, BOARD_SIZE.y)
	# Posts and shadow.
	draw_rect(Rect2(-half - 2, -4, BOARD_SIZE.x + 4, 6), Color(0, 0, 0, 0.25))
	for x in [-half + 1.0, half - 7.0]:
		draw_rect(Rect2(x, -POST_HEIGHT, 6, POST_HEIGHT), WOOD_DARK)
		draw_rect(Rect2(x + 1, -POST_HEIGHT, 2, POST_HEIGHT), WOOD_DARK.lightened(0.25))
	# Plank board with a frame.
	draw_texture_rect(TownArt.piece("walls", WOOD), board, true)
	draw_rect(board, WOOD_DARK, false, 2.0)
	# Small shingle roof on top.
	var roof := Rect2(-half - 6, board.position.y - 12, BOARD_SIZE.x + 12, 12)
	draw_texture_rect(TownArt.roof_tiles("brown")[0], roof, true)
	draw_rect(roof, WOOD_DARK, false, 1.0)
	draw_rect(Rect2(roof.position.x, roof.end.y - 2, roof.size.x, 2), WOOD_DARK)
	var font: Font = ThemeDB.fallback_font
	var title: String = TranslationServer.translate(&"WANTED_TITLE")
	var count: int = mini(posters.size(), int((BOARD_SIZE.x - 6.0) / (POSTER_SIZE.x + POSTER_GAP)))
	var total: float = count * POSTER_SIZE.x + (count - 1) * POSTER_GAP
	for i in count:
		var poster: WantedPoster = posters[i]
		if poster == null:
			continue
		var tilt: float = -1.5 if i % 2 == 0 else 1.5
		var rect := Rect2(-total / 2.0 + i * (POSTER_SIZE.x + POSTER_GAP), board.position.y + 8.0 + tilt, POSTER_SIZE.x,
			POSTER_SIZE.y)
		draw_rect(rect, PAPER)
		draw_rect(rect, PAPER_EDGE, false, 1.0)
		draw_string(font, Vector2(rect.position.x + 1, rect.position.y + 6), title, HORIZONTAL_ALIGNMENT_CENTER,
			POSTER_SIZE.x - 2, TITLE_FONT_SIZE, INK)
		# Portrait: head and shoulders.
		var face: Color = KIND_COLORS[poster.kind]
		var center := Vector2(rect.get_center().x, rect.position.y + 13)
		draw_circle(center, 3.5, face)
		draw_rect(Rect2(center.x - 6, center.y + 3, 12, 4), face)
		# Reward line and a red pin.
		var reward: String = TranslationServer.translate(&"WANTED_REWARD").format({"reward": poster.reward})
		draw_string(font, Vector2(rect.position.x + 1, rect.end.y - 2), reward, HORIZONTAL_ALIGNMENT_CENTER,
			POSTER_SIZE.x - 2, TITLE_FONT_SIZE, INK)
		draw_circle(Vector2(rect.get_center().x, rect.position.y + 1), 1.2, Color(0.8, 0.1, 0.1))
