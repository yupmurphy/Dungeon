class_name CaveArt
extends RefCounted
## Procedural cave art of the Goblin Galleries (natural rock walls and floor), first made by Notion AI, given more
## volume after (v0.1.4). Every combination of open neighbors gets its own wall tile; borders stay inside the rock
## cell (no height is borrowed from walkable ground). Volume comes from: a lit rim and a top that darkens toward
## the inside of the rock, a tall south face with ledges and cracks, side faces lit from the west, and a long contact
## shadow with some rubble on the floor below. Source pixels are 16 px, FloorTiles upscales them (nearest).

const TILE: int = TileAtlas.TILE_SIZE
const ATLAS_COLUMNS: int = 16
## Wall tiles: EDGE_VARIANTS sets of 256 (index = open-neighbor mask + 256 * variant), so long faces do not repeat
## every tile; mask 0 (rock closed all around) has its own variants too.
const WALL_MASKS: int = 256
const EDGE_VARIANTS: int = 3
const WALL_TILES: int = WALL_MASKS * EDGE_VARIANTS
const FLOOR_VARIANTS: int = 4
const FLOOR_MASKS: int = 16
const NORTH: int = 1
const EAST: int = 2
const SOUTH: int = 4
const WEST: int = 8
const NORTH_EAST: int = 16
const SOUTH_EAST: int = 32
const SOUTH_WEST: int = 64
const NORTH_WEST: int = 128
const OFFSETS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT,
	Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)]
const BITS: Array[int] = [NORTH, EAST, SOUTH, WEST, NORTH_EAST, SOUTH_EAST, SOUTH_WEST, NORTH_WEST]

const ROCK_OUTLINE: Color = Color("15161c")
## Top of the rock: lit rim at the open edge, then from TOP_LIT to TOP_DEEP over TOP_FADE pixels inward.
const ROCK_RIM: Color = Color("5a5f6d")
const TOP_LIT: Color = Color("383b46")
const TOP_DEEP: Color = Color("1f2128")
const TOP_FADE: float = 5.0
## Lumps on the top (rounded stones): a lighter upper-left edge and a darker lower-right edge.
const LUMP_LIGHT: float = 0.08
const LUMP_DARK: float = 0.12
## South face (the tall front of the wall seen from above).
const FACE_DEPTH: int = 12
const FACE_BROW: Color = Color("8c909b")
const FACE_TOP: Color = Color("666a78")
const FACE_BOTTOM: Color = Color("2f323c")
## Ledges of each variant (row as a fraction of the face: lit top, shadow under it) and cracks (column, first row,
## last row: dark with a lit right edge).
const FACE_LEDGES: Array[Array] = [[0.4], [0.3, 0.7], [0.55]]
## How far each column of a ledge sits below its row (a ledge waves gently along the face, not like mortar).
const LEDGE_WAVE: Array[int] = [0, 0, 0, 1, 1, 1, 1, 0, 0, -1, -1, 0, 0, 0, 1, 1]
const FACE_CRACKS: Array[Array] = [
	[Vector3i(3, 2, 7), Vector3i(8, 5, 11), Vector3i(12, 1, 6)],
	[Vector3i(5, 1, 9), Vector3i(11, 4, 11)],
	[Vector3i(2, 6, 11), Vector3i(7, 1, 5), Vector3i(13, 3, 10)]]
const LEDGE_SHADE: float = 0.22
const CRACK_SHADE: float = 0.3
const CRACK_LIGHT: float = 0.12
## West and east faces: the light comes from the west.
const SIDE_DEPTH: int = 3
const SIDE_WEST: Color = Color("575b69")
const SIDE_EAST: Color = Color("262832")
const FLOOR_BASE: Color = Color("786b58")
const FLOOR_STONE: Color = Color("918577")
const FLOOR_PEBBLE: Color = Color("5b5245")
const FLOOR_STONE_PERIOD: int = 47
## Floor right under a wall face: a long contact shadow (the wall is tall) and a little rubble.
const FLOOR_FRONT_SHADOW_DEPTH: int = 7
const FLOOR_FRONT_SHADOW_STRENGTH: float = 0.55
const FLOOR_SHADOW_DEPTH: int = 3
const FLOOR_SHADOW_STRENGTH: float = 0.28
const FLOOR_BACK_SHADOW_DEPTH: int = 2
const FLOOR_BACK_SHADOW_STRENGTH: float = 0.18
const RUBBLE: Array[Vector2i] = [Vector2i(2, 1), Vector2i(3, 1), Vector2i(9, 2), Vector2i(13, 1), Vector2i(6, 3)]

static var _walls: ImageTexture
static var _floors: ImageTexture


static func atlas_coords(index: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(index % ATLAS_COLUMNS, index / ATLAS_COLUMNS)


## Bits indicate open (walkable) sides and corners around a rock cell.
static func open_mask(is_rock: Callable, x: int, y: int) -> int:
	var mask: int = 0
	for index in OFFSETS.size():
		var at: Vector2i = Vector2i(x, y) + OFFSETS[index]
		if not is_rock.call(at.x, at.y):
			mask |= BITS[index]
	return mask


## Wall tile for an open-neighbor mask, one of its variants by `roll` (0..1).
static func wall_index(mask: int, roll: float) -> int:
	return mask + WALL_MASKS * clampi(int(roll * EDGE_VARIANTS), 0, EDGE_VARIANTS - 1)


## Floor shadow bits indicate adjacent rock on each cardinal side.
static func floor_index(is_rock: Callable, x: int, y: int, roll: float) -> int:
	var rock_mask: int = 0
	if is_rock.call(x, y - 1):
		rock_mask |= NORTH
	if is_rock.call(x + 1, y):
		rock_mask |= EAST
	if is_rock.call(x, y + 1):
		rock_mask |= SOUTH
	if is_rock.call(x - 1, y):
		rock_mask |= WEST
	var variant: int = clampi(int(roll * FLOOR_VARIANTS), 0, FLOOR_VARIANTS - 1)
	return rock_mask * FLOOR_VARIANTS + variant


static func walls_texture() -> ImageTexture:
	if _walls == null:
		_walls = ImageTexture.create_from_image(_build_atlas(true))
	return _walls


static func floors_texture() -> ImageTexture:
	if _floors == null:
		_floors = ImageTexture.create_from_image(_build_atlas(false))
	return _floors


static func _build_atlas(walls: bool) -> Image:
	var count: int = WALL_TILES if walls else FLOOR_MASKS * FLOOR_VARIANTS
	@warning_ignore("integer_division")
	var rows: int = (count + ATLAS_COLUMNS - 1) / ATLAS_COLUMNS
	var width: int = ATLAS_COLUMNS * TILE
	# Raw bytes instead of set_pixel: the atlas is built while the first chunks load.
	var bytes := PackedByteArray()
	bytes.resize(width * rows * TILE * 4)
	for index in count:
		var at: Vector2i = atlas_coords(index) * TILE
		for y in TILE:
			var offset: int = ((at.y + y) * width + at.x) * 4
			for x in TILE:
				var color: Color = _wall_pixel(index, x, y) if walls else _floor_pixel(index, x, y)
				bytes.encode_u32(offset + x * 4, color.to_abgr32())
	return Image.create_from_data(width, rows * TILE, false, Image.FORMAT_RGBA8, bytes)


static func _wall_pixel(index: int, x: int, y: int) -> Color:
	var mask: int = index % WALL_MASKS
	@warning_ignore("integer_division")
	var variant: int = index / WALL_MASKS
	var last: int = TILE - 1
	if ((mask & NORTH) != 0 and y == 0) or ((mask & SOUTH) != 0 and y == last) \
			or ((mask & WEST) != 0 and x == 0) or ((mask & EAST) != 0 and x == last):
		return ROCK_OUTLINE
	var edge: float = _edge_distance(mask, x, y)
	if edge <= 0.0:
		return ROCK_OUTLINE
	var face_top: int = last - FACE_DEPTH
	if (mask & SOUTH) != 0 and y >= face_top:
		return _face_pixel(mask, variant, x, y - face_top)
	if (mask & WEST) != 0 and x <= SIDE_DEPTH:
		return SIDE_WEST.lerp(TOP_LIT, float(x - 1) / SIDE_DEPTH)
	if (mask & EAST) != 0 and last - x <= SIDE_DEPTH:
		return SIDE_EAST.lerp(TOP_DEEP, float(last - x - 1) / SIDE_DEPTH)
	if edge < 2.0:
		return ROCK_RIM
	var color: Color = TOP_LIT.lerp(TOP_DEEP, clampf((edge - 2.0) / TOP_FADE, 0.0, 1.0))
	return _lumps(color, x, y, variant)


## Pixels from the nearest open side or open corner (a large value when the rock is closed all around).
static func _edge_distance(mask: int, x: int, y: int) -> float:
	var last: int = TILE - 1
	var distance: float = TILE * 2.0
	if (mask & NORTH) != 0:
		distance = minf(distance, y)
	if (mask & SOUTH) != 0:
		distance = minf(distance, last - y)
	if (mask & WEST) != 0:
		distance = minf(distance, x)
	if (mask & EAST) != 0:
		distance = minf(distance, last - x)
	# Open corners round the rock off (a diagonal cut), so outer corners are not square blocks.
	if (mask & NORTH_EAST) != 0 and (mask & (NORTH | EAST)) == 0:
		distance = minf(distance, (y + last - x) * 0.7)
	if (mask & SOUTH_EAST) != 0 and (mask & (SOUTH | EAST)) == 0:
		distance = minf(distance, (last - y + last - x) * 0.7)
	if (mask & SOUTH_WEST) != 0 and (mask & (SOUTH | WEST)) == 0:
		distance = minf(distance, (last - y + x) * 0.7)
	if (mask & NORTH_WEST) != 0 and (mask & (NORTH | WEST)) == 0:
		distance = minf(distance, (y + x) * 0.7)
	return distance


## The tall front face: a lit brow, then dark toward the floor, with ledges and vertical cracks.
static func _face_pixel(mask: int, variant: int, x: int, row: int) -> Color:
	if row == 0:
		return FACE_BROW
	var depth: float = float(row) / FACE_DEPTH
	var color: Color = FACE_TOP.lerp(FACE_BOTTOM, depth)
	for ledge: float in FACE_LEDGES[variant]:
		var ledge_row: int = roundi(ledge * FACE_DEPTH) + LEDGE_WAVE[posmod(x + variant * 5 + roundi(ledge * 9), TILE)]
		if row == ledge_row:
			color = color.lightened(CRACK_LIGHT)
		elif row == ledge_row + 1:
			color = color.darkened(LEDGE_SHADE)
	for crack: Vector3i in FACE_CRACKS[variant]:
		if row >= crack.y and row <= crack.z:
			if x == crack.x:
				color = color.darkened(CRACK_SHADE)
			elif x == crack.x + 1:
				color = color.lightened(CRACK_LIGHT)
	# The face's corners turn away from the light: the west end is lit, the east end in shadow.
	if (mask & WEST) != 0 and x <= SIDE_DEPTH:
		color = color.lightened(CRACK_LIGHT)
	if (mask & EAST) != 0 and TILE - 1 - x <= SIDE_DEPTH:
		color = color.darkened(LEDGE_SHADE)
	return color


## Rounded lumps on the rock top, placed differently in each variant.
static func _lumps(color: Color, x: int, y: int, variant: int) -> Color:
	var cell := Vector2i(posmod(x + variant * 5, TILE), posmod(y + variant * 3, TILE))
	@warning_ignore("integer_division")
	var lump := Vector2i(cell.x / 5, cell.y / 5)
	var inside := Vector2i(cell.x % 5, cell.y % 5)
	if posmod(lump.x * 7 + lump.y * 3 + variant, 4) != 0:
		return color
	if inside.x + inside.y <= 1:
		return color.lightened(LUMP_LIGHT)
	if inside.x + inside.y >= 6:
		return color.darkened(LUMP_DARK)
	return color


static func _floor_pixel(index: int, x: int, y: int) -> Color:
	@warning_ignore("integer_division")
	var mask: int = index / FLOOR_VARIANTS
	var variant: int = index % FLOOR_VARIANTS
	var base: Color = FLOOR_BASE
	@warning_ignore("integer_division")
	var pattern: int = posmod((x / 2) * 13 + (y / 2) * 7 + variant * 17, FLOOR_STONE_PERIOD)
	if variant != 0 and pattern == 0:
		base = FLOOR_STONE
	# Rubble fallen from the wall above.
	if (mask & NORTH) != 0 and Vector2i(posmod(x + variant * 4, TILE), y) in RUBBLE:
		base = FLOOR_PEBBLE
	var shade: float = 0.0
	if (mask & NORTH) != 0 and y < FLOOR_FRONT_SHADOW_DEPTH:
		shade = maxf(shade, FLOOR_FRONT_SHADOW_STRENGTH * (1.0 - float(y) / FLOOR_FRONT_SHADOW_DEPTH))
	if (mask & WEST) != 0 and x < FLOOR_SHADOW_DEPTH:
		shade = maxf(shade, FLOOR_SHADOW_STRENGTH * (1.0 - float(x) / FLOOR_SHADOW_DEPTH))
	if (mask & EAST) != 0 and TILE - 1 - x < FLOOR_SHADOW_DEPTH:
		shade = maxf(shade, FLOOR_SHADOW_STRENGTH * (1.0 - float(TILE - 1 - x) / FLOOR_SHADOW_DEPTH))
	if (mask & SOUTH) != 0 and TILE - 1 - y < FLOOR_BACK_SHADOW_DEPTH:
		shade = maxf(shade, FLOOR_BACK_SHADOW_STRENGTH * (1.0 - float(TILE - 1 - y) / FLOOR_BACK_SHADOW_DEPTH))
	return base.darkened(shade)
