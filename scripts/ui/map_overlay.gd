class_name MapOverlay
extends Control
## Full map (key M): the floor's outline (faint), everything explored so far, the start and the portal (always
## marked), player position, region legend.

const BACKGROUND: Color = Color(0.02, 0.02, 0.04, 0.92)
const FONT_SIZE: int = 10
const MAP_TOP: float = 24.0
## Room kept on the right for the legend.
const LEGEND_WIDTH: float = 150.0
## Start and portal dots on the map.
const MARKER_RADIUS: float = 3.5

var exploration: MapSource
var player: Node2D
var title: String = ""

var _blink: float = 0.0


func _process(delta: float) -> void:
	if visible:
		_blink += delta
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	if exploration == null or exploration.map_texture == null:
		return
	var font: Font = ThemeDB.fallback_font
	var map_size: Vector2 = Vector2(exploration.map_size())
	# Fit the map next to the legend. Big floors are shrunk (linear filtering keeps thin corridors visible).
	var scale_factor: float = minf((size.x - LEGEND_WIDTH) / map_size.x, (size.y - MAP_TOP - 8.0) / map_size.y)
	if scale_factor >= 1.0:
		scale_factor = floorf(scale_factor)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if scale_factor >= 1.0 else CanvasItem.TEXTURE_FILTER_LINEAR
	var map_rect := Rect2(Vector2(16.0, MAP_TOP), map_size * scale_factor)
	draw_rect(map_rect.grow(1.0), Color(1, 1, 1, 0.25), false, 1.0)
	if exploration.outline_texture != null:
		draw_texture_rect(exploration.outline_texture, map_rect, false)
	draw_texture_rect(exploration.map_texture, map_rect, false)
	for marker in exploration.markers():
		var at: Vector2 = map_rect.position + (Vector2(marker["cell"]) + Vector2(0.5, 0.5)) * scale_factor
		draw_circle(at, MARKER_RADIUS, marker["color"])
		draw_arc(at, MARKER_RADIUS + 2.0, 0.0, TAU, 16, Color(0, 0, 0, 0.8), 1.0)
		draw_string(font, at + Vector2(MARKER_RADIUS + 3.0, 4.0), marker["label"], HORIZONTAL_ALIGNMENT_LEFT, -1,
			FONT_SIZE, marker["color"])

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
	y += 9.0
	for line in exploration.status_lines():
		draw_string(font, Vector2(x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
		y += 15.0
	draw_string(font, Vector2(x, y), "M - close", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
