@tool
class_name TownBuilding
extends Node2D
## A town building put together from LPC pieces (TownArt): wall face, roof, door, windows, chimney, sign,
## banners. Every part is an inspector setting, and the editor redraws it live (it is a @tool script).
## The node sits at the bottom-left corner of the front wall; the door always faces south (down), as in
## every LPC town. Ground footprint = width x roof_height tiles (it blocks movement); the upper part of the
## roof hangs over the ground behind, so characters walk behind it (World is y-sorted).

enum RoofShape { GABLE, HIP }

const TILE: int = 32
## How far the roof sticks out past the walls, left/right and over the wall's top.
const OVERHANG: float = 6.0
const EAVE_DROP: float = 6.0
## Part of the roof height that is the back slope (the rest is the front slope).
const BACK_SLOPE: float = 0.38
const ROOF_OUTLINE: Color = Color(0.13, 0.08, 0.07, 1.0)
const EAVE_SHADOW: Color = Color(0, 0, 0, 0.28)
const BEAM_COLOR: Color = Color(0.32, 0.2, 0.12)
const DOOR_SHADOW: Color = Color(0, 0, 0, 0.35)
const STRAW_STROKE: Color = Color(0.35, 0.22, 0.05, 0.28)
const STRAW_FRINGE: Color = Color(0.45, 0.3, 0.1, 0.9)
const STRAW_ROW: float = 4.0
const WINDOW_GLOW: Color = Color(1.0, 0.8, 0.4, 0.55)
## Light of a lit window at night (stage 3: TownLevel turns `lit` on after dark).
const WINDOW_LIGHT_COLOR: Color = Color(1.0, 0.75, 0.4)
const WINDOW_LIGHT_ENERGY: float = 0.7
const WINDOW_LIGHT_SCALE: float = 0.35

@export_range(2, 20) var width: int = 6:
	set(value):
		width = value
		_changed()
## Wall face height in tiles: 3 = one floor, 4-5 = two floors (windows on both).
@export_range(2, 7) var wall_height: int = 3:
	set(value):
		wall_height = value
		_changed()
## Roof height in tiles = how deep the building is (its ground footprint).
@export_range(2, 7) var roof_height: int = 3:
	set(value):
		roof_height = value
		_changed()
@export_enum("stone", "stone_light", "sandstone", "red_brick", "dark_brick", "cream_brick", "grey_stone", "cobble",
	"planks", "tudor", "tudor_stone", "timber_tan", "timber_cream", "timber_stone") var wall_style: String = "timber_tan":
	set(value):
		wall_style = value
		_changed()
@export_enum("slate", "grey", "blue", "green", "red", "brown", "white", "dark", "rust", "teal", "thatch",
	"thatch_dark") var roof_color: String = "red":
	set(value):
		roof_color = value
		_changed()
@export var roof_shape: RoofShape = RoofShape.GABLE:
	set(value):
		roof_shape = value
		_changed()
## Door tile, counted from the left (-1 = no door). Wide doors (64 px) take this tile and the next.
@export var door_x: int = 2:
	set(value):
		door_x = value
		_changed()
@export_enum("plank", "window", "panel", "plank_dark", "red", "white", "arched", "arched_dark", "double",
	"castle_double", "castle_big") var door_style: String = "plank":
	set(value):
		door_style = value
		_changed()
@export_enum("dark", "white", "gold", "grey", "dark_tall", "white_tall", "gold_tall", "grey_tall", "curtain",
	"curtain_gold", "round") var window_style: String = "dark":
	set(value):
		window_style = value
		_changed()
## Ground floor windows every this many tiles (0 = none).
@export_range(0, 6) var window_spacing: int = 2:
	set(value):
		window_spacing = value
		_changed()
@export var flower_boxes: bool = false:
	set(value):
		flower_boxes = value
		_changed()
## Chimney tile (-1 = none). Chimneys smoke (TownLevel adds the particles).
@export var chimney_x: int = -1:
	set(value):
		chimney_x = value
		_changed()
## Hanging sign next to the door ("none" = none): blank, sword, potion, bread, bag, book, beer, inn, amulet, hammer.
@export_enum("none", "blank", "sword", "potion", "bread", "bag", "book", "beer", "inn", "amulet", "hammer")
var shop_sign: String = "none":
	set(value):
		shop_sign = value
		_changed()
## Banners on the facade ("none" = none): white, blue, green, red, yellow, black.
@export_enum("none", "white", "blue", "green", "red", "yellow", "black") var banner: String = "none":
	set(value):
		banner = value
		_changed()
## Night: windows glow and give light.
@export var lit: bool = false:
	set(value):
		lit = value
		_changed()
		_update_lights()

var _lights: Array[PointLight2D] = []


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	if Engine.is_editor_hint():
		return
	add_to_group(&"town_lights")
	var body := StaticBody2D.new()
	body.name = "Collision"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width * TILE, roof_height * TILE)
	shape.shape = rect
	shape.position = Vector2(width * TILE / 2.0, -roof_height * TILE / 2.0)
	body.add_child(shape)
	add_child(body)
	_update_lights()


## Where a character stands to use the door (in front of it), in global coordinates.
func door_position() -> Vector2:
	return to_global(Vector2((door_x + 0.5) * TILE, TILE * 0.5))


## Top of the chimney, in local coordinates (smoke starts here).
func chimney_top() -> Vector2:
	return Vector2(chimney_x * TILE + 16, _roof_top() - 10)


func window_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if window_spacing <= 0:
		return rects
	var entry: Array = TownArt.WINDOWS.get(window_style, TownArt.WINDOWS["dark"])
	var size: Vector2 = Vector2((entry[1] as Rect2i).size)
	var door_tiles: int = _door_tiles()
	var floors: int = 1 if wall_height <= 3 else 2
	for floor_index in floors:
		var bottom: float = -22.0 - floor_index * 2 * TILE
		for i in width:
			var is_door: bool = door_x >= 0 and i >= door_x and i < door_x + door_tiles
			if floor_index == 0 and is_door:
				continue
			if absi(i - maxi(door_x, 0)) % window_spacing != 0:
				continue
			if width > 3 and (i == 0 or i == width - 1):
				continue
			rects.append(Rect2(Vector2(i * TILE + (TILE - size.x) / 2.0, bottom - size.y), size))
	return rects


func _changed() -> void:
	queue_redraw()


func _door_tiles() -> int:
	var entry: Array = TownArt.DOORS.get(door_style, TownArt.DOORS["plank"])
	return ceili((entry[1] as Rect2i).size.x / float(TILE))


func _wall_top() -> float:
	return -wall_height * TILE


func _roof_top() -> float:
	return _wall_top() - roof_height * TILE


func _draw() -> void:
	var w: float = width * TILE
	_draw_walls(w)
	_draw_door()
	_draw_windows()
	_draw_roof(w)
	if chimney_x >= 0 and chimney_x < width:
		_draw_chimney()
	if banner != "none":
		_draw_banners(w)
	if shop_sign != "none" and door_x >= 0:
		var sign_x: float = (door_x + _door_tiles()) * TILE
		if sign_x + TILE > w:
			sign_x = (door_x - 1) * TILE
		draw_texture_rect_region(TownArt.sheet("deco"), Rect2(sign_x, -2.4 * TILE, 32, 30),
			Rect2(TownArt.SIGNS.get(shop_sign, TownArt.SIGNS["blank"])))


func _draw_walls(w: float) -> void:
	var rows: Array[Texture2D] = TownArt.wall_rows(wall_style)
	for r in wall_height:
		var texture: Texture2D = rows[1]
		if r == 0:
			texture = rows[0]
		elif r == wall_height - 1:
			texture = rows[2]
		draw_texture_rect(texture, Rect2(0, _wall_top() + r * TILE, w, TILE), true)
	if wall_height >= 4:
		# Floor beam between the two floors.
		var y: float = -2.0 * TILE - 3.0
		draw_rect(Rect2(0, y, w, 5), BEAM_COLOR)
		draw_rect(Rect2(0, y, w, 1), BEAM_COLOR.lightened(0.3))
	# Corner posts give the facade clean edges.
	draw_rect(Rect2(0, _wall_top(), 2, wall_height * TILE), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(w - 2, _wall_top(), 2, wall_height * TILE), Color(0, 0, 0, 0.35))


func _draw_door() -> void:
	if door_x < 0:
		return
	var entry: Array = TownArt.DOORS.get(door_style, TownArt.DOORS["plank"])
	var region: Rect2i = entry[1]
	var x: float = door_x * TILE + (_door_tiles() * TILE - region.size.x) / 2.0
	draw_rect(Rect2(x - 2, -region.size.y - 2, region.size.x + 4, region.size.y + 2), DOOR_SHADOW)
	draw_texture_rect_region(TownArt.sheet(entry[0]), Rect2(x, -region.size.y, region.size.x, region.size.y),
		Rect2(region))


func _draw_windows() -> void:
	var entry: Array = TownArt.WINDOWS.get(window_style, TownArt.WINDOWS["dark"])
	var texture: Texture2D = TownArt.sheet(entry[0])
	for rect in window_rects():
		draw_texture_rect_region(texture, rect, Rect2(entry[1]))
		if lit:
			draw_rect(rect.grow(-4), WINDOW_GLOW)
		if flower_boxes and rect.end.y > -TILE * 1.5:
			var box: Rect2i = TownArt.FLOWER_BOX[1]
			draw_texture_rect_region(TownArt.sheet(TownArt.FLOWER_BOX[0]),
				Rect2(rect.position.x + (rect.size.x - box.size.x) / 2.0, rect.end.y - 8, box.size.x, box.size.y), Rect2(box))


func _draw_roof(w: float) -> void:
	var tiles: Array[Texture2D] = TownArt.roof_tiles(roof_color)
	var top: float = _roof_top()
	var bottom: float = _wall_top() + EAVE_DROP
	var ridge: float = top + (bottom - top) * BACK_SLOPE
	var left: float = -OVERHANG
	var right: float = w + OVERHANG
	var inset: float = 0.0
	if roof_shape == RoofShape.HIP:
		inset = minf((ridge - top) * 1.6, (right - left) / 2.0 - 8.0)
	# Shadow of the eaves on the wall.
	draw_rect(Rect2(0, bottom, w, 6), EAVE_SHADOW)
	var back := PackedVector2Array([Vector2(left, top), Vector2(right, top), Vector2(right - inset, ridge),
		Vector2(left + inset, ridge)])
	var front := PackedVector2Array([Vector2(left + inset, ridge), Vector2(right - inset, ridge), Vector2(right, bottom),
		Vector2(left, bottom)])
	_textured(back, tiles[1], Color(0.92, 0.92, 0.92))
	_textured(front, tiles[0], Color.WHITE)
	if inset > 0.0:
		_textured(PackedVector2Array([Vector2(left, top), Vector2(left + inset, ridge), Vector2(left, bottom)]),
			tiles[0], Color(0.8, 0.8, 0.8))
		_textured(PackedVector2Array([Vector2(right, top), Vector2(right, bottom), Vector2(right - inset, ridge)]),
			tiles[1], Color(1.05, 1.05, 1.05))
		draw_line(Vector2(left, top), Vector2(left + inset, ridge), ROOF_OUTLINE, 1.0)
		draw_line(Vector2(right, top), Vector2(right - inset, ridge), ROOF_OUTLINE, 1.0)
		draw_line(Vector2(left, bottom), Vector2(left + inset, ridge), ROOF_OUTLINE, 1.0)
		draw_line(Vector2(right, bottom), Vector2(right - inset, ridge), ROOF_OUTLINE, 1.0)
	else:
		# Gable ends: dark barge boards on both sides.
		draw_rect(Rect2(left, top, 3, bottom - top), ROOF_OUTLINE.lightened(0.15))
		draw_rect(Rect2(right - 3, top, 3, bottom - top), ROOF_OUTLINE.lightened(0.15))
	if roof_color.begins_with("thatch"):
		_draw_straw(left, right, top, ridge, bottom)
	# Ridge cap.
	draw_rect(Rect2(left + inset, ridge - 2, right - left - inset * 2.0, 4), ROOF_OUTLINE.lightened(0.2))
	draw_line(Vector2(left + inset, ridge - 2), Vector2(right - inset, ridge - 2), Color(1, 1, 1, 0.25), 1.0)
	# Eave edge and outline.
	draw_rect(Rect2(left, bottom - 3, right - left, 3), ROOF_OUTLINE.lightened(0.1))
	draw_polyline(PackedVector2Array([Vector2(left, bottom), Vector2(left, top), Vector2(right, top), Vector2(right, bottom),
		Vector2(left, bottom)]), ROOF_OUTLINE, 1.0)


## The LPC thatch is a smooth fill: layered straw strokes and a ragged eave make it read as straw.
func _draw_straw(left: float, right: float, top: float, ridge: float, bottom: float) -> void:
	var y: float = top + 4.0
	var row: int = 0
	while y < bottom - 4.0:
		if absf(y - ridge) > 3.0:
			var x: float = left + 2.0 + (row % 3) * 3.0
			while x < right - 4.0:
				var length: float = 3.0 + float((int(x) * 7 + row * 5) % 4)
				draw_line(Vector2(x, y), Vector2(x + length, y), STRAW_STROKE, 1.0)
				x += length + 3.0 + float((int(x) + row) % 3)
		y += STRAW_ROW
		row += 1
	var fringe: float = left
	var step: int = 0
	while fringe < right:
		draw_rect(Rect2(fringe, bottom - 1.0, 2.0, 1.0 + float(step % 3)), STRAW_FRINGE)
		fringe += 2.0
		step += 1


func _textured(points: PackedVector2Array, texture: Texture2D, tint: Color) -> void:
	var uvs := PackedVector2Array()
	var size: Vector2 = texture.get_size()
	for p in points:
		uvs.append(p / size)
	draw_colored_polygon(points, tint, uvs, texture)


func _draw_chimney() -> void:
	var rows: Array[Texture2D] = TownArt.wall_rows("red_brick")
	var top: float = _roof_top() - 10.0
	var x: float = chimney_x * TILE + 8.0
	var height: float = (_roof_top() + (_wall_top() + EAVE_DROP - _roof_top()) * BACK_SLOPE) - top
	draw_texture_rect(rows[1], Rect2(x, top, 16, height), true)
	draw_rect(Rect2(x, top, 16, height), ROOF_OUTLINE, false, 1.0)
	draw_rect(Rect2(x - 2, top - 3, 20, 4), Color(0.25, 0.22, 0.22))
	draw_rect(Rect2(x + 3, top - 2, 10, 2), Color(0.05, 0.05, 0.05))


func _draw_banners(w: float) -> void:
	var prop: Dictionary = TownArt.PROPS["banner_" + banner]
	var region: Rect2i = prop["rect"]
	var y: float = _wall_top() + EAVE_DROP + 4.0
	for x in [TILE * 0.5, w - TILE * 0.5 - region.size.x]:
		draw_texture_rect_region(TownArt.sheet(prop["sheet"]), Rect2(Vector2(x, y), Vector2(region.size)), Rect2(region))


func _update_lights() -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	if lit and _lights.is_empty():
		for rect in window_rects():
			var light := PointLight2D.new()
			light.texture = TownLighting.light_texture()
			light.color = WINDOW_LIGHT_COLOR
			light.energy = WINDOW_LIGHT_ENERGY
			light.texture_scale = WINDOW_LIGHT_SCALE
			light.position = rect.get_center() + Vector2(0, TILE * 0.6)
			add_child(light)
			_lights.append(light)
	for light in _lights:
		light.visible = lit
