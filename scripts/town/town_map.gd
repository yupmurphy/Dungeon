class_name TownMap
extends MapSource
## Map of the town for the minimap and the big map (M). The town is known from the start (no fog): the
## picture is drawn once from the scene itself (ground layers, walls, buildings, trees), so hand edits in the
## editor show up on the map automatically. Landmarks get their own color and a line in the legend.

const GRASS: Color = Color(0.3, 0.52, 0.24)
const ROAD: Color = Color(0.66, 0.52, 0.33)
const SOIL: Color = Color(0.4, 0.28, 0.17)
const PAVING: Color = Color(0.62, 0.62, 0.64)
const WATER: Color = Color(0.22, 0.42, 0.8)
const WALL: Color = Color(0.4, 0.4, 0.46)
const TREE: Color = Color(0.13, 0.32, 0.14)
const FOUNTAIN: Color = Color(0.45, 0.7, 1.0)
const GATE: Color = Color(1.0, 0.95, 0.55)
const EXIT: Color = Color(0.8, 0.4, 1.0)
## Houses darken their roof color a bit so the landmarks stand out.
const HOUSE_DARKEN: float = 0.15
## Landmark node name -> [text key in texts.csv, map color].
const LANDMARKS: Dictionary = {
	"HuntersGuild": [&"TOWN_HUNTERS_GUILD", Color(0.95, 0.3, 0.25)],
	"TownHall": [&"TOWN_HALL", Color(0.4, 0.6, 1.0)],
	"Inn": [&"TOWN_INN", Color(1.0, 0.65, 0.2)],
	"Smithy": [&"TOWN_SMITHY", Color(0.7, 0.42, 0.32)],
	"Alchemist": [&"TOWN_ALCHEMIST", Color(0.45, 0.95, 0.5)],
	"GeneralStore": [&"TOWN_GENERAL_STORE", Color(0.9, 0.8, 0.45)],
	"Temple": [&"TOWN_TEMPLE", Color(0.95, 0.95, 1.0)],
}
const TILE: int = 32

var _image: Image
var _roof_colors: Dictionary = {}


## Draws the map from `town` (the town scene root).
func build(town: Node) -> void:
	var grass := town.get_node("Grass") as TileMapLayer
	var used: Rect2i = grass.get_used_rect()
	var size: Vector2i = used.end
	_image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	_image.fill(GRASS)
	_paint_layer(town.get_node_or_null("Water") as TileMapLayer, func(_source: int) -> Color: return WATER)
	_paint_layer(town.get_node_or_null("Roads") as TileMapLayer, func(source: int) -> Color:
		return SOIL if source == TownTiles.Source.SOIL else ROAD)
	_paint_layer(town.get_node_or_null("Paving") as TileMapLayer, func(_source: int) -> Color: return PAVING)
	legend.clear()
	for node in town.find_children("*", "", true, false):
		if node is TownWall:
			_paint_wall(node)
		elif node is TownBuilding:
			_paint_building(node)
		elif node is TownProp:
			_paint_prop(node)
	var exit := town.get_node_or_null("DungeonExit") as Area2D
	if exit != null:
		var cell: Vector2i = _cell(exit.global_position + (exit.get_child(0) as Node2D).position)
		_rect(Rect2i(cell - Vector2i(1, 0), Vector2i(3, 1)), EXIT)
		legend.append({"name": TranslationServer.translate(&"TOWN_TO_DUNGEON"), "color": EXIT})
	legend.append({"name": TranslationServer.translate(&"TOWN_GATES"), "color": GATE})
	map_texture = ImageTexture.create_from_image(_image)


func _paint_layer(layer: TileMapLayer, color_of: Callable) -> void:
	if layer == null:
		return
	for cell in layer.get_used_cells():
		var source: int = layer.get_cell_source_id(cell)
		var coords: Vector2i = layer.get_cell_atlas_coords(cell)
		# Only full tiles: the LPC edge tiles are mostly the ground under them.
		if source in [TownTiles.Source.FLAGSTONE, TownTiles.Source.COBBLE] or coords in TownTiles.FULL_VARIANTS:
			_paint(cell, color_of.call(source))


func _paint_building(building: TownBuilding) -> void:
	var corner: Vector2i = _cell(building.global_position)
	var height: int = building.wall_height + building.roof_height
	var color: Color = _roof_color(building.roof_color).darkened(HOUSE_DARKEN)
	var key: String = String(building.name)
	if LANDMARKS.has(key):
		color = LANDMARKS[key][1]
		legend.append({"name": TranslationServer.translate(LANDMARKS[key][0]), "color": color})
	_rect(Rect2i(corner.x, corner.y - height, building.width, height), color)


func _paint_wall(wall: TownWall) -> void:
	var corner: Vector2i = _cell(wall.global_position)
	if wall.vertical:
		_rect(Rect2i(corner.x, corner.y - wall.length - 2, 2, wall.length + 2), WALL)
		return
	_rect(Rect2i(corner.x, corner.y - 3, wall.length, 3), WALL)
	if wall.gate_from >= 0:
		_rect(Rect2i(corner.x + wall.gate_from, corner.y - 3, wall.gate_width, 3), GATE)


func _paint_prop(prop: TownProp) -> void:
	var cell: Vector2i = _cell(prop.global_position - Vector2(0, 1))
	match prop.prop:
		"tree", "tree_pine":
			_paint(cell, TREE)
			_paint(cell + Vector2i(0, -1), TREE)
		"tower":
			_rect(Rect2i(cell.x - 1, cell.y - 3, 2, 3), WALL.darkened(0.2))
		"fountain":
			_rect(Rect2i(cell.x - 1, cell.y - 1, 2, 1), FOUNTAIN)


## Average color of a roof's shingle tile, so the map matches what you see.
func _roof_color(roof: String) -> Color:
	if _roof_colors.has(roof):
		return _roof_colors[roof]
	var image: Image = TownArt.roof_tiles(roof)[0].get_image()
	var sum := Color(0, 0, 0, 0)
	var count: int = 0
	for y in image.get_height():
		for x in image.get_width():
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a > 0.5:
				sum += pixel
				count += 1
	_roof_colors[roof] = Color(sum.r / count, sum.g / count, sum.b / count) if count > 0 else ROAD
	return _roof_colors[roof]


func _cell(world_position: Vector2) -> Vector2i:
	return Vector2i((world_position / TILE).floor())


func _rect(rect: Rect2i, color: Color) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			_paint(Vector2i(x, y), color)


func _paint(cell: Vector2i, color: Color) -> void:
	if cell.x >= 0 and cell.y >= 0 and cell.x < _image.get_width() and cell.y < _image.get_height():
		_image.set_pixelv(cell, color)
