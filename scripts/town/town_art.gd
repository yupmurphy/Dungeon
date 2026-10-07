@tool
class_name TownArt
extends RefCounted
## Every piece of town art (assets/town/, LPC packs from OpenGameArt): where it sits on its sheet.
## Buildings, walls and props draw from here, so swapping a piece = editing one rectangle below.
## Rectangles are in sheet pixels (LPC art is 32 px per tile, the same as GameScale.TILE_SIZE).

const SHEETS: Dictionary = {
	"walls": "res://assets/town/walls/walls.png",
	"cottage": "res://assets/town/thatched-roof-cottage/cottage.png",
	"thatch": "res://assets/town/thatched-roof-cottage/thatched-roof.png",
	"roofs": "res://assets/town/roofs/roofs.png",
	"doors": "res://assets/town/windows-doors/windows-doors.png",
	"deco": "res://assets/town/medieval-village-decorations/decorations-medieval.png",
	"fence": "res://assets/town/medieval-village-decorations/fence_medieval.png",
	"castle": "res://assets/town/castle-mega-pack/castle8_0.png",
	"containers": "res://assets/town/containers/container.png",
	"plants": "res://assets/town/flowers-plants-fungi-wood/plants.png",
	"smith": "res://assets/town/blacksmith/blacksmith-smelter.png",
	"alchemy": "res://assets/town/alchemy/alchemy.png",
	"floors": "res://assets/town/base-assets/castlefloors_outside.png",
	"treetop": "res://assets/town/base-assets/treetop.png",
	"trunk": "res://assets/town/base-assets/trunk.png",
	"bridges": "res://assets/town/base-assets/bridges.png",
}

## Wall faces: a 96 x 96 block = top row, middle row (repeated for taller walls), bottom row.
const WALLS: Dictionary = {
	"stone": ["walls", Rect2i(0, 640, 96, 96)],
	"stone_light": ["walls", Rect2i(128, 640, 96, 96)],
	"sandstone": ["walls", Rect2i(256, 640, 96, 96)],
	"red_brick": ["walls", Rect2i(0, 736, 96, 96)],
	"dark_brick": ["walls", Rect2i(128, 736, 96, 96)],
	"cream_brick": ["walls", Rect2i(256, 736, 96, 96)],
	"grey_stone": ["walls", Rect2i(0, 928, 96, 96)],
	"cobble": ["walls", Rect2i(256, 928, 96, 96)],
	"planks": ["walls", Rect2i(1280, 1984, 96, 96)],
	"tudor": ["walls", Rect2i(1792, 1792, 96, 96)],
	"tudor_stone": ["walls", Rect2i(1792, 1888, 96, 96)],
	"timber_tan": ["cottage", Rect2i(96, 0, 96, 96)],
	"timber_cream": ["cottage", Rect2i(96, 128, 96, 96)],
	"timber_stone": ["cottage", Rect2i(96, 256, 96, 96)],
}

## Roof shingles: [light slope, dark slope] fill tiles. LPC Roofs has one 160 px wide kit per color.
const ROOFS: Dictionary = {
	"slate": ["roofs", 0],
	"grey": ["roofs", 1],
	"blue": ["roofs", 2],
	"green": ["roofs", 3],
	"red": ["roofs", 4],
	"brown": ["roofs", 5],
	"white": ["roofs", 6],
	"dark": ["roofs", 7],
	"rust": ["roofs", 8],
	"teal": ["roofs", 9],
	"thatch": ["thatch", 0],
	"thatch_dark": ["thatch", 1],
}
const ROOF_KIT_WIDTH: int = 160

const DOORS: Dictionary = {
	"plank": ["doors", Rect2i(16, 512, 32, 48)],
	"window": ["doors", Rect2i(80, 512, 32, 48)],
	"panel": ["doors", Rect2i(144, 512, 32, 48)],
	"plank_dark": ["doors", Rect2i(208, 512, 32, 48)],
	"red": ["doors", Rect2i(528, 512, 32, 52)],
	"white": ["doors", Rect2i(592, 512, 32, 48)],
	"arched": ["doors", Rect2i(816, 904, 32, 56)],
	"arched_dark": ["doors", Rect2i(864, 904, 32, 56)],
	"double": ["doors", Rect2i(896, 800, 64, 64)],
	"castle_double": ["castle", Rect2i(352, 448, 64, 64)],
	"castle_big": ["castle", Rect2i(352, 512, 64, 64)],
}

const WINDOWS: Dictionary = {
	"dark": ["doors", Rect2i(160, 64, 32, 32)],
	"white": ["doors", Rect2i(160, 160, 32, 32)],
	"gold": ["doors", Rect2i(160, 256, 32, 32)],
	"grey": ["doors", Rect2i(160, 352, 32, 32)],
	"dark_tall": ["doors", Rect2i(96, 26, 32, 44)],
	"white_tall": ["doors", Rect2i(96, 122, 32, 44)],
	"gold_tall": ["doors", Rect2i(96, 218, 32, 44)],
	"grey_tall": ["doors", Rect2i(96, 314, 32, 44)],
	"curtain": ["doors", Rect2i(225, 289, 30, 44)],
	"curtain_gold": ["doors", Rect2i(257, 307, 30, 44)],
	"round": ["doors", Rect2i(194, 113, 28, 27)],
}

const FLOWER_BOX: Array = ["doors", Rect2i(448, 128, 32, 22)]

## Props: sheet, rectangle, solid footprint (w, h px, at the bottom; Vector2i.ZERO = walk through),
## animation frames (count, step between frames on the sheet), optional light offset from the bottom center.
const PROPS: Dictionary = {
	"fountain": {"sheet": "deco", "rect": Rect2i(0, 512, 64, 64), "solid": Vector2i(56, 30), "frames": 3, "step": Vector2i(64, 0)},
	"well": {"sheet": "deco", "rect": Rect2i(448, 415, 64, 97), "solid": Vector2i(48, 22)},
	"well_stone": {"sheet": "deco", "rect": Rect2i(0, 432, 64, 48), "solid": Vector2i(56, 26)},
	"hand_cart": {"sheet": "deco", "rect": Rect2i(196, 514, 82, 62), "solid": Vector2i(60, 20)},
	"hay_cart": {"sheet": "deco", "rect": Rect2i(136, 739, 80, 55), "solid": Vector2i(60, 20)},
	"wheelbarrow": {"sheet": "deco", "rect": Rect2i(224, 708, 64, 55), "solid": Vector2i(44, 16)},
	"wagon": {"sheet": "deco", "rect": Rect2i(199, 1311, 116, 72), "solid": Vector2i(100, 30)},
	"woodpile": {"sheet": "deco", "rect": Rect2i(455, 646, 52, 55), "solid": Vector2i(48, 22)},
	"woodpile_small": {"sheet": "deco", "rect": Rect2i(354, 657, 30, 32), "solid": Vector2i(28, 14)},
	"anvil": {"sheet": "deco", "rect": Rect2i(417, 737, 29, 30), "solid": Vector2i(24, 12)},
	"trough": {"sheet": "deco", "rect": Rect2i(426, 577, 74, 31), "solid": Vector2i(70, 18)},
	"hay_trough": {"sheet": "deco", "rect": Rect2i(426, 536, 74, 40), "solid": Vector2i(70, 18)},
	"hay_bale": {"sheet": "deco", "rect": Rect2i(5, 649, 51, 78), "solid": Vector2i(46, 30)},
	"bench": {"sheet": "deco", "rect": Rect2i(193, 1091, 63, 28), "solid": Vector2i(60, 12)},
	"bench_long": {"sheet": "deco", "rect": Rect2i(193, 1145, 63, 38), "solid": Vector2i(60, 14)},
	"table": {"sheet": "deco", "rect": Rect2i(257, 1122, 62, 44), "solid": Vector2i(58, 20)},
	"stool": {"sheet": "deco", "rect": Rect2i(164, 1092, 24, 23), "solid": Vector2i.ZERO},
	"banner_white": {"sheet": "deco", "rect": Rect2i(0, 1218, 32, 71), "solid": Vector2i.ZERO},
	"banner_blue": {"sheet": "deco", "rect": Rect2i(32, 1218, 32, 71), "solid": Vector2i.ZERO},
	"banner_green": {"sheet": "deco", "rect": Rect2i(64, 1218, 32, 71), "solid": Vector2i.ZERO},
	"banner_red": {"sheet": "deco", "rect": Rect2i(96, 1218, 32, 71), "solid": Vector2i.ZERO},
	"banner_yellow": {"sheet": "deco", "rect": Rect2i(128, 1218, 32, 71), "solid": Vector2i.ZERO},
	"banner_black": {"sheet": "deco", "rect": Rect2i(160, 1218, 32, 71), "solid": Vector2i.ZERO},
	"laundry": {"sheet": "deco", "rect": Rect2i(288, 198, 64, 26), "solid": Vector2i.ZERO},
	"laundry_sheet": {"sheet": "deco", "rect": Rect2i(352, 130, 32, 30), "solid": Vector2i.ZERO},
	"scarecrow": {"sheet": "deco", "rect": Rect2i(320, 130, 32, 62), "solid": Vector2i(12, 8)},
	"notice_board": {"sheet": "deco", "rect": Rect2i(225, 160, 30, 32), "solid": Vector2i(26, 10)},
	"sign_post": {"sheet": "deco", "rect": Rect2i(193, 128, 30, 32), "solid": Vector2i(10, 8)},
	"lantern": {"sheet": "deco", "rect": Rect2i(416, 64, 32, 32), "solid": Vector2i.ZERO, "light": Vector2(0, -16)},
	"lantern_cage": {"sheet": "deco", "rect": Rect2i(416, 0, 32, 32), "solid": Vector2i.ZERO, "light": Vector2(0, -14)},
	"pole": {"sheet": "deco", "rect": Rect2i(364, 198, 8, 79), "solid": Vector2i(8, 6)},
	"grave": {"sheet": "deco", "rect": Rect2i(130, 98, 29, 29), "solid": Vector2i(26, 10)},
	"statue": {"sheet": "deco", "rect": Rect2i(0, 288, 32, 64), "solid": Vector2i(22, 12)},
	"tower": {"sheet": "castle", "rect": Rect2i(448, 96, 64, 128), "solid": Vector2i(64, 40)},
	"stall_orange": {"sheet": "deco", "rect": Rect2i(160, 816, 96, 144), "solid": Vector2i(92, 26)},
	"stall_green": {"sheet": "deco", "rect": Rect2i(320, 816, 96, 144), "solid": Vector2i(92, 26)},
	"stall_grey": {"sheet": "deco", "rect": Rect2i(0, 800, 96, 160), "solid": Vector2i(92, 26)},
	"barrel": {"sheet": "containers", "rect": Rect2i(3, 7, 28, 38), "solid": Vector2i(26, 14)},
	"barrel_open": {"sheet": "containers", "rect": Rect2i(130, 20, 28, 39), "solid": Vector2i(26, 14)},
	"barrels": {"sheet": "containers", "rect": Rect2i(197, 5, 55, 50), "solid": Vector2i(52, 22)},
	"barrel_big": {"sheet": "containers", "rect": Rect2i(457, 0, 51, 64), "solid": Vector2i(48, 24)},
	"bucket": {"sheet": "containers", "rect": Rect2i(134, 131, 20, 24), "solid": Vector2i.ZERO},
	"tub": {"sheet": "containers", "rect": Rect2i(3, 133, 58, 59), "solid": Vector2i(54, 26)},
	"crate": {"sheet": "containers", "rect": Rect2i(224, 480, 32, 32), "solid": Vector2i(30, 16)},
	"crate_small": {"sheet": "containers", "rect": Rect2i(160, 492, 31, 20), "solid": Vector2i(28, 12)},
	"crates": {"sheet": "containers", "rect": Rect2i(33, 491, 62, 21), "solid": Vector2i(58, 14)},
	"chest": {"sheet": "containers", "rect": Rect2i(0, 256, 64, 49), "solid": Vector2i(60, 20)},
	"forge": {"sheet": "smith", "rect": Rect2i(0, 0, 64, 128), "solid": Vector2i(60, 40), "frames": 4, "step": Vector2i(64, 0), "light": Vector2(0, -36)},
	"smith_anvil": {"sheet": "smith", "rect": Rect2i(331, 419, 46, 27), "solid": Vector2i(40, 12)},
	"smith_rack": {"sheet": "smith", "rect": Rect2i(258, 482, 61, 90), "solid": Vector2i(58, 18)},
	"smith_bench": {"sheet": "smith", "rect": Rect2i(384, 483, 63, 61), "solid": Vector2i(60, 20)},
	"quench": {"sheet": "smith", "rect": Rect2i(646, 432, 57, 38), "solid": Vector2i(54, 18)},
	"coal": {"sheet": "smith", "rect": Rect2i(547, 200, 59, 44), "solid": Vector2i(50, 16)},
	"tree": {"sheet": "treetop", "rect": Rect2i(1, 0, 94, 80), "solid": Vector2i(20, 12), "trunk": Rect2i(16, 0, 64, 73)},
	"tree_pine": {"sheet": "treetop", "rect": Rect2i(4, 101, 85, 91), "solid": Vector2i(20, 12), "trunk": Rect2i(115, 0, 59, 71)},
	"bridge": {"sheet": "bridges", "rect": Rect2i(0, 0, 96, 77), "solid": Vector2i.ZERO},
	"bush": {"sheet": "plants", "rect": Rect2i(192, 416, 32, 32), "solid": Vector2i(24, 10)},
	"bush_round": {"sheet": "plants", "rect": Rect2i(256, 416, 32, 32), "solid": Vector2i(24, 10)},
	"flowers_red": {"sheet": "plants", "rect": Rect2i(320, 160, 32, 32), "solid": Vector2i.ZERO},
	"flowers_blue": {"sheet": "plants", "rect": Rect2i(224, 160, 32, 32), "solid": Vector2i.ZERO},
	"flowers_yellow": {"sheet": "plants", "rect": Rect2i(288, 160, 32, 32), "solid": Vector2i.ZERO},
	"flowers_mix": {"sheet": "plants", "rect": Rect2i(0, 160, 32, 32), "solid": Vector2i.ZERO},
	"sunflower": {"sheet": "plants", "rect": Rect2i(128, 160, 32, 32), "solid": Vector2i.ZERO},
	"cabbage": {"sheet": "plants", "rect": Rect2i(320, 256, 32, 32), "solid": Vector2i.ZERO},
	"lettuce": {"sheet": "plants", "rect": Rect2i(352, 256, 32, 32), "solid": Vector2i.ZERO},
	"leafy": {"sheet": "plants", "rect": Rect2i(384, 256, 32, 32), "solid": Vector2i.ZERO},
	"herbs": {"sheet": "plants", "rect": Rect2i(192, 352, 32, 32), "solid": Vector2i.ZERO},
	"reeds": {"sheet": "plants", "rect": Rect2i(32, 416, 32, 64), "solid": Vector2i.ZERO},
	"grass_tuft": {"sheet": "plants", "rect": Rect2i(0, 320, 32, 32), "solid": Vector2i.ZERO},
}

## Hanging shop signs (with their iron bracket), LPC Medieval Village Decorations.
const SIGNS: Dictionary = {
	"blank": Rect2i(192, 2, 32, 30),
	"sword": Rect2i(224, 2, 32, 30),
	"potion": Rect2i(256, 2, 32, 30),
	"bread": Rect2i(288, 2, 32, 30),
	"bag": Rect2i(320, 2, 32, 30),
	"book": Rect2i(192, 34, 32, 30),
	"beer": Rect2i(224, 34, 32, 30),
	"inn": Rect2i(256, 34, 32, 30),
	"amulet": Rect2i(288, 34, 32, 30),
	"hammer": Rect2i(320, 34, 32, 30),
}

## Fences (fence_medieval.png kits): horizontal piece (repeats), left end, right end, vertical post.
const FENCES: Dictionary = {
	"rail": {"left": Rect2i(0, 0, 32, 32), "mid": Rect2i(32, 0, 32, 32), "right": Rect2i(64, 0, 32, 32), "post": Rect2i(32, 32, 32, 32)},
	"picket": {"left": Rect2i(0, 192, 32, 32), "mid": Rect2i(32, 192, 32, 32), "right": Rect2i(64, 192, 32, 32), "post": Rect2i(32, 224, 32, 32)},
	"stone": {"left": Rect2i(192, 192, 32, 32), "mid": Rect2i(224, 192, 32, 32), "right": Rect2i(256, 192, 32, 32), "post": Rect2i(224, 224, 32, 32)},
}

static var _textures: Dictionary = {}
static var _pieces: Dictionary = {}
static var _images: Dictionary = {}


static func sheet(id: String) -> Texture2D:
	if not _textures.has(id):
		_textures[id] = load(SHEETS[id])
	return _textures[id]


## One piece of a sheet as its own texture (needed when it repeats across a polygon or a long strip).
static func piece(id: String, rect: Rect2i) -> Texture2D:
	var key: String = "%s:%s" % [id, rect]
	if not _pieces.has(key):
		if not _images.has(id):
			var image: Image = sheet(id).get_image()
			if image.is_compressed():
				image.decompress()
			_images[id] = image
		_pieces[key] = ImageTexture.create_from_image((_images[id] as Image).get_region(rect))
	return _pieces[key]


## [light slope, dark slope] shingle tiles of a roof color.
static func roof_tiles(color: String) -> Array[Texture2D]:
	var entry: Array = ROOFS.get(color, ROOFS["red"])
	if entry[0] == "thatch":
		var y: int = 160 if entry[1] == 0 else 384
		return [piece("thatch", Rect2i(0, y, 32, 32)), piece("thatch", Rect2i(32, y, 32, 32))]
	var x: int = entry[1] * ROOF_KIT_WIDTH
	return [piece("roofs", Rect2i(x, 96, 32, 32)), piece("roofs", Rect2i(x + 128, 96, 32, 32))]


## The three rows (top, middle, bottom) of a wall face, 96 x 32 each.
static func wall_rows(style: String) -> Array[Texture2D]:
	var entry: Array = WALLS.get(style, WALLS["stone"])
	var rect: Rect2i = entry[1]
	var rows: Array[Texture2D] = []
	for i in 3:
		rows.append(piece(entry[0], Rect2i(rect.position.x, rect.position.y + i * 32, rect.size.x, 32)))
	return rows


static func prop_names() -> String:
	return ",".join(PROPS.keys())
