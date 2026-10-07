extends Node
## One-time authoring tool: lays out the human town and saves it as an editable scene.
##   <godot.exe> --headless --path . -- --build-town [--force]
## Writes resources/tilesets/town_tileset.tres, scenes/town/buildings/*.tscn and scenes/town/town.tscn.
## WARNING: town.tscn is meant to be edited by hand afterwards. Running this again with --force throws away
## every edit made in the editor (it refuses without --force when the town already exists).
##
## Map: 84 x 62 tiles. Stone wall around the inside (columns 5-78, rows 7-53), gates north (road to the dungeon)
## and south (main road), both on columns 40-42. Square in the middle with the important buildings around it,
## row houses on streets that run east-west (every LPC door faces south, so every house fronts a street),
## a stream with a bridge and vegetable gardens along the west wall.

const TOWN_PATH: String = "res://scenes/town/town.tscn"
const BUILDINGS_DIR: String = "res://scenes/town/buildings/"
const HOUSE_PATH: String = "res://scenes/town/buildings/house.tscn"
const PLAYER_SCENE: String = "res://scenes/player/player.tscn"
const HUD_SCENE: String = "res://scenes/ui/hud.tscn"
const WANTED_DIR: String = "res://resources/town/wanted/"
const WATER_SHADER: String = "res://resources/shaders/town_water.gdshader"

const T: int = 32
const MAP_SIZE: Vector2i = Vector2i(84, 62)
## Wall: west/east columns 3-4 and 79-80, north footprint row 6, south footprint row 56 (+2 hidden rows).
const WALL_LEFT: int = 3
const WALL_RIGHT: int = 79
const WALL_NORTH_ROW: int = 6
const WALL_SOUTH_ROW: int = 56
const GATE_COLUMN: int = 40
const GATE_WIDTH: int = 3
const STREAM_COLUMN: int = 8
const STREAM_WIDTH: int = 3

## House looks (TownBuilding settings). Rows below pick them by name, so the town reads as planned streets.
const HOUSE_TYPES: Dictionary = {
	"cottage": {"wall_style": "timber_tan", "roof_color": "thatch", "wall_height": 3, "window_style": "curtain",
		"flower_boxes": true},
	"cottage_cream": {"wall_style": "timber_cream", "roof_color": "thatch_dark", "wall_height": 3,
		"window_style": "curtain_gold", "flower_boxes": true},
	"townhouse": {"wall_style": "timber_cream", "roof_color": "red", "wall_height": 4, "window_style": "white"},
	"brick": {"wall_style": "red_brick", "roof_color": "slate", "wall_height": 3, "window_style": "white"},
	"stone": {"wall_style": "stone_light", "roof_color": "brown", "wall_height": 3, "window_style": "dark"},
	"tudor": {"wall_style": "tudor", "roof_color": "rust", "wall_height": 4, "window_style": "gold"},
	"cream": {"wall_style": "cream_brick", "roof_color": "teal", "wall_height": 3, "window_style": "grey",
		"roof_shape": TownBuilding.RoofShape.HIP},
	"timber_stone": {"wall_style": "timber_stone", "roof_color": "grey", "wall_height": 3, "window_style": "dark"},
	"shack": {"wall_style": "planks", "roof_color": "thatch_dark", "wall_height": 3, "window_style": "dark",
		"window_spacing": 3},
	"sand": {"wall_style": "sandstone", "roof_color": "blue", "wall_height": 4, "window_style": "white_tall"},
	"dark": {"wall_style": "dark_brick", "roof_color": "green", "wall_height": 3, "window_style": "gold",
		"roof_shape": TownBuilding.RoofShape.HIP},
}
const DOOR_STYLES: Array[String] = ["plank", "window", "panel", "plank_dark", "red", "white", "arched"]

## Rows of houses: [front row (the street's first row), tallest wall allowed, [[column, width, type], ...]].
## Houses touch each other in the middle of town; widths add up exactly to each block.
const HOUSE_ROWS: Array = [
	[13, 3, [[11, 6, "brick"], [19, 5, "cottage"], [24, 4, "shack"], [28, 6, "stone"], [34, 6, "cream"],
		[43, 6, "timber_stone"], [49, 5, "dark"], [54, 4, "cottage_cream"], [58, 5, "brick"],
		[65, 5, "stone"], [70, 4, "cottage"], [74, 5, "cream"]]],
	[22, 4, [[11, 6, "townhouse"], [65, 6, "tudor"]]],
	[30, 3, [[11, 6, "cottage"], [65, 6, "brick"]]],
	[38, 3, [[11, 6, "stone"], [65, 5, "cottage_cream"], [70, 4, "shack"], [74, 5, "timber_stone"]]],
	[47, 4, [[11, 6, "tudor"], [19, 5, "sand"], [24, 6, "townhouse"], [30, 4, "cottage"], [34, 6, "brick"],
		[43, 4, "shack"], [47, 6, "tudor"], [53, 5, "stone"], [58, 5, "cream"],
		[65, 6, "timber_stone"], [71, 4, "cottage_cream"], [75, 4, "dark"]]],
]

## Important buildings: scene name -> [column, front row, TownBuilding settings].
const LANDMARKS: Dictionary = {
	"alchemist": [19, 24, {"width": 8, "wall_height": 3, "roof_height": 4, "wall_style": "cream_brick",
		"roof_color": "green", "door_x": 3, "door_style": "arched", "window_style": "curtain", "flower_boxes": true,
		"chimney_x": 6, "shop_sign": "potion"}],
	"hunters_guild": [27, 24, {"width": 13, "wall_height": 5, "roof_height": 4, "wall_style": "tudor_stone",
		"roof_color": "red", "roof_shape": TownBuilding.RoofShape.HIP, "door_x": 5, "door_style": "castle_double",
		"window_style": "gold_tall", "banner": "red", "shop_sign": "sword", "chimney_x": 10}],
	"town_hall": [43, 24, {"width": 12, "wall_height": 5, "roof_height": 4, "wall_style": "sandstone",
		"roof_color": "slate", "roof_shape": TownBuilding.RoofShape.HIP, "door_x": 5, "door_style": "castle_big",
		"window_style": "white_tall", "banner": "blue"}],
	"general_store": [55, 24, {"width": 8, "wall_height": 4, "roof_height": 3, "wall_style": "timber_cream",
		"roof_color": "brown", "door_x": 3, "door_style": "window", "window_style": "white", "shop_sign": "bag",
		"chimney_x": 1}],
	"smithy": [19, 38, {"width": 7, "wall_height": 3, "roof_height": 3, "wall_style": "stone", "roof_color": "dark",
		"door_x": 5, "door_style": "plank_dark", "window_style": "dark", "window_spacing": 2, "shop_sign": "hammer",
		"chimney_x": 2}],
	"inn": [53, 38, {"width": 10, "wall_height": 5, "roof_height": 3, "wall_style": "tudor", "roof_color": "rust",
		"door_x": 4, "door_style": "double", "window_style": "curtain_gold", "flower_boxes": true, "shop_sign": "inn",
		"chimney_x": 8}],
	"temple": [71, 30, {"width": 8, "wall_height": 4, "roof_height": 4, "wall_style": "stone_light",
		"roof_color": "teal", "roof_shape": TownBuilding.RoofShape.HIP, "door_x": 3, "door_style": "double",
		"window_style": "round", "window_spacing": 2, "banner": "white"}],
}

var _root: Node2D
var _roads: Dictionary = {}
var _water: Dictionary = {}
var _soil: Dictionary = {}
var _paving: Dictionary = {}
var _bridges: Dictionary = {}


func run(options: Dictionary) -> void:
	if ResourceLoader.exists(TOWN_PATH) and not options.has("--force"):
		push_error("%s already exists (and may have hand edits). Use --force to rebuild it." % TOWN_PATH)
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BUILDINGS_DIR))
	var tile_set: TileSet = TownTiles.build_tile_set()
	_check(ResourceSaver.save(tile_set, TownTiles.TILE_SET_PATH), TownTiles.TILE_SET_PATH)
	tile_set = ResourceLoader.load(TownTiles.TILE_SET_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)
	_save_building_scenes()

	_root = Node2D.new()
	_root.name = "Town"
	_root.set_script(load("res://scripts/town/town_level.gd"))
	var lighting := TownLighting.new()
	lighting.name = "Lighting"
	_own(_root, lighting)
	var layers: Dictionary = {}
	for layer_name in ["Grass", "Water", "Roads", "Paving"]:
		var layer := TileMapLayer.new()
		layer.name = layer_name
		layer.tile_set = tile_set
		_own(_root, layer)
		layers[layer_name] = layer
	var ground_props := _group(_root, "GroundProps", false)
	var world := _group(_root, "World", true)

	_plan_ground()
	TownTiles.fill_grass(layers["Grass"], MAP_SIZE)
	TownTiles.paint(layers["Water"], TownTiles.Source.WATER, _water, false, _bridges)
	var shimmer := ShaderMaterial.new()
	shimmer.shader = load(WATER_SHADER)
	(layers["Water"] as TileMapLayer).material = shimmer
	TownTiles.paint(layers["Roads"], TownTiles.Source.DIRT, _roads, true)
	TownTiles.paint(layers["Roads"], TownTiles.Source.SOIL, _soil, false)
	TownTiles.paint_cobbles(layers["Paving"], _paving)

	_build_walls(_group(world, "Walls", true), _group(_root, "SideWalls", false))
	var buildings := _group(world, "Buildings", true)
	_place_landmarks(buildings)
	_place_houses(buildings)
	var props := _group(world, "Props", true)
	_place_structure_props(props, ground_props)
	_place_details(props, buildings)
	_place_trees(_group(world, "Trees", true))
	_root.move_child(_root.get_node("SideWalls"), _root.get_node("World").get_index())

	var player: Node2D = (load(PLAYER_SCENE) as PackedScene).instantiate()
	player.name = "Player"
	player.position = Vector2(41.5, 51.5) * T
	_own(world, player)
	_place_npc_spots()
	_add_dungeon_exit()
	var hud: Node = (load(HUD_SCENE) as PackedScene).instantiate()
	hud.name = "HUD"
	_own(_root, hud)

	var packed := PackedScene.new()
	_check(packed.pack(_root), "pack town")
	_check(ResourceSaver.save(packed, TOWN_PATH), TOWN_PATH)
	print("Town saved: ", TOWN_PATH)
	get_tree().quit(0)


func _check(error: Error, what: String) -> void:
	if error != OK:
		push_error("Failed: %s (%s)" % [what, error])
		get_tree().quit(1)


## Adds `node` under `parent`, saved with the town scene.
func _own(parent: Node, node: Node) -> void:
	parent.add_child(node)
	node.owner = _root


func _group(parent: Node, group_name: String, y_sorted: bool) -> Node2D:
	var node := Node2D.new()
	node.name = group_name
	node.y_sort_enabled = y_sorted
	_own(parent, node)
	return node


# --- Ground ---

func _rect(cells: Dictionary, x0: int, y0: int, x1: int, y1: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			cells[Vector2i(x, y)] = true


func _plan_ground() -> void:
	# Stream: from the north edge to the south edge, under both walls.
	_rect(_water, STREAM_COLUMN, 0, STREAM_COLUMN + STREAM_WIDTH - 1, MAP_SIZE.y - 1)
	# Main road (south gate) and dungeon road (north gate), straight through the square.
	_rect(_roads, GATE_COLUMN, 0, GATE_COLUMN + GATE_WIDTH - 1, MAP_SIZE.y - 1)
	# East-west streets.
	_rect(_roads, 11, 13, 78, 14)
	_rect(_roads, 11, 22, 18, 23)
	_rect(_roads, 11, 30, 18, 31)
	_rect(_roads, 63, 22, 70, 23)
	_rect(_roads, 63, 30, 78, 31)
	_rect(_roads, 5, 38, 78, 39)
	_rect(_roads, 11, 47, 78, 48)
	# North-south lanes.
	_rect(_roads, 17, 13, 18, 48)
	_rect(_roads, 63, 13, 64, 48)
	# Yards: smithy side and forge, inn back yard, behind the alchemist and the store.
	_rect(_roads, 19, 27, 29, 31)
	_rect(_roads, 26, 32, 29, 37)
	_rect(_roads, 53, 27, 62, 29)
	_rect(_roads, 19, 15, 26, 16)
	_rect(_roads, 55, 15, 62, 16)
	# Square: a paved strip in front of the big buildings and the market place around the fountain.
	_rect(_paving, 19, 24, 62, 26)
	_rect(_paving, 30, 24, 52, 37)
	# A dirt border around the paving.
	_rect(_roads, 18, 23, 63, 27)
	_rect(_roads, 29, 23, 53, 38)
	# Bridge where the main street crosses the stream (water without collision).
	_rect(_bridges, STREAM_COLUMN, 38, STREAM_COLUMN + STREAM_WIDTH - 1, 39)
	# Vegetable gardens (tilled soil): west strip and back gardens along the south wall.
	for patch in [[5, 9, 7, 20], [5, 24, 7, 35], [5, 42, 7, 52], [20, 50, 25, 53], [30, 50, 36, 53],
			[45, 50, 51, 53], [56, 50, 61, 53], [67, 50, 73, 53]]:
		_rect(_soil, patch[0], patch[1], patch[2], patch[3])
	for cell: Vector2i in _soil:
		_roads.erase(cell)


# --- Walls ---

func _build_walls(walls: Node2D, side_walls: Node2D) -> void:
	var length: int = WALL_RIGHT - WALL_LEFT + 2
	var north := TownWall.new()
	north.name = "WallNorth"
	north.position = Vector2(WALL_LEFT, WALL_NORTH_ROW + 1) * T
	north.length = length
	north.gate_from = GATE_COLUMN - WALL_LEFT
	north.gate_width = GATE_WIDTH
	north.grate_from = STREAM_COLUMN - WALL_LEFT
	north.grate_width = STREAM_WIDTH
	_own(walls, north)
	var south := TownWall.new()
	south.name = "WallSouth"
	south.position = Vector2(WALL_LEFT, WALL_SOUTH_ROW + 1) * T
	south.length = length
	south.depth = 3
	south.gate_from = GATE_COLUMN - WALL_LEFT
	south.gate_width = GATE_WIDTH
	south.grate_from = STREAM_COLUMN - WALL_LEFT
	south.grate_width = STREAM_WIDTH
	_own(walls, south)
	for side in [["WallWest", WALL_LEFT], ["WallEast", WALL_RIGHT]]:
		var wall := TownWall.new()
		wall.name = side[0]
		wall.vertical = true
		wall.position = Vector2(side[1], WALL_SOUTH_ROW - 2) * T
		wall.length = WALL_SOUTH_ROW - 2 - (WALL_NORTH_ROW + 1)
		_own(side_walls, wall)
	# Round towers on the corners and on both sides of each gate.
	var towers: Array = [
		["TowerNorthWest", WALL_LEFT + 1, WALL_NORTH_ROW + 1], ["TowerNorthEast", WALL_RIGHT + 1, WALL_NORTH_ROW + 1],
		["TowerSouthWest", WALL_LEFT + 1, WALL_SOUTH_ROW + 1], ["TowerSouthEast", WALL_RIGHT + 1, WALL_SOUTH_ROW + 1],
		["TowerNorthGateWest", GATE_COLUMN - 1, WALL_NORTH_ROW + 1],
		["TowerNorthGateEast", GATE_COLUMN + GATE_WIDTH + 1, WALL_NORTH_ROW + 1],
		["TowerSouthGateWest", GATE_COLUMN - 1, WALL_SOUTH_ROW + 1],
		["TowerSouthGateEast", GATE_COLUMN + GATE_WIDTH + 1, WALL_SOUTH_ROW + 1],
	]
	for tower in towers:
		_prop(walls, tower[0], "tower", Vector2(tower[1], tower[2]))


# --- Buildings ---

func _save_building_scenes() -> void:
	var house := TownBuilding.new()
	house.name = "House"
	_save_scene(house, HOUSE_PATH)
	for scene_name: String in LANDMARKS:
		var building := TownBuilding.new()
		building.name = scene_name.to_pascal_case()
		var settings: Dictionary = LANDMARKS[scene_name][2]
		for key: String in settings:
			building.set(key, settings[key])
		_save_scene(building, BUILDINGS_DIR + scene_name + ".tscn")


func _save_scene(node: Node, path: String) -> void:
	var packed := PackedScene.new()
	_check(packed.pack(node), "pack " + path)
	_check(ResourceSaver.save(packed, path), path)
	node.free()


func _place_landmarks(parent: Node2D) -> void:
	for scene_name: String in LANDMARKS:
		var entry: Array = LANDMARKS[scene_name]
		var building: Node2D = (load(BUILDINGS_DIR + scene_name + ".tscn") as PackedScene).instantiate()
		building.name = scene_name.to_pascal_case()
		building.position = Vector2(entry[0], entry[1]) * T
		_own(parent, building)


func _place_houses(parent: Node2D) -> void:
	var house_scene: PackedScene = load(HOUSE_PATH)
	var count: int = 0
	for row: Array in HOUSE_ROWS:
		for spec: Array in row[2]:
			var house: TownBuilding = house_scene.instantiate()
			count += 1
			house.name = "House%02d" % count
			house.position = Vector2(spec[0], row[0]) * T
			var settings: Dictionary = HOUSE_TYPES[spec[2]]
			for key: String in settings:
				house.set(key, settings[key])
			house.width = spec[1]
			house.wall_height = mini(house.wall_height, row[1])
			house.roof_height = 3
			house.door_x = 1 if (count % 3 == 0) else (spec[1] - 1) / 2
			house.door_style = DOOR_STYLES[(count * 5) % DOOR_STYLES.size()]
			if count % 2 == 0:
				house.chimney_x = spec[1] - 2
			_own(parent, house)


# --- Props (structure: square, market, board, bridge, forge, garden fences) ---

## A TownProp at `cell` (tile units, may be fractional): the bottom center of the picture.
func _prop(parent: Node2D, prop_name: String, kind: String, cell: Vector2, flip: bool = false) -> TownProp:
	var prop := TownProp.new()
	prop.name = prop_name
	prop.prop = kind
	prop.flip_h = flip
	prop.position = cell * T
	_own(parent, prop)
	return prop


func _fence(parent: Node2D, fence_name: String, style: String, cell: Vector2i, length: int, vertical: bool,
		gap: int = -1) -> void:
	var fence := TownFence.new()
	fence.name = fence_name
	fence.style = style
	fence.length = length
	fence.vertical = vertical
	fence.gap_at = gap
	fence.position = Vector2(cell) * T
	_own(parent, fence)


func _place_structure_props(props: Node2D, ground_props: Node2D) -> void:
	_prop(props, "Fountain", "fountain", Vector2(41.5, 32))
	_prop(props, "StallVegetables", "stall_green", Vector2(31.5, 36.6))
	_prop(props, "StallCloth", "stall_grey", Vector2(35.2, 36.6))
	_prop(props, "StallBread", "stall_orange", Vector2(45, 36.6))
	_prop(props, "StallPottery", "stall_green", Vector2(48.6, 36.6), true)
	var board := WantedBoard.new()
	board.name = "WantedBoard"
	board.position = Vector2(45.5, 28.2) * T
	for file in DirAccess.get_files_at(WANTED_DIR):
		if file.ends_with(".tres"):
			board.posters.append(load(WANTED_DIR + file) as WantedPoster)
	_own(props, board)
	# Inn terrace on the square.
	_prop(props, "InnTable1", "table", Vector2(51.5, 31))
	_prop(props, "InnTable2", "table", Vector2(51.5, 34.5))
	# Forge yard next to the smithy.
	_prop(props, "Forge", "forge", Vector2(27.5, 34.2))
	_prop(props, "Anvil", "smith_anvil", Vector2(28.6, 36.4))
	_prop(props, "Quench", "quench", Vector2(26.9, 37.6))
	_prop(props, "ToolRack", "smith_rack", Vector2(29.1, 33.2))
	# Bridge over the stream (under characters, never y-sorted over them).
	_prop(ground_props, "Bridge", "bridge", Vector2(STREAM_COLUMN + STREAM_WIDTH / 2.0, 40.1))
	# Fences around the vegetable gardens.
	var gardens: Array = [[5, 9, 3, 12], [5, 24, 3, 12], [5, 42, 3, 11], [20, 50, 6, 4], [30, 50, 7, 4],
		[45, 50, 7, 4], [56, 50, 6, 4], [67, 50, 7, 4]]
	var index: int = 0
	for garden in gardens:
		index += 1
		var x: int = garden[0]
		var y: int = garden[1]
		var w: int = garden[2]
		var h: int = garden[3]
		_fence(props, "GardenFence%dTop" % index, "picket", Vector2i(x, y), w, false)
		_fence(props, "GardenFence%dBottom" % index, "picket", Vector2i(x, y + h), w, false, w / 2)
		if w <= 3:
			continue
		_fence(props, "GardenFence%dLeft" % index, "picket", Vector2i(x, y + h), h - 1, true)
		_fence(props, "GardenFence%dRight" % index, "picket", Vector2i(x + w - 1, y + h), h - 1, true)
	# Graveyard behind the temple.
	_fence(props, "GraveyardFenceTop", "stone", Vector2i(71, 16), 8, false)
	_fence(props, "GraveyardFenceLeft", "stone", Vector2i(71, 21), 5, true)
	for i in 6:
		_prop(props, "Grave%d" % (i + 1), "grave", Vector2(72.5 + (i % 3) * 2.0, 18.5 + (i / 3) * 2.0))


## Small life: lamps, barrels, crates, sacks, carts, laundry, benches, flower pots, woodpiles, sheds.
func _place_details(props: Node2D, buildings: Node2D) -> void:
	var lamps: Array = [
		# Dungeon road and north gate.
		Vector2(39.6, 10.4), Vector2(43.4, 10.4), Vector2(39.6, 19), Vector2(43.4, 19),
		# Square corners and along the paved strip.
		Vector2(29.6, 27.6), Vector2(53.4, 27.6), Vector2(29.6, 37.8), Vector2(53.4, 37.8), Vector2(24, 27.4),
		Vector2(59, 27.4),
		# Streets.
		Vector2(16.4, 15.4), Vector2(65.4, 15.4), Vector2(16.4, 32.4), Vector2(65.4, 32.4), Vector2(12, 40.6),
		Vector2(26, 40.6), Vector2(36, 40.6), Vector2(39.6, 45), Vector2(43.4, 45), Vector2(56, 40.6),
		Vector2(70, 40.6), Vector2(20, 49.4), Vector2(56, 49.4), Vector2(66, 49.4), Vector2(39.6, 53.6),
		Vector2(43.4, 53.6), Vector2(5.8, 40.4),
	]
	for i in lamps.size():
		var lamp := _prop(props, "Lamp%02d" % (i + 1), "lantern", lamps[i])
		lamp.on_pole = true
	var things: Array = [
		# Store: goods by the door and in the back yard.
		["crates", 60.5, 25.6], ["barrel", 62.3, 25.4], ["sacks", 56.4, 25.6], ["crate", 57.5, 16.7],
		["crate_small", 59.5, 16.7], ["barrels", 61, 16.9],
		# Inn: barrels and a cart in the back yard, stools by the tables.
		["barrels", 54.5, 29.7], ["barrel_big", 56.6, 29.6], ["crates", 60, 29.7], ["hand_cart", 58.6, 29.5],
		["stool", 50.4, 31.3], ["stool", 52.6, 31.3], ["stool", 50.4, 34.8], ["stool", 52.6, 34.8],
		# Smithy side yard.
		["woodpile", 20.6, 30.4], ["coal", 23.4, 31.4], ["barrel_open", 19.6, 28.4], ["wheelbarrow", 26, 29.6],
		["crate", 28.6, 28.4],
		# Alchemist: herbs and pots behind, pots by the door.
		["pot_blue", 21.3, 25], ["pot_red", 24.6, 25], ["herbs", 20, 16.4], ["barrel_open", 25.6, 16.6],
		["tub", 23, 16.9],
		# Square: benches around the fountain, a cart by the stalls, sacks and crates at the market.
		["bench", 37.6, 30.6], ["bench", 45.4, 30.6], ["bench", 34, 27.6], ["bench_long", 38, 34.4],
		["hand_cart", 38.4, 37.8], ["sacks", 33.6, 37.6], ["crates", 47.6, 37.7], ["barrel", 43.6, 37.6],
		["sack", 30.9, 37.7], ["pot_yellow", 40, 26.4], ["pot_red", 43, 26.4],
		# Guild and Town Hall doors.
		["pot_red", 31.4, 24.8], ["pot_red", 35.6, 24.8], ["pot_blue", 47.4, 24.8], ["pot_blue", 50.6, 24.8],
		# Temple: statue and flowers.
		["statue", 77.6, 31.5], ["flowers_mix", 72.4, 31.2], ["flowers_blue", 76, 31.2],
		# Gardens by the stream: scarecrows, a well, a hay cart.
		["scarecrow", 6, 15.4], ["scarecrow", 6, 30.4], ["scarecrow", 6, 47.4], ["well_stone", 6.2, 22.9],
		["hay_cart", 6.3, 37.2], ["bucket", 7.3, 23.2], ["reeds", 11.3, 8.6], ["reeds", 11.3, 54.4],
		# Back gardens along the south wall.
		["laundry_line", 16, 51.6], ["woodpile", 18.6, 50.8], ["sack", 29.4, 52.6], ["hay_bale", 35.6, 49.6],
		["woodpile_small", 55.2, 51.2], ["laundry_line", 64.3, 51.4], ["barrel", 62.6, 52.8], ["woodpile", 66.2, 52.6],
		["sacks", 78.2, 52.6],
		# Behind the north row, between the houses.
		["woodpile_small", 17.4, 11.6], ["bush", 18, 9.6], ["barrel", 39.4, 12.6], ["crate_small", 42.8, 12.7],
		["woodpile_small", 63.6, 12.6], ["bush_round", 64.2, 9.6],
		# Outside the south gate: a merchant wagon waiting, a trough for the horses.
		["wagon", 46.6, 59.6], ["trough", 36.6, 59.6], ["sign_post", 43.8, 58.4],
		# Outside the north gate: the road sign to the dungeon.
		["sign_post", 43.8, 3.4],
	]
	for i in things.size():
		var thing: Array = things[i]
		_prop(props, "%s%02d" % [String(thing[0]).to_pascal_case(), i + 1], thing[0], Vector2(thing[1], thing[2]))
	# Flower pots and sacks by the house doors (every few houses), chosen by order so it stays the same.
	var index: int = 0
	for building in buildings.get_children():
		var house := building as TownBuilding
		if house == null or not String(house.name).begins_with("House"):
			continue
		index += 1
		var door: float = house.position.x / T + house.door_x
		var front: float = house.position.y / T
		if index % 2 == 0:
			_prop(props, "DoorPot%02d" % index, ["pot_red", "pot_blue", "pot_yellow"][index % 3],
				Vector2(door + 1.35, front + 0.25))
		elif index % 3 == 0:
			_prop(props, "DoorSack%02d" % index, "sack", Vector2(door - 0.4, front + 0.3))
	# Small storage sheds in the back gardens (no door, no windows).
	var shed_scene: PackedScene = load(HOUSE_PATH)
	for shed_spec in [[26, 3], [37, 3], [52, 3], [74, 4], [11, 3]]:
		var shed: TownBuilding = shed_scene.instantiate()
		shed.name = "Shed%02d" % shed_spec[0]
		shed.position = Vector2(shed_spec[0], 54) * T
		shed.width = shed_spec[1]
		shed.wall_height = 2
		shed.roof_height = 2
		shed.wall_style = "planks"
		shed.roof_color = "thatch_dark" if shed_spec[0] % 2 == 0 else "brown"
		shed.door_x = -1
		shed.window_spacing = 0
		_own(buildings, shed)


func _place_trees(trees: Node2D) -> void:
	var index: int = 0
	# Outside the wall: a ring of trees, leaving the roads and the stream free.
	for y in range(0, MAP_SIZE.y, 3):
		for x in range(0, MAP_SIZE.x, 3):
			var inside: bool = x >= WALL_LEFT - 1 and x <= WALL_RIGHT + 2 and y >= WALL_NORTH_ROW - 3 and y <= WALL_SOUTH_ROW + 1
			if inside:
				continue
			if absi(x - (GATE_COLUMN + 1)) <= 3 or absi(x - (STREAM_COLUMN + 1)) <= 2:
				continue
			index += 1
			var jitter := Vector2(((x * 7 + y * 3) % 5) * 0.2, ((x * 3 + y * 5) % 5) * 0.15)
			_prop(trees, "Tree%03d" % index, "tree_pine" if (x + y) % 2 == 0 else "tree", Vector2(x + 1, y + 1) + jitter)
	# A few trees inside: temple yard and gardens.
	for spot in [Vector2(77, 21), Vector2(73.5, 21.5), Vector2(6.2, 8.6), Vector2(6.2, 41), Vector2(55.8, 53.8)]:
		index += 1
		_prop(trees, "Tree%03d" % index, "tree", spot)


# --- Runtime markers ---

func _place_npc_spots() -> void:
	var spots := _group(_root, "NpcSpots", false)
	for spot in [Vector2(36, 30), Vector2(47, 30), Vector2(41.5, 27), Vector2(33, 26), Vector2(50, 26), Vector2(44, 34)]:
		var marker := Marker2D.new()
		marker.name = "NpcSpot%d" % (spots.get_child_count() + 1)
		marker.position = spot * T
		marker.add_to_group(&"npc_spot", true)
		_own(spots, marker)


func _add_dungeon_exit() -> void:
	var exit := Area2D.new()
	exit.name = "DungeonExit"
	exit.collision_layer = 0
	exit.collision_mask = 2
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(GATE_WIDTH * T, T)
	shape.shape = box
	shape.position = Vector2(GATE_COLUMN + GATE_WIDTH / 2.0, 0.5) * T
	exit.add_child(shape)
	_own(_root, exit)
	shape.owner = _root
