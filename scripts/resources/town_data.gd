class_name TownData
extends Resource
## Hand-shaped human settlement. Positions are tiles; IDs survive layout changes and future interior work.
const MAP_SIZE: Vector2i = Vector2i(96, 96)
const START_CELL: Vector2i = Vector2i(50, 48)
const SQUARE: Rect2i = Rect2i(38, 37, 23, 17)
const TERRACE: Rect2i = Rect2i(34, 22, 34, 36)
const TERRACE_SHAPE: Array[Rect2i] = [Rect2i(38, 22, 22, 4), Rect2i(34, 26, 34, 24), Rect2i(36, 50, 30, 8)]
const LEDGE_WIDTH: int = 1
const STAIR_BORDER_TILES: int = 1
const TWO_STOREY_IDS: Array[StringName] = [&"town_hall", &"tavern", &"house_03", &"house_13"]
const STAIRS: Rect2i = Rect2i(47, 55, 6, 5)
const STAIR_LANDINGS: Array[Rect2i] = [Rect2i(47, 54, 6, 1), Rect2i(47, 60, 6, 1)]
const RAMP: Rect2i = Rect2i(65, 47, 5, 5)
const TERRACE_HEIGHT: float = 1.0
const ROAD_HALF_WIDTH: int = 1
const HOUSE_SIZES: Array[Vector2i] = [Vector2i(6, 5), Vector2i(7, 5), Vector2i(6, 6), Vector2i(5, 5)]
const HOUSE_CELLS: Array[Vector2i] = [Vector2i(15, 12), Vector2i(30, 7), Vector2i(47, 6), Vector2i(65, 8),
	Vector2i(80, 17), Vector2i(8, 29), Vector2i(11, 43), Vector2i(8, 59), Vector2i(16, 73), Vector2i(27, 82),
	Vector2i(44, 86), Vector2i(61, 82), Vector2i(79, 77), Vector2i(85, 62), Vector2i(83, 44), Vector2i(79, 29),
	Vector2i(21, 36), Vector2i(34, 13), Vector2i(69, 21), Vector2i(36, 70)]
const ROAD_PATHS: Array[Array] = [
	[Vector2i(51, 92), Vector2i(49, 83), Vector2i(55, 72), Vector2i(50, 66), Vector2i(50, 59), Vector2i(50, 54)],
	[Vector2i(49, 83), Vector2i(40, 74), Vector2i(23, 60), Vector2i(24, 43), Vector2i(20, 35), Vector2i(25, 21), Vector2i(30, 13), Vector2i(50, 14)],
	[Vector2i(49, 83), Vector2i(75, 81), Vector2i(83, 64), Vector2i(81, 53), Vector2i(75, 42), Vector2i(79, 27), Vector2i(66, 15), Vector2i(50, 14)],
	[Vector2i(81, 53), Vector2i(73, 50), Vector2i(66, 49), Vector2i(59, 48)],
	[Vector2i(50, 54), Vector2i(50, 36), Vector2i(49, 33)],
]
const GATE_CELL: Vector2i = Vector2i(51, 92)
const RESERVED_PLOTS: Array[Rect2i] = [Rect2i(22, 26, 9, 7), Rect2i(71, 45, 9, 7),
	Rect2i(26, 62, 9, 7), Rect2i(59, 63, 9, 7)]
const SERVICE_BUILDINGS: Array[Dictionary] = [
	{"id": &"town_hall", "kind": &"hall", "name": &"TOWN_HALL", "rect": Rect2i(44, 26, 10, 7), "style": 2},
	{"id": &"blacksmith", "kind": &"smith", "name": &"TOWN_BLACKSMITH", "rect": Rect2i(20, 49, 8, 6), "style": 1},
	{"id": &"bookshop", "kind": &"books", "name": &"TOWN_BOOKSHOP", "rect": Rect2i(70, 32, 7, 6), "style": 3},
	{"id": &"tavern", "kind": &"tavern", "name": &"TOWN_TAVERN", "rect": Rect2i(66, 73, 9, 7), "style": 0},
]
const STALL_CELLS: Array[Vector2i] = [Vector2i(39, 38), Vector2i(56, 38), Vector2i(39, 44),
	Vector2i(56, 44), Vector2i(39, 50), Vector2i(56, 50)]
const STALL_SIZE: Vector2i = Vector2i(4, 2)
const PROP_SPECS: Array[Dictionary] = [
	{"id": &"square_fountain", "kind": &"fountain", "rect": Rect2i(48, 44, 3, 3)},
	{"id": &"square_board", "kind": &"board", "rect": Rect2i(44, 35, 2, 1)},
	{"id": &"bench_west", "kind": &"bench", "rect": Rect2i(44, 39, 2, 1)},
	{"id": &"bench_east", "kind": &"bench", "rect": Rect2i(53, 39, 2, 1)},
	{"id": &"bench_south", "kind": &"bench", "rect": Rect2i(53, 52, 2, 1)},
	{"id": &"smith_anvil", "kind": &"anvil", "rect": Rect2i(29, 50, 2, 1)},
	{"id": &"smith_wood", "kind": &"wood", "rect": Rect2i(29, 53, 2, 1)},
	{"id": &"smith_coal", "kind": &"coal", "rect": Rect2i(29, 55, 2, 1)},
	{"id": &"books_planter", "kind": &"planter", "rect": Rect2i(77, 37, 1, 1)},
	{"id": &"tavern_barrel_west", "kind": &"barrel", "rect": Rect2i(66, 80, 1, 1)},
	{"id": &"tavern_barrel_east", "kind": &"barrel", "rect": Rect2i(74, 80, 1, 1)},
]
const TREE_CELLS: Array[Vector2i] = [Vector2i(7, 17), Vector2i(10, 21), Vector2i(23, 10), Vector2i(39, 5),
	Vector2i(57, 8), Vector2i(77, 12), Vector2i(87, 25), Vector2i(90, 36), Vector2i(6, 40), Vector2i(5, 54),
	Vector2i(15, 54), Vector2i(19, 64), Vector2i(11, 72), Vector2i(10, 84), Vector2i(25, 90), Vector2i(36, 87),
	Vector2i(57, 88), Vector2i(73, 91), Vector2i(91, 79), Vector2i(91, 54), Vector2i(84, 56), Vector2i(72, 60),
	Vector2i(40, 61), Vector2i(56, 61), Vector2i(38, 25), Vector2i(62, 25)]
const STYLE_COUNT: int = 4
const BORDER_MARGIN: int = 2

var buildings: Array[TownBuildingData] = []
var props: Array[TownPropData] = []

func _init() -> void:
	for item in SERVICE_BUILDINGS:
		_add(item.id, item.kind, item.name, item.rect, item.style)
	for index in HOUSE_CELLS.size():
		var number: int = index + 1
		_add(StringName("house_%02d" % number), &"house", &"TOWN_HOUSE",
			Rect2i(HOUSE_CELLS[index], HOUSE_SIZES[number % STYLE_COUNT]), number % STYLE_COUNT)
	for item in PROP_SPECS:
		var prop := TownPropData.new()
		prop.id = item.id
		prop.kind = item.kind
		prop.footprint = item.rect
		props.append(prop)

func _add(id_value: StringName, kind_value: StringName, text_key: StringName, rect: Rect2i, variant: int) -> void:
	var building := TownBuildingData.new()
	building.id = id_value
	building.kind = kind_value
	building.name_key = text_key
	building.footprint = rect
	building.style = variant
	building.floors = 2 if id_value in TWO_STOREY_IDS else 1
	buildings.append(building)
