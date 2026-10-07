class_name CaveArt
extends RefCounted
## Original procedural cave art. Every rock neighbor combination gets a complete opaque tile.
## Borders stay inside the blocked cell; no visual height is borrowed from walkable ground.
## Source pixels match the existing 16 px atlas and FloorTiles upscales with nearest filtering.

const TILE: int = TileAtlas.TILE_SIZE
const ATLAS_COLUMNS: int = 16
const WALL_TILES: int = 256
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
const ROCK_TOP: Color = Color("2d2f38")
const ROCK_LIGHT: Color = Color("979ba6")
const ROCK_EDGE: Color = Color("5e6370")
const ROCK_OUTLINE: Color = Color("191b22")
const ROCK_FACE: Color = Color("606472")
const FLOOR_BASE: Color = Color("786b58")
const FLOOR_STONE: Color = Color("918577")
const RIM_DEPTH: int = 2
const FACE_DEPTH: int = 10
const SIDE_FACE_DEPTH: int = 3
const ROCK_BASE: Color = Color("343741")
const ROCK_SIDE_WEST: Color = Color("505461")
const ROCK_SIDE_EAST: Color = Color("242731")
const NORTH_EDGE: Color = Color("515662")
const FACE_FACET_PERIOD: int = 17
const FACE_FACET_SHADE: float = 0.12
const SIDE_FACE_SHADE: float = 0.18
const FLOOR_FRONT_SHADOW_DEPTH: int = 5
const FLOOR_FRONT_SHADOW_STRENGTH: float = 0.48
const FLOOR_BACK_SHADOW_DEPTH: int = 2
const FLOOR_BACK_SHADOW_STRENGTH: float = 0.18
const TEXTURE_BLOCK: int = 4
const TEXTURE_AMOUNT: float = 0.025
const TEXTURE_PERIOD: int = 11
const FLOOR_STONE_PERIOD: int = 47
const FLOOR_SHADOW_DEPTH: int = 3
const FLOOR_SHADOW_STRENGTH: float = 0.28

static var _walls: ImageTexture
static var _floors: ImageTexture


static func atlas_coords(index: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(index % ATLAS_COLUMNS, index / ATLAS_COLUMNS)


## Bits indicate exposed sides/corners, not which wall tile was picked first.
static func open_mask(is_rock: Callable, x: int, y: int) -> int:
	var mask: int = 0
	for index in OFFSETS.size():
		var at: Vector2i = Vector2i(x, y) + OFFSETS[index]
		if not is_rock.call(at.x, at.y):
			mask |= BITS[index]
	return mask


## Floor shadow bits indicate adjacent rock on each cardinal side.
static func floor_index(is_rock: Callable, x: int, y: int, roll: float) -> int:
	var rock_mask: int = 0
	# Floors need cardinal contact shadows only; avoid four unnecessary diagonal queries per cell.
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
	var image := Image.create(ATLAS_COLUMNS * TILE, rows * TILE, false, Image.FORMAT_RGBA8)
	for index in count:
		var at: Vector2i = atlas_coords(index) * TILE
		for y in TILE:
			for x in TILE:
				var color: Color = _wall_pixel(index, x, y) if walls else _floor_pixel(index, x, y)
				image.set_pixel(at.x + x, at.y + y, color)
	return image


static func _wall_pixel(mask: int, x: int, y: int) -> Color:
	var last: int = TILE - 1
	# Every exposed outer boundary remains continuous; volume is drawn inside the solid footprint.
	if ((mask & NORTH) != 0 and y == 0) or ((mask & SOUTH) != 0 and y == last) \
			or ((mask & WEST) != 0 and x == 0) or ((mask & EAST) != 0 and x == last):
		return ROCK_OUTLINE
	var corner: int = TILE
	if (mask & NORTH_EAST) != 0 and (mask & (NORTH | EAST)) == 0:
		corner = mini(corner, y + last - x)
	if (mask & SOUTH_EAST) != 0 and (mask & (SOUTH | EAST)) == 0:
		corner = mini(corner, last - y + last - x)
	if (mask & SOUTH_WEST) != 0 and (mask & (SOUTH | WEST)) == 0:
		corner = mini(corner, last - y + x)
	if (mask & NORTH_WEST) != 0 and (mask & (NORTH | WEST)) == 0:
		corner = mini(corner, y + x)
	if corner == 0:
		return ROCK_OUTLINE
	if corner < RIM_DEPTH:
		return ROCK_EDGE
	var base: Color = ROCK_TOP
	var face_lip: int = last - FACE_DEPTH
	if (mask & SOUTH) != 0 and y >= face_lip:
		# One lit brow separates the top from the tall vertical face, not a bright four-sided frame.
		if y == face_lip:
			base = ROCK_LIGHT
		elif y == face_lip + 1:
			base = ROCK_EDGE
		else:
			var depth: float = float(y - face_lip - 1) / FACE_DEPTH
			base = ROCK_FACE.lerp(ROCK_BASE, depth)
			# Irregular faceting, not horizontal brick mortar.
			if posmod(x * 3 + y, FACE_FACET_PERIOD) == 0:
				base = base.darkened(FACE_FACET_SHADE)
		if (mask & WEST) != 0 and x < SIDE_FACE_DEPTH:
			base = base.darkened(SIDE_FACE_SHADE)
		if (mask & EAST) != 0 and last - x < SIDE_FACE_DEPTH:
			base = base.darkened(SIDE_FACE_SHADE)
		return base
	# Lateral faces have different light/shadow values; north has only a restrained rear edge.
	if (mask & WEST) != 0 and x < SIDE_FACE_DEPTH:
		base = ROCK_SIDE_WEST
	elif (mask & EAST) != 0 and last - x < SIDE_FACE_DEPTH:
		base = ROCK_SIDE_EAST
	elif (mask & NORTH) != 0 and y < RIM_DEPTH:
		base = NORTH_EDGE
	@warning_ignore("integer_division")
	var pattern: int = posmod((x / TEXTURE_BLOCK) * 7 + (y / TEXTURE_BLOCK) * 3, TEXTURE_PERIOD)
	return base.lightened(TEXTURE_AMOUNT) if pattern == 0 else base


static func _floor_pixel(index: int, x: int, y: int) -> Color:
	@warning_ignore("integer_division")
	var mask: int = index / FLOOR_VARIANTS
	var variant: int = index % FLOOR_VARIANTS
	var base: Color = FLOOR_BASE
	var pattern: int = posmod((x / 2) * 13 + (y / 2) * 7 + variant * 17, FLOOR_STONE_PERIOD)
	if variant != 0 and pattern == 0:
		base = FLOOR_STONE
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
