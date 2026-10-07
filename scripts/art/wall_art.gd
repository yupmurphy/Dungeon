class_name WallArt
extends RefCounted
## Original procedural wall details. Transparent art leaves the rock boundary visible.

const SIZE: Vector2i = Vector2i(16, 16)
const FLAME_FRAMES: int = 4
const DECOR_KINDS: Array[String] = ["cracks", "roots", "web", "goblin_mark", "wall_bones"]
const OUTLINE: Color = Color("191b22")
const IRON: Color = Color("55515b")
const IRON_LIGHT: Color = Color("89818b")
const WOOD: Color = Color("805334")
const FIRE_OUTER: Color = Color("ed6424")
const FIRE_INNER: Color = Color("ffc05c")
const FIRE_CORE: Color = Color("fff2aa")
const ROOT: Color = Color("786342")
const ROOT_LIGHT: Color = Color("9b8357")
const SILK: Color = Color(0.7, 0.73, 0.76, 0.6)
const MARK: Color = Color("a47b59")
const BONE: Color = Color("b9ad8c")
const FLAME_TIPS: Array[Vector2i] = [Vector2i(7, 1), Vector2i(8, 0), Vector2i(9, 2), Vector2i(7, 0)]
const FLAME_RADIUS: float = 3.0
const CORE_RADIUS: float = 1.8
## The plate is inside rock; the socket and torch body are outside, toward the adjacent room cell.
const WALL_ANCHOR_DISTANCE: int = 7
const PROJECTION_DISTANCE: int = 9
const SOCKET_OFFSET: Vector2i = Vector2i.ZERO
## A front-facing torch sits on the vertical face, not at ground height in the adjacent cell.
const SOUTH_BODY_OFFSET: Vector2i = Vector2i(0, 0)
const SOUTH_ANCHOR_OFFSET: Vector2i = Vector2i(-3, 1)
const BRACKET_SIZE: Vector2i = Vector2i(48, 48)
const PLATE_SIZE: Vector2i = Vector2i(5, 5)
const CAST_SHADOW: Color = Color(0.04, 0.03, 0.05, 0.28)
const SHADOW_RADIUS: Vector2 = Vector2(4.5, 1.8)

static var _flames: Array[ImageTexture] = []
static var _decor: Dictionary = {}
static var _brackets: Dictionary = {}
static var _shadow: ImageTexture


static func torch_texture(frame: int) -> ImageTexture:
	if _flames.is_empty():
		for index in FLAME_FRAMES:
			_flames.append(ImageTexture.create_from_image(_torch_image(index)))
	return _flames[posmod(frame, FLAME_FRAMES)]


static func decoration_texture(kind: String) -> ImageTexture:
	if not _decor.has(kind):
		_decor[kind] = ImageTexture.create_from_image(_decoration_image(kind))
	return _decor[kind]


static func _torch_image(frame: int) -> Image:
	var img := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	# The flame/body are separate from the wall plate and projecting iron arm.
	img.fill_rect(Rect2i(6, 5, 4, 10), OUTLINE)
	img.fill_rect(Rect2i(7, 6, 2, 8), WOOD)
	img.fill_rect(Rect2i(6, 7, 4, 2), IRON_LIGHT)
	_disc(img, Vector2(8, 4), FLAME_RADIUS, FIRE_OUTER)
	_line(img, Vector2i(8, 4), FLAME_TIPS[frame], FIRE_OUTER)
	_disc(img, Vector2(8, 5), CORE_RADIUS, FIRE_INNER)
	img.set_pixel(8, 5, FIRE_CORE)
	return img


static func _decoration_image(kind: String) -> Image:
	var img := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	match kind:
		"cracks":
			_line(img, Vector2i(7, 2), Vector2i(9, 6), OUTLINE)
			_line(img, Vector2i(9, 6), Vector2i(5, 10), OUTLINE)
			_line(img, Vector2i(5, 10), Vector2i(7, 14), OUTLINE)
			_line(img, Vector2i(8, 7), Vector2i(12, 8), OUTLINE)
		"roots":
			_line(img, Vector2i(4, 2), Vector2i(6, 7), ROOT)
			_line(img, Vector2i(6, 7), Vector2i(4, 13), ROOT)
			_line(img, Vector2i(6, 7), Vector2i(11, 11), ROOT)
			_line(img, Vector2i(10, 2), Vector2i(8, 7), ROOT_LIGHT)
		"web":
			var center := Vector2i(3, 3)
			for end: Vector2i in [Vector2i(12, 3), Vector2i(10, 10), Vector2i(3, 12)]:
				_line(img, center, end, SILK)
			_line(img, Vector2i(7, 3), Vector2i(6, 6), SILK)
			_line(img, Vector2i(6, 6), Vector2i(3, 7), SILK)
			_line(img, Vector2i(10, 3), Vector2i(8, 8), SILK)
			_line(img, Vector2i(8, 8), Vector2i(3, 10), SILK)
		"goblin_mark":
			_line(img, Vector2i(4, 11), Vector2i(8, 3), MARK)
			_line(img, Vector2i(8, 3), Vector2i(12, 11), MARK)
			_line(img, Vector2i(5, 9), Vector2i(11, 9), MARK)
		"wall_bones":
			img.fill_rect(Rect2i(5, 4, 6, 6), BONE)
			img.set_pixel(6, 6, OUTLINE)
			img.set_pixel(9, 6, OUTLINE)
			img.fill_rect(Rect2i(7, 9, 2, 2), BONE)
			_line(img, Vector2i(4, 12), Vector2i(12, 14), BONE)
			_line(img, Vector2i(4, 14), Vector2i(12, 12), BONE)
	return img


static func _disc(img: Image, center: Vector2, radius: float, color: Color) -> void:
	for y in range(floori(center.y - radius), ceili(center.y + radius) + 1):
		for x in range(floori(center.x - radius), ceili(center.x + radius) + 1):
			if x >= 0 and y >= 0 and x < SIZE.x and y < SIZE.y and Vector2(x, y).distance_to(center) <= radius:
				img.set_pixel(x, y, color)


static func _line(img: Image, from: Vector2i, to: Vector2i, color: Color) -> void:
	var steps: int = maxi(absi(to.x - from.x), absi(to.y - from.y))
	for index in steps + 1:
		var at: Vector2 = Vector2(from).lerp(Vector2(to), float(index) / maxf(steps, 1))
		img.set_pixel(roundi(at.x), roundi(at.y), color)


static func bracket_texture(direction: Vector2i) -> ImageTexture:
	if not _brackets.has(direction):
		var image := Image.create(BRACKET_SIZE.x, BRACKET_SIZE.y, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		@warning_ignore("integer_division")
		var center: Vector2i = BRACKET_SIZE / 2
		var anchor: Vector2i = center + (SOUTH_ANCHOR_OFFSET if direction == Vector2i.DOWN else direction * WALL_ANCHOR_DISTANCE)
		var socket: Vector2i = center + mount_offset(direction) + SOCKET_OFFSET
		@warning_ignore("integer_division")
		var plate := Rect2i(anchor - PLATE_SIZE / 2, PLATE_SIZE)
		image.fill_rect(Rect2i(plate.position + Vector2i(1, 2), plate.size), CAST_SHADOW)
		image.fill_rect(plate, OUTLINE)
		image.fill_rect(Rect2i(plate.position + Vector2i.ONE, plate.size - Vector2i.ONE * 2), IRON)
		image.set_pixel(anchor.x, anchor.y, IRON_LIGHT)
		# Raised arm: dark lower edge, iron body and a narrow upper highlight.
		_line(image, anchor + Vector2i.DOWN, socket + Vector2i.DOWN, OUTLINE)
		_line(image, anchor, socket, IRON)
		_line(image, anchor + Vector2i.UP, socket + Vector2i.UP, IRON_LIGHT)
		_brackets[direction] = ImageTexture.create_from_image(image)
	return _brackets[direction]


static func shadow_texture() -> ImageTexture:
	if _shadow == null:
		var image := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		var center: Vector2 = Vector2(SIZE) / 2.0
		for y in SIZE.y:
			for x in SIZE.x:
				var distance: float = ((Vector2(x, y) - center) / SHADOW_RADIUS).length()
				if distance < 1.0:
					var color: Color = CAST_SHADOW
					color.a *= 1.0 - distance * distance
					image.set_pixel(x, y, color)
		_shadow = ImageTexture.create_from_image(image)
	return _shadow


static func mount_offset(direction: Vector2i) -> Vector2i:
	return SOUTH_BODY_OFFSET if direction == Vector2i.DOWN else direction * PROJECTION_DISTANCE
