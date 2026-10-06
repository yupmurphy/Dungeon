class_name MapOverlay
extends Control
## Full map (key M): everything explored so far, player position, region legend.

const BACKGROUND: Color = Color(0.02, 0.02, 0.04, 0.92)
const FONT_SIZE: int = 10
const MAP_TOP: float = 24.0

var exploration: ExplorationMap
var player: Node2D
var title: String = ""

var _blink: float = 0.0


func _process(delta: float) -> void:
	if visible:
		_blink += delta
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	if exploration == null or exploration.layout == null:
		return
	var font: Font = ThemeDB.fallback_font
	var map_size: Vector2 = Vector2(exploration.layout.size)
	var scale_factor: float = floorf(minf((size.x - 180.0) / map_size.x, (size.y - MAP_TOP - 12.0) / map_size.y))
	scale_factor = maxf(scale_factor, 1.0)
	var map_rect := Rect2(Vector2(16.0, MAP_TOP), map_size * scale_factor)
	draw_rect(map_rect.grow(1.0), Color(1, 1, 1, 0.25), false, 1.0)
	draw_texture_rect(exploration.map_texture, map_rect, false)

	if player != null and fmod(_blink, 0.8) < 0.55:
		var dot: Vector2 = map_rect.position + player.global_position / GameScale.TILE_SIZE * scale_factor
		draw_circle(dot, 3.0, Color.WHITE)

	draw_string(font, Vector2(16.0, 16.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE + 2)
	var x: float = map_rect.end.x + 16.0
	var y: float = MAP_TOP + 10.0
	for entry in exploration.legend:
		draw_rect(Rect2(x, y - 7.0, 8.0, 8.0), entry["color"])
		draw_string(font, Vector2(x + 13.0, y), entry["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
		y += 15.0
	draw_rect(Rect2(x, y - 7.0, 8.0, 8.0), ExplorationMap.PORTAL_MAP_COLOR)
	draw_string(font, Vector2(x + 13.0, y), "Portal", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	y += 24.0
	var explored: String = "Explored: %d%%" % roundi(exploration.explored_ratio() * 100.0)
	draw_string(font, Vector2(x, y), explored, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	draw_string(font, Vector2(x, y + 15.0), "M - close", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
