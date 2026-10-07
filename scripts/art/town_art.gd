class_name TownArt
extends RefCounted
## Original pixel art drawn by project code; no third-party building textures.
const TILE: int = GameScale.REFERENCE_TILE
const OUTLINE: Color = Color("302d32")
const TIMBER: Color = Color("674937")
const TIMBER_LIGHT: Color = Color("9c7650")
const PLASTER: Color = Color("dbc59a")
const STONE: Color = Color("a8a293")
const WINDOW: Color = Color("364f62")
const WINDOW_LIGHT: Color = Color("719794")
const ROOFS: Array[Color] = [Color("aa6046"), Color("606d7f"), Color("746751"), Color("648076")]
const GROUND_COLORS: Array[Color] = [Color("6d8053"), Color("b3a080"), Color("98998b"), Color("8f9567"), Color("827c70"), Color("77766a"), Color("8e8d7b"), Color("b4ad95"), Color("b29f81"), Color("79895b")]
const BUILDING_MARGIN: int = 4
const ROOF_EXTRA_HEIGHT: int = 28
const WALL_HEIGHT: int = 46
const UPPER_FLOOR_HEIGHT: int = 38
const WINDOW_ROW_OFFSET: int = 18
const FLOOR_BEAM_HEIGHT: int = 4
const MAX_BUILDING_FLOORS: int = 2
const STAIR_TREAD_HEIGHT: int = 13
const STAIR_RISER_HEIGHT: int = 3
const STAIR_STONE_WIDTH: int = 24
const STAIR_BORDER_REF_WIDTH: int = TILE
const STAIR_COPING_REF_WIDTH: int = 6
const STAIR_LANDING_HEIGHT: int = 3
const STAIR_MORTAR: Color = Color("77786e")
const STAIR_TREAD: Color = Color("b3ac96")
const STAIR_TREAD_LIGHT: Color = Color("d0c7b1")
const STAIR_RISER: Color = Color("817b6a")
const FENCE_POST_WIDTH: int = 7
const FENCE_POST_HEIGHT: int = 22
const FENCE_POST_PITCH: int = TILE * 2
const FENCE_RAIL_WIDTH: int = 5
const FENCE_RAIL_OFFSET: int = 6
const FENCE_CAP_OVERHANG: int = 2
const FENCE_CAP_HEIGHT: int = 4
const FENCE_BASE_GAP: int = 4
const FENCE_NAIL: Color = Color("bcb1a0")
const FENCE_DARK: Color = Color("473529")
const FENCE_GRAIN: Color = Color("886143")
const UPPER_SHADOW_OFFSET: Vector2i = Vector2i(8, 4)
const FOUNDATION_HEIGHT: int = 7
const ROOF_TILE_WIDTH: int = 10
const ROOF_TILE_HEIGHT: int = 5
const DOOR_SIZE: Vector2i = Vector2i(12, 22)
const WINDOW_SIZE: Vector2i = Vector2i(10, 13)
const WINDOW_SPACING: int = 27
const TIMBER_SPACING: int = 26
const CHIMNEY_SIZE: Vector2i = Vector2i(11, 23)
const ATLAS_VARIANTS: int = 4
const GROUND_DETAILS: int = 5
const GROUND_HASH_X: int = 73
const GROUND_HASH_Y: int = 151
const STALL_REF_SIZE: Vector2i = Vector2i(64, 46)
const STALL_COLORS: Array[Color] = [Color("a15b4a"), Color("657e8a"), Color("be9959")]
const TREE_SIZE: Vector2i = Vector2i(38, 54)
const TREE_COLORS: Array[Color] = [Color("344c36"), Color("46633d"), Color("63834a"), Color("879557")]
const RIDGE_FRACTION: float = 0.34
const FRONT_ROOF_SHADE: float = 0.08
const REAR_ROOF_LIGHT: float = 0.18
const SIDE_ROOF_SHADE: float = 0.3
const EAVE_SHADOW_HEIGHT: int = 8
const SHADOW_OFFSET: Vector2i = Vector2i(10, 7)
const CAST_SHADOW: Color = Color(0.16, 0.19, 0.15, 0.25)
const PROP_MARGIN: int = 4
const PROP_EXTRA_HEIGHT: int = 22
const STONE_LIGHT: Color = Color("c2bba5")
const WATER: Color = Color("558797")
const WATER_LIGHT: Color = Color("86b2b4")
static var _props: Dictionary = {}
static var _shadows: Dictionary = {}
static var _buildings: Dictionary = {}
static var _stall: Dictionary = {}
static var _tree: ImageTexture
static var _stairs: ImageTexture

static func building_texture(data: TownBuildingData) -> ImageTexture:
	var key: String = "%s:%s:%s:%s" % [data.kind, data.style, data.footprint.size, data.floors]
	if not _buildings.has(key):
		_buildings[key] = ImageTexture.create_from_image(building_image(data))
	return _buildings[key]

static func building_image(data: TownBuildingData) -> Image:
	var w: int = data.footprint.size.x * TILE + BUILDING_MARGIN * 2
	var floor_count: int = clampi(data.floors, 1, MAX_BUILDING_FLOORS)
	var extra_height: int = (floor_count - 1) * UPPER_FLOOR_HEIGHT
	var wall_height: int = WALL_HEIGHT + extra_height
	var h: int = data.footprint.size.y * TILE + ROOF_EXTRA_HEIGHT + extra_height
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var wall_top: int = h - wall_height - FOUNDATION_HEIGHT
	var roof: Color = ROOFS[posmod(data.style, ROOFS.size())]
	# Foot shadow, stone plinth and a warm plaster facade framed with wood.
	img.fill_rect(Rect2i(2, h - 6, w - 4, 6), Color(0.15, 0.18, 0.14, 0.35))
	img.fill_rect(Rect2i(BUILDING_MARGIN, wall_top, w - BUILDING_MARGIN * 2, wall_height + 3), OUTLINE)
	img.fill_rect(Rect2i(BUILDING_MARGIN + 2, wall_top + 2, w - BUILDING_MARGIN * 2 - 4, wall_height - 2), PLASTER)
	img.fill_rect(Rect2i(BUILDING_MARGIN + 2, h - FOUNDATION_HEIGHT - 1, w - BUILDING_MARGIN * 2 - 4, FOUNDATION_HEIGHT), STONE.darkened(0.18))
	img.fill_rect(Rect2i(w - BUILDING_MARGIN - 7, wall_top, 7, wall_height + 1), PLASTER.darkened(0.23))
	img.fill_rect(Rect2i(BUILDING_MARGIN, h - FOUNDATION_HEIGHT - 2, w - BUILDING_MARGIN * 2, 2), STONE_LIGHT)
	for bx in range(BUILDING_MARGIN, w - BUILDING_MARGIN, TILE):
		img.fill_rect(Rect2i(bx, h - FOUNDATION_HEIGHT + 1, 1, FOUNDATION_HEIGHT - 2), STONE.darkened(0.3))
	for x in range(BUILDING_MARGIN, w - BUILDING_MARGIN, TIMBER_SPACING):
		img.fill_rect(Rect2i(x, wall_top, 3, wall_height), TIMBER)
	img.fill_rect(Rect2i(BUILDING_MARGIN, wall_top + 5, w - BUILDING_MARGIN * 2, 3), TIMBER)
	for floor_index in floor_count:
		var row_y: int = wall_top + WINDOW_ROW_OFFSET + floor_index * UPPER_FLOOR_HEIGHT
		for x in range(13, w - 13, WINDOW_SPACING):
			if floor_index == floor_count - 1 and absf(x - w / 2.0) < DOOR_SIZE.x:
				continue
			if floor_index == floor_count - 1 and data.kind in [&"smith", &"books", &"tavern"] and x + WINDOW_SIZE.x >= w - 27:
				continue
			_window(img, Vector2i(x, row_y))
			if floor_count > 1:
				# Thick shutters cast a small shadow instead of floating on flat plaster.
				img.fill_rect(Rect2i(x - 4, row_y, 3, WINDOW_SIZE.y), TIMBER)
				img.fill_rect(Rect2i(x + WINDOW_SIZE.x + 1, row_y, 3, WINDOW_SIZE.y), TIMBER_LIGHT)
	if floor_count > 1:
		var beam_y: int = wall_top + UPPER_FLOOR_HEIGHT - 2
		img.fill_rect(Rect2i(BUILDING_MARGIN, beam_y, w - BUILDING_MARGIN * 2, FLOOR_BEAM_HEIGHT + 2), TIMBER.darkened(0.2))
		img.fill_rect(Rect2i(BUILDING_MARGIN, beam_y, w - BUILDING_MARGIN * 2, FLOOR_BEAM_HEIGHT), TIMBER)
		img.fill_rect(Rect2i(BUILDING_MARGIN, beam_y, w - BUILDING_MARGIN * 2, 1), TIMBER_LIGHT)
	var door_x: int = BUILDING_MARGIN + floori(data.footprint.size.x / 2.0) * TILE + TILE / 2 - DOOR_SIZE.x / 2
	img.fill_rect(Rect2i(door_x - 2, h - DOOR_SIZE.y - FOUNDATION_HEIGHT - 2, DOOR_SIZE.x + 4, DOOR_SIZE.y + 3), STONE)
	img.fill_rect(Rect2i(door_x, h - DOOR_SIZE.y - FOUNDATION_HEIGHT, DOOR_SIZE.x, DOOR_SIZE.y), TIMBER.darkened(0.18))
	for x in range(door_x + 2, door_x + DOOR_SIZE.x, 3):
		img.fill_rect(Rect2i(x, h - DOOR_SIZE.y - FOUNDATION_HEIGHT + 2, 1, DOOR_SIZE.y - 3), TIMBER_LIGHT.darkened(0.2))
	img.fill_rect(Rect2i(door_x + DOOR_SIZE.x - 3, h - 17, 2, 2), Color("d2b16a"))
	# Hipped roof: irregular staggered shingles, bright ridge, dark eave and side planes.
	var ridge: int = 18
	for y in range(8, wall_top + 4):
		var inset: int = maxi(0, ridge - y)
		for x in range(inset, w - inset):
			var ridge_y: int = floori(wall_top * RIDGE_FRACTION)
			var shade: Color = roof.lightened(REAR_ROOF_LIGHT) if y < ridge_y else roof.darkened(FRONT_ROOF_SHADE)
			if x < 7 or x >= w - 7:
				shade = roof.darkened(SIDE_ROOF_SHADE)
			if y % ROOF_TILE_HEIGHT == 0:
				shade = roof.darkened(0.23)
			elif y % ROOF_TILE_HEIGHT == 1:
				shade = shade.lightened(0.08)
			if (x + floori(y / float(ROOF_TILE_HEIGHT)) * 4) % ROOF_TILE_WIDTH == 0:
				shade = shade.darkened(0.1)
			img.set_pixel(x, y, shade)
	img.fill_rect(Rect2i(ridge - 7, 8, w - (ridge - 7) * 2, 3), roof.lightened(0.2))
	img.fill_rect(Rect2i(0, floori(wall_top * RIDGE_FRACTION), w, 3), roof.lightened(0.28))
	img.fill_rect(Rect2i(BUILDING_MARGIN, wall_top + 7, w - BUILDING_MARGIN * 2, EAVE_SHADOW_HEIGHT), Color("776653"))
	img.fill_rect(Rect2i(0, wall_top + 4, w, 3), OUTLINE)
	img.fill_rect(Rect2i(0, wall_top + 4, w, 1), roof.darkened(0.12))
	# A small dormer/crest distinguishes civic and shop buildings.
	if data.kind == &"hall":
		img.fill_rect(Rect2i(w / 2 - 10, wall_top - 18, 20, 23), TIMBER)
		img.fill_rect(Rect2i(w / 2 - 8, wall_top - 16, 16, 18), PLASTER)
		_window(img, Vector2i(w / 2 - 5, wall_top - 14))
		img.fill_rect(Rect2i(w / 2 - 14, wall_top - 21, 28, 4), roof.darkened(0.25))
	else:
		var cx: int = w - 24
		img.fill_rect(Rect2i(cx, 13, CHIMNEY_SIZE.x, CHIMNEY_SIZE.y), OUTLINE)
		img.fill_rect(Rect2i(cx + 1, 13, CHIMNEY_SIZE.x - 2, CHIMNEY_SIZE.y - 1), STONE)
		for yy in range(16, 34, 5):
			img.fill_rect(Rect2i(cx + 1, yy, CHIMNEY_SIZE.x - 2, 1), STONE.darkened(0.25))
		img.fill_rect(Rect2i(cx - 2, 12, CHIMNEY_SIZE.x + 4, 4), STONE.darkened(0.25))
	if data.kind in [&"smith", &"books", &"tavern"]:
		var sign := Rect2i(w - 27, wall_top + extra_height + WINDOW_ROW_OFFSET, 18, 14)
		img.fill_rect(sign, TIMBER)
		img.fill_rect(sign.grow(-2), Color("c2b38e"))
		if data.kind == &"smith":
			img.fill_rect(Rect2i(sign.position + Vector2i(4, 4), Vector2i(10, 3)), OUTLINE)
			img.fill_rect(Rect2i(sign.position + Vector2i(7, 7), Vector2i(4, 3)), OUTLINE)
		elif data.kind == &"books":
			img.fill_rect(Rect2i(sign.position + Vector2i(4, 3), Vector2i(5, 8)), Color("597584"))
			img.fill_rect(Rect2i(sign.position + Vector2i(10, 3), Vector2i(4, 8)), Color("eee0b7"))
		else:
			img.fill_rect(Rect2i(sign.position + Vector2i(5, 4), Vector2i(7, 7)), Color("b68946"))
			img.fill_rect(Rect2i(sign.position + Vector2i(4, 3), Vector2i(9, 2)), Color("f3e8cb"))
			img.fill_rect(Rect2i(sign.position + Vector2i(12, 5), Vector2i(3, 4)), TIMBER)
	if data.kind == &"house":
		# Small flower boxes break up the repeated residential facades without blocking doors.
		for bx in [9, w - 22]:
			img.fill_rect(Rect2i(bx, h - 10, 13, 5), TIMBER)
			for fx in range(bx + 2, bx + 11, 3):
				img.fill_rect(Rect2i(fx, h - 13, 2, 4), Color("59724a"))
				img.set_pixel(fx, h - 13, Color("e2b877") if data.style % 2 else Color("bc777c"))
	return img

static func _window(img: Image, at: Vector2i) -> void:
	img.fill_rect(Rect2i(at - Vector2i.ONE, WINDOW_SIZE + Vector2i(2, 2)), TIMBER)
	img.fill_rect(Rect2i(at, WINDOW_SIZE), WINDOW)
	img.fill_rect(Rect2i(at + Vector2i(1, 1), Vector2i(3, 5)), WINDOW_LIGHT)
	img.fill_rect(Rect2i(at + Vector2i(4, 0), Vector2i(2, WINDOW_SIZE.y)), TIMBER_LIGHT)
	img.fill_rect(Rect2i(at + Vector2i(0, 6), Vector2i(WINDOW_SIZE.x, 2)), TIMBER_LIGHT)
	img.fill_rect(Rect2i(at + Vector2i(-2, WINDOW_SIZE.y), Vector2i(WINDOW_SIZE.x + 4, 2)), TIMBER)

static func ground_atlas() -> Image:
	var img := Image.create(TILE * ATLAS_VARIANTS, TILE * GROUND_COLORS.size(), false, Image.FORMAT_RGBA8)
	for kind in GROUND_COLORS.size():
		for variant in ATLAS_VARIANTS:
			var offset := Vector2i(variant * TILE, kind * TILE)
			img.fill_rect(Rect2i(offset, Vector2i(TILE, TILE)), GROUND_COLORS[kind])
			for yy in TILE:
				for xx in TILE:
					var pattern: int = posmod(xx * GROUND_HASH_X + yy * GROUND_HASH_Y + variant * 19, 47)
					if kind == TownLayout.Ground.PAVING and (yy % 8 == 0 or (xx + (yy / 8) * 8) % TILE == 0):
						img.set_pixelv(offset + Vector2i(xx, yy), GROUND_COLORS[kind].darkened(0.14))
					elif kind in [TownLayout.Ground.LEDGE_FRONT, TownLayout.Ground.LEDGE_SIDE, TownLayout.Ground.LEDGE_BACK]:
						var ledge_color: Color = STONE.darkened(0.24)
						if yy < 3:
							ledge_color = STONE_LIGHT if kind == TownLayout.Ground.LEDGE_FRONT else STONE
						elif yy >= TILE - 2:
							ledge_color = OUTLINE
						elif yy % 6 == 0 or (xx + (yy / 6) * 5) % 11 == 0:
							ledge_color = STONE.darkened(0.4)
						if kind == TownLayout.Ground.LEDGE_SIDE and xx > TILE / 2:
							ledge_color = ledge_color.darkened(0.12)
						img.set_pixelv(offset + Vector2i(xx, yy), ledge_color)
					elif kind == TownLayout.Ground.STAIRS:
						img.set_pixelv(offset + Vector2i(xx, yy), STAIR_TREAD)
					elif kind == TownLayout.Ground.RAMP and yy in [0, TILE - 1]:
						img.set_pixelv(offset + Vector2i(xx, yy), STONE.darkened(0.2))
					elif pattern < GROUND_DETAILS:
						img.set_pixelv(offset + Vector2i(xx, yy), GROUND_COLORS[kind].lightened(0.08) if pattern % 2 else GROUND_COLORS[kind].darkened(0.08))
	return img

static func stall_texture(style: int) -> ImageTexture:
	var v: int = posmod(style, STALL_COLORS.size())
	if not _stall.has(v):
		var img := Image.create(STALL_REF_SIZE.x, STALL_REF_SIZE.y, false, Image.FORMAT_RGBA8)
		img.fill(Color.TRANSPARENT)
		img.fill_rect(Rect2i(4, 3, 3, 39), TIMBER)
		img.fill_rect(Rect2i(57, 3, 3, 39), TIMBER)
		img.fill_rect(Rect2i(0, 4, 64, 17), STALL_COLORS[v])
		for x in range(0, 64, 16):
			img.fill_rect(Rect2i(x, 4, 8, 17), Color("dacda6"))
		img.fill_rect(Rect2i(0, 21, 64, 3), OUTLINE)
		img.fill_rect(Rect2i(4, 29, 56, 13), TIMBER)
		img.fill_rect(Rect2i(4, 29, 56, 3), TIMBER_LIGHT)
		for x in range(10, 52, 9):
			img.fill_rect(Rect2i(x, 25, 6, 5), STALL_COLORS[(v + 1) % STALL_COLORS.size()])
		_stall[v] = ImageTexture.create_from_image(img)
	return _stall[v]

static func tree_texture() -> ImageTexture:
	if _tree == null:
		var img := Image.create(TREE_SIZE.x, TREE_SIZE.y, false, Image.FORMAT_RGBA8)
		img.fill(Color.TRANSPARENT)
		img.fill_rect(Rect2i(17, 31, 5, 19), TIMBER)
		for y in range(3, 40):
			for x in range(2, 37):
				var p := Vector2(x - 19, (y - 21) * 0.85)
				if p.length() < 17.0 + sin(x * 1.3 + y * 0.8):
					var index: int = clampi(floori((41 - y - x / 3.0) / 13.0), 0, TREE_COLORS.size() - 1)
					img.set_pixel(x, y, TREE_COLORS[index])
		_tree = ImageTexture.create_from_image(img)
	return _tree


static func building_shadow(data: TownBuildingData) -> ImageTexture:
	var key: String = "%s:%s" % [data.footprint.size, data.floors]
	if not _shadows.has(key):
		var size: Vector2i = data.footprint.size * TILE + SHADOW_OFFSET * 2 + UPPER_SHADOW_OFFSET * (data.floors - 1)
		var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
		img.fill(Color.TRANSPARENT)
		for y in range(SHADOW_OFFSET.y, size.y):
			var inset: int = SHADOW_OFFSET.x + floori((size.y - y) * 0.12)
			img.fill_rect(Rect2i(inset, y, maxi(1, size.x - inset), 1), CAST_SHADOW)
		_shadows[key] = ImageTexture.create_from_image(img)
	return _shadows[key]

static func _ellipse(img: Image, at: Vector2, radius: Vector2, color: Color) -> void:
	for y in range(maxi(0, floori(at.y - radius.y)), mini(img.get_height(), ceili(at.y + radius.y + 1))):
		for x in range(maxi(0, floori(at.x - radius.x)), mini(img.get_width(), ceili(at.x + radius.x + 1))):
			if ((Vector2(x, y) - at) / radius).length_squared() <= 1.0:
				img.set_pixel(x, y, color)

static func prop_texture(data: TownPropData) -> ImageTexture:
	if data.kind == &"tree":
		return tree_texture()
	var key: String = "%s:%s:%s" % [data.kind, data.style, data.footprint.size]
	if not _props.has(key):
		_props[key] = ImageTexture.create_from_image(prop_image(data))
	return _props[key]

static func prop_image(data: TownPropData) -> Image:
	var size: Vector2i = data.footprint.size * TILE + Vector2i(PROP_MARGIN * 2, PROP_EXTRA_HEIGHT)
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var w: int = size.x
	var h: int = size.y
	_ellipse(img, Vector2(w / 2.0 + 2, h - 3), Vector2(w / 2.0 - 2, 3), CAST_SHADOW)
	match data.kind:
		&"fountain":
			_ellipse(img, Vector2(w / 2.0, h - 20), Vector2(w / 2.0 - 2, 18), OUTLINE)
			_ellipse(img, Vector2(w / 2.0, h - 22), Vector2(w / 2.0 - 4, 17), STONE)
			_ellipse(img, Vector2(w / 2.0, h - 25), Vector2(w / 2.0 - 8, 12), WATER)
			_ellipse(img, Vector2(w / 2.0, h - 29), Vector2(w / 2.0 - 8, 7), WATER_LIGHT)
			img.fill_rect(Rect2i(w / 2 - 4, h - 47, 8, 22), STONE_LIGHT)
			_ellipse(img, Vector2(w / 2.0, h - 47), Vector2(12, 5), STONE_LIGHT)
			_ellipse(img, Vector2(w / 2.0, h - 49), Vector2(9, 3), WATER)
			img.fill_rect(Rect2i(w / 2 - 1, h - 59, 2, 9), WATER_LIGHT)
		&"bench":
			img.fill_rect(Rect2i(6, h - 15, w - 12, 4), TIMBER_LIGHT)
			img.fill_rect(Rect2i(6, h - 25, w - 12, 4), TIMBER)
			for x in [8, w - 11]:
				img.fill_rect(Rect2i(x, h - 25, 3, 23), TIMBER)
		&"board":
			img.fill_rect(Rect2i(5, 9, w - 10, 19), TIMBER)
			for x in [7, w - 10]:
				img.fill_rect(Rect2i(x, 12, 3, h - 14), TIMBER)
			for x in range(9, w - 10, 8):
				img.fill_rect(Rect2i(x, 13, 6, 11), PLASTER)
				img.fill_rect(Rect2i(x + 1, 16, 4, 1), TIMBER_LIGHT)
		&"anvil":
			img.fill_rect(Rect2i(10, h - 14, w - 20, 11), TIMBER)
			img.fill_rect(Rect2i(8, h - 23, w - 16, 5), Color("667685"))
			img.fill_rect(Rect2i(4, h - 25, w - 8, 3), Color("96a1a7"))
			img.fill_rect(Rect2i(15, h - 19, w - 28, 7), Color("44525c"))
		&"wood":
			for y in [h - 10, h - 16, h - 22]:
				img.fill_rect(Rect2i(5, y, w - 10, 5), TIMBER)
				img.fill_rect(Rect2i(5, y, w - 10, 1), TIMBER_LIGHT)
				_ellipse(img, Vector2(8, y + 2), Vector2(3, 2), PLASTER.darkened(0.2))
		&"coal":
			_ellipse(img, Vector2(w / 2.0, h - 11), Vector2(w / 2.0 - 4, 9), OUTLINE)
			for x in range(7, w - 7, 6):
				img.fill_rect(Rect2i(x, h - 18 + x % 4, 4, 4), Color("51545a"))
		&"barrel":
			_ellipse(img, Vector2(w / 2.0, h - 13), Vector2(8, 11), TIMBER)
			_ellipse(img, Vector2(w / 2.0, h - 22), Vector2(7, 3), TIMBER_LIGHT)
			for y in [h - 17, h - 8]:
				img.fill_rect(Rect2i(w / 2 - 7, y, 14, 2), Color("60646a"))
		&"crate":
			img.fill_rect(Rect2i(4, h - 25, w - 8, 22), TIMBER)
			img.fill_rect(Rect2i(6, h - 23, w - 12, 17), TIMBER_LIGHT)
			for y in range(h - 20, h - 5, 4):
				img.fill_rect(Rect2i(6, y, w - 12, 1), TIMBER)
		&"fence_vertical", &"fence":
			_draw_fence(img, data.kind == &"fence_vertical")
		&"flowers", &"planter":
			if data.kind == &"planter":
				img.fill_rect(Rect2i(5, h - 14, w - 10, 11), Color("a76f4f"))
			for x in range(5, w - 4, 4):
				img.fill_rect(Rect2i(x, h - 20 + x % 3, 2, 14), Color("58774b"))
				_ellipse(img, Vector2(x + 1, h - 20 + x % 3), Vector2(2, 2), Color("dbc080") if data.style % 2 else Color("bb7884"))
	return img


## Full flight, not a repeated striped tile. Side coping belongs outside the six-tile usable passage.
static func stair_texture() -> ImageTexture:
	if _stairs == null:
		_stairs = ImageTexture.create_from_image(stair_image())
	return _stairs

static func stair_image() -> Image:
	var border: int = STAIR_BORDER_REF_WIDTH * TownData.STAIR_BORDER_TILES
	var flight_width: int = TownData.STAIRS.size.x * TILE
	var height: int = TownData.STAIRS.size.y * TILE
	var img := Image.create(flight_width + border * 2, height, false, Image.FORMAT_RGBA8)
	img.fill(STAIR_MORTAR)
	for step in TownData.STAIRS.size.y:
		var y: int = step * TILE
		img.fill_rect(Rect2i(border, y, flight_width, STAIR_TREAD_HEIGHT), STAIR_TREAD)
		img.fill_rect(Rect2i(border, y + STAIR_TREAD_HEIGHT, flight_width, STAIR_RISER_HEIGHT), STAIR_RISER)
		img.fill_rect(Rect2i(border, y + STAIR_TREAD_HEIGHT - 1, flight_width, 1), STAIR_TREAD_LIGHT)
		img.fill_rect(Rect2i(border, y + TILE - 1, flight_width, 1), STAIR_MORTAR)
		# Stagger joints; each tread is assembled from large stones, with sparse wear rather than noise.
		for x in range(border - (step % 2) * (STAIR_STONE_WIDTH / 2), border + flight_width, STAIR_STONE_WIDTH):
			var left: int = maxi(x, border)
			var right: int = mini(x + STAIR_STONE_WIDTH - 1, border + flight_width)
			img.fill_rect(Rect2i(left, y + 2, maxi(1, right - left), STAIR_TREAD_HEIGHT - 3), STAIR_TREAD.lightened(0.025 * (step % 3)))
			if x >= border:
				img.fill_rect(Rect2i(x, y, 1, TILE - 1), STAIR_MORTAR)
			if right - left > 6:
				img.fill_rect(Rect2i(left + 3, y + STAIR_TREAD_HEIGHT - 2, 3, 1), STAIR_RISER.lightened(0.15))
	for x in [0, border + flight_width]:
		# Raised side masonry has a light coping, a shaded face and a continuous outer contact line.
		img.fill_rect(Rect2i(x, 0, border, height), STONE.darkened(0.2))
		img.fill_rect(Rect2i(x + 1, 0, STAIR_COPING_REF_WIDTH, height), STONE_LIGHT)
		img.fill_rect(Rect2i(x + STAIR_COPING_REF_WIDTH + 1, 0, 2, height), STAIR_MORTAR)
		for y in range(TILE - 1, height, TILE):
			img.fill_rect(Rect2i(x, y, border, 1), STAIR_MORTAR)
		img.fill_rect(Rect2i(x + border - 2, 0, 2, height), OUTLINE)
	img.fill_rect(Rect2i(border, 0, flight_width, STAIR_LANDING_HEIGHT), STONE_LIGHT)
	return img

static func _timber_prism(img: Image, rect: Rect2i) -> void:
	img.fill_rect(rect, TIMBER)
	img.fill_rect(Rect2i(rect.end.x - 2, rect.position.y, 2, rect.size.y), FENCE_DARK)
	img.fill_rect(Rect2i(rect.position, Vector2i(1, rect.size.y)), TIMBER_LIGHT)
	img.fill_rect(Rect2i(rect.position, Vector2i(rect.size.x - 1, 2)), TIMBER_LIGHT)

static func _fence_post(img: Image, x: int, base_y: int) -> void:
	var top: int = maxi(0, base_y - FENCE_POST_HEIGHT)
	var rect := Rect2i(x - FENCE_POST_WIDTH / 2, top, FENCE_POST_WIDTH, base_y - top)
	_timber_prism(img, rect)
	img.fill_rect(Rect2i(rect.position.x - FENCE_CAP_OVERHANG, top, FENCE_POST_WIDTH + FENCE_CAP_OVERHANG * 2, FENCE_CAP_HEIGHT), FENCE_DARK)
	img.fill_rect(Rect2i(rect.position.x - FENCE_CAP_OVERHANG, top, FENCE_POST_WIDTH + FENCE_CAP_OVERHANG * 2 - 2, FENCE_CAP_HEIGHT - 1), TIMBER_LIGHT)
	if rect.size.y > 10:
		img.fill_rect(Rect2i(x - 1, top + 6, 1, rect.size.y - 8), FENCE_GRAIN)
		img.set_pixel(x, top + 9, FENCE_NAIL)
		img.set_pixel(x, base_y - 5, FENCE_NAIL)

static func _draw_fence(img: Image, vertical: bool) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	if vertical:
		# Posts and two solid rails share one continuous multi-tile run, never disconnected dots.
		var center: int = w / 2
		for y in range(PROP_EXTRA_HEIGHT, h - FENCE_BASE_GAP):
			img.fill_rect(Rect2i(center + 3, y, 7, 1), CAST_SHADOW)
		for x in [center - FENCE_RAIL_OFFSET, center + 2]:
			_timber_prism(img, Rect2i(x, 3, FENCE_RAIL_WIDTH, h - FENCE_BASE_GAP - 3))
			for y in range(12, h - 8, TILE):
				img.fill_rect(Rect2i(x + 2, y, 1, 6), FENCE_GRAIN)
		var base: int = h - FENCE_BASE_GAP
		while base > PROP_EXTRA_HEIGHT:
			_fence_post(img, center, base)
			base -= FENCE_POST_PITCH
		_fence_post(img, center, PROP_EXTRA_HEIGHT)
	else:
		for y in [h - 19, h - 10]:
			_timber_prism(img, Rect2i(3, y, w - 6, FENCE_RAIL_WIDTH))
		for x in [FENCE_POST_WIDTH, w - FENCE_POST_WIDTH]:
			_fence_post(img, x, h - FENCE_BASE_GAP)
