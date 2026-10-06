class_name NatureArt
## Placeholder pixel art drawn in code: the nature tiles (grass, water, trees, sand...) as one atlas, and
## the props of every zone (tents, carts, crystals, palms, bones, nests...) as separate textures.
## Everything is 16 px per tile, like the Kenney pack, and built once per run. A real tileset can replace
## it later by swapping the textures (tile order: Terrain.ART; prop names: PROPS).

const TILE: int = 16
const ATLAS_COLUMNS: int = 16

## name -> {size: Vector2i pixels, footprint: Vector2i tiles that block, solid, light (Color or null)}
const PROPS: Dictionary = {
	"old_tree": {"size": Vector2i(32, 40), "footprint": Vector2i(2, 2), "solid": true},
	"dead_tree": {"size": Vector2i(16, 32), "footprint": Vector2i(1, 1), "solid": true},
	"palm": {"size": Vector2i(32, 40), "footprint": Vector2i(1, 1), "solid": true},
	"skull": {"size": Vector2i(32, 32), "footprint": Vector2i(2, 2), "solid": true},
	"ribs": {"size": Vector2i(48, 32), "footprint": Vector2i(3, 2), "solid": true},
	"bone": {"size": Vector2i(16, 16), "footprint": Vector2i(1, 1), "solid": false},
	"tent": {"size": Vector2i(32, 32), "footprint": Vector2i(2, 2), "solid": true},
	"campfire": {"size": Vector2i(16, 16), "footprint": Vector2i(1, 1), "solid": true, "light": Color(1.0, 0.55, 0.2)},
	"log_seat": {"size": Vector2i(16, 16), "footprint": Vector2i(1, 1), "solid": false},
	"cart": {"size": Vector2i(16, 16), "footprint": Vector2i(1, 1), "solid": true},
	"rails": {"size": Vector2i(16, 16), "footprint": Vector2i(1, 1), "solid": false},
	"crystal": {"size": Vector2i(16, 20), "footprint": Vector2i(1, 1), "solid": true, "light": Color(0.4, 0.8, 1.0)},
	"throne": {"size": Vector2i(32, 32), "footprint": Vector2i(2, 2), "solid": true},
	"banner": {"size": Vector2i(16, 32), "footprint": Vector2i(1, 1), "solid": true},
	"spider_nest": {"size": Vector2i(32, 32), "footprint": Vector2i(2, 2), "solid": true},
	"bush": {"size": Vector2i(16, 16), "footprint": Vector2i(1, 1), "solid": false},
	"mushroom": {"size": Vector2i(16, 16), "footprint": Vector2i(1, 1), "solid": false},
	"cactus": {"size": Vector2i(16, 24), "footprint": Vector2i(1, 1), "solid": true},
	"shrub": {"size": Vector2i(16, 16), "footprint": Vector2i(1, 1), "solid": false},
	"lily": {"size": Vector2i(16, 16), "footprint": Vector2i(1, 1), "solid": false},
	"boulder": {"size": Vector2i(16, 16), "footprint": Vector2i(1, 1), "solid": true},
	"fog": {"size": Vector2i(64, 40), "footprint": Vector2i(1, 1), "solid": false},
}

const OUTLINE: Color = Color(0.08, 0.06, 0.08)

static var _atlas: ImageTexture
static var _props: Dictionary = {}


## The nature tiles, ATLAS_COLUMNS per row, in Terrain.ART order.
static func atlas_texture() -> ImageTexture:
	if _atlas == null:
		_atlas = ImageTexture.create_from_image(_build_atlas())
	return _atlas


static func atlas_coords(tile: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(tile % ATLAS_COLUMNS, tile / ATLAS_COLUMNS)


static func prop_texture(prop_name: String) -> ImageTexture:
	if not _props.has(prop_name):
		_props[prop_name] = ImageTexture.create_from_image(_build_prop(prop_name))
	return _props[prop_name]


static func prop_info(prop_name: String) -> Dictionary:
	return PROPS[prop_name]


# --- Atlas ---

static func _build_atlas() -> Image:
	@warning_ignore("integer_division")
	var rows: int = (Terrain.ART_TILES + ATLAS_COLUMNS - 1) / ATLAS_COLUMNS
	var image := Image.create(ATLAS_COLUMNS * TILE, rows * TILE, false, Image.FORMAT_RGBA8)
	for type: int in Terrain.ART:
		var first: int = Terrain.ART[type][0]
		for variant in Terrain.ART[type][1]:
			var tile := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
			_draw_tile(tile, type, variant)
			var at: Vector2i = atlas_coords(first + variant) * TILE
			image.blit_rect(tile, Rect2i(0, 0, TILE, TILE), at)
	return image


static func _draw_tile(img: Image, type: int, v: int) -> void:
	var s: int = type * 31 + v * 7
	match type:
		Terrain.Type.GRASS:
			_speckle(img, Color(0.36, 0.6, 0.24), 0.08, s)
			_blades(img, Color(0.5, 0.75, 0.32), 5 + v * 2, s)
			if v == 3:
				_dots(img, [Color(1, 0.95, 0.5), Color(1, 1, 1)], 3, s)
		Terrain.Type.FOREST_FLOOR:
			_speckle(img, Color(0.24, 0.36, 0.17), 0.1, s)
			_dots(img, [Color(0.45, 0.32, 0.15), Color(0.55, 0.4, 0.16)], 4 + v, s)
			if v == 2:
				_line(img, Vector2i(3, 11), Vector2i(10, 8), Color(0.4, 0.27, 0.14))
		Terrain.Type.TREE:
			_speckle(img, Color(0.2, 0.3, 0.14), 0.08, s)
			var crown: Color = [Color(0.16, 0.42, 0.16), Color(0.13, 0.36, 0.17), Color(0.2, 0.46, 0.14),
				Color(0.1, 0.3, 0.16)][v]
			_disc(img, Vector2(8, 9.5), 6.0, Color(0.08, 0.16, 0.07, 0.8))  # shadow
			_disc(img, Vector2(7.5, 7.5), 7.0, crown.darkened(0.35))
			_disc(img, Vector2(7.5, 7.0), 6.0, crown)
			_disc(img, Vector2(5.5, 5.0), 2.5, crown.lightened(0.25))
			_dots(img, [crown.darkened(0.2)], 6, s, Rect2i(3, 3, 10, 10))
		Terrain.Type.WATER_SHALLOW:
			_speckle(img, Color(0.32, 0.58, 0.78), 0.04, s)
			_waves(img, Color(0.55, 0.78, 0.92), 2, s)
		Terrain.Type.WATER_DEEP:
			_speckle(img, Color(0.11, 0.24, 0.52), 0.04, s)
			_waves(img, Color(0.22, 0.4, 0.7), 1 + v % 2, s)
		Terrain.Type.BRIDGE:
			img.fill(Color(0.55, 0.37, 0.19))
			for y in range(0, TILE, 4):
				for x in TILE:
					img.set_pixel(x, y, Color(0.3, 0.19, 0.09))
				img.set_pixel(2 + (y + v * 5) % 11, y + 2, Color(0.25, 0.2, 0.18))
			_speckle_over(img, 0.06, s)
		Terrain.Type.MUD:
			_speckle(img, Color(0.33, 0.32, 0.2), 0.1, s)
			_dots(img, [Color(0.25, 0.24, 0.15), Color(0.38, 0.45, 0.22)], 6 + v * 2, s)
			if v == 2:
				_disc(img, Vector2(9, 9), 2.5, Color(0.25, 0.3, 0.25))
		Terrain.Type.REEDS:
			_speckle(img, Color(0.3, 0.52, 0.62), 0.05, s)
			var rng := _rng(s)
			for i in 5 + v:
				var x: int = rng.randi_range(1, 14)
				var top: int = rng.randi_range(1, 6)
				_line(img, Vector2i(x, 15), Vector2i(x, top), Color(0.32, 0.5, 0.18))
				img.set_pixel(x, top, Color(0.45, 0.28, 0.12))
				img.set_pixel(x, top + 1, Color(0.45, 0.28, 0.12))
		Terrain.Type.SAND:
			_speckle(img, Color(0.88, 0.76, 0.48), 0.06, s)
			if v == 1:
				_dots(img, [Color(0.65, 0.55, 0.42)], 4, s)
			elif v >= 2:
				_line(img, Vector2i(2, 5 + v), Vector2i(12, 4 + v), Color(0.8, 0.67, 0.4))
		Terrain.Type.DUNE:
			_speckle(img, Color(0.82, 0.68, 0.4), 0.05, s)
			for x in TILE:
				var y: int = 6 + int(round(sin((x + v * 5) * 0.4) * 2.0))
				img.set_pixel(x, y, Color(0.97, 0.88, 0.62))
				img.set_pixel(x, y + 1, Color(0.68, 0.53, 0.3))
		Terrain.Type.QUICKSAND:
			_speckle(img, Color(0.66, 0.52, 0.28), 0.05, s)
			for r: float in [2.5, 5.0, 7.5]:
				_ring(img, Vector2(7.5 + v, 7.5), r, Color(0.5, 0.38, 0.2))
		Terrain.Type.OASIS_GRASS:
			_speckle(img, Color(0.38, 0.68, 0.3), 0.08, s)
			_blades(img, Color(0.55, 0.85, 0.4), 7, s)
		Terrain.Type.WEB:
			_speckle(img, Color(0.24, 0.34, 0.18), 0.08, s)
			var web := Color(0.92, 0.92, 0.96, 0.85)
			var c := Vector2i(7 + v, 8)
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(15, 0), Vector2i(0, 15), Vector2i(15, 15)]:
				_line(img, c, corner, web)
			_ring(img, Vector2(c), 3.5, web)
			_ring(img, Vector2(c), 6.5, web)


# --- Props ---

static func _build_prop(prop_name: String) -> Image:
	var size: Vector2i = PROPS[prop_name]["size"]
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var w: float = size.x
	var h: float = size.y
	match prop_name:
		"old_tree":
			_rect(img, Rect2i(13, 26, 6, 13), Color(0.36, 0.22, 0.12))
			_rect(img, Rect2i(11, 36, 10, 3), Color(0.3, 0.18, 0.1))
			_disc(img, Vector2(16, 15), 14.0, Color(0.12, 0.32, 0.12))
			_disc(img, Vector2(9, 18), 7.0, Color(0.15, 0.38, 0.14))
			_disc(img, Vector2(23, 18), 7.0, Color(0.14, 0.36, 0.14))
			_disc(img, Vector2(16, 12), 10.0, Color(0.18, 0.44, 0.16))
			_disc(img, Vector2(12, 8), 4.0, Color(0.3, 0.58, 0.24))
			_dots(img, [Color(0.1, 0.28, 0.1)], 30, 11, Rect2i(4, 3, 24, 22), true)
		"dead_tree":
			var bark := Color(0.38, 0.33, 0.28)
			_rect(img, Rect2i(7, 10, 3, 22), bark)
			_line(img, Vector2i(8, 14), Vector2i(2, 6), bark)
			_line(img, Vector2i(8, 12), Vector2i(14, 3), bark)
			_line(img, Vector2i(9, 20), Vector2i(13, 15), bark)
			_line(img, Vector2i(3, 7), Vector2i(1, 2), bark)
		"palm":
			for i in 22:
				var x: int = 14 + int(round(sin(i * 0.12) * 3.0))
				_rect(img, Rect2i(x, 39 - i, 3, 1), Color(0.5, 0.36, 0.2) if i % 3 else Color(0.38, 0.26, 0.14))
			var top := Vector2i(16, 16)
			for end: Vector2i in [Vector2i(2, 14), Vector2i(30, 13), Vector2i(6, 4), Vector2i(26, 3),
					Vector2i(16, 1), Vector2i(4, 22), Vector2i(28, 22)]:
				_thick_line(img, top, end, Color(0.22, 0.55, 0.2))
			_disc(img, Vector2(16, 17), 2.0, Color(0.45, 0.3, 0.12))
		"skull":
			var bone := Color(0.9, 0.86, 0.74)
			_disc(img, Vector2(16, 13), 12.0, bone)
			_rect(img, Rect2i(9, 20, 14, 9), bone)
			_disc(img, Vector2(11, 14), 3.5, Color(0.15, 0.1, 0.1))
			_disc(img, Vector2(21, 14), 3.5, Color(0.15, 0.1, 0.1))
			_rect(img, Rect2i(15, 19, 2, 3), Color(0.2, 0.14, 0.12))
			for x in range(10, 23, 3):
				_rect(img, Rect2i(x, 25, 1, 4), Color(0.45, 0.4, 0.35))
		"ribs":
			var bone := Color(0.9, 0.86, 0.74)
			_rect(img, Rect2i(2, 26, 44, 4), bone)
			for i in 6:
				var x: int = 5 + i * 7
				for y in range(4, 27):
					var bend: int = int(round(sin(float(y - 4) / 22.0 * PI) * 3.0))
					_rect(img, Rect2i(x + bend, y, 2, 1), bone)
		"bone":
			var bone := Color(0.88, 0.84, 0.74)
			_thick_line(img, Vector2i(4, 11), Vector2i(12, 5), bone)
			_disc(img, Vector2(3.5, 11.5), 1.8, bone)
			_disc(img, Vector2(12.5, 4.5), 1.8, bone)
		"tent":
			var cloth := Color(0.6, 0.32, 0.22)
			for y in range(4, 30):
				var half_width: int = int((y - 4) * 0.55)
				_rect(img, Rect2i(16 - half_width, y, half_width * 2 + 1, 1), cloth if y % 6 else cloth.darkened(0.2))
			for y in range(18, 30):
				var half_width: int = int((y - 18) * 0.3)
				_rect(img, Rect2i(16 - half_width, y, half_width * 2 + 1, 1), Color(0.12, 0.08, 0.06))
			_line(img, Vector2i(16, 1), Vector2i(16, 5), Color(0.35, 0.25, 0.15))
		"campfire":
			_thick_line(img, Vector2i(2, 13), Vector2i(13, 10), Color(0.4, 0.25, 0.12))
			_thick_line(img, Vector2i(3, 10), Vector2i(14, 13), Color(0.35, 0.22, 0.1))
			_disc(img, Vector2(8, 8), 4.5, Color(1.0, 0.45, 0.1))
			_disc(img, Vector2(8, 9), 2.5, Color(1.0, 0.85, 0.3))
			img.set_pixel(8, 2, Color(1.0, 0.6, 0.2))
			img.set_pixel(7, 3, Color(1.0, 0.6, 0.2))
		"log_seat":
			_rect(img, Rect2i(1, 8, 14, 5), Color(0.45, 0.3, 0.15))
			_disc(img, Vector2(14, 10.5), 2.5, Color(0.7, 0.55, 0.32))
		"cart":
			_rect(img, Rect2i(2, 5, 12, 7), Color(0.45, 0.45, 0.5))
			_rect(img, Rect2i(3, 3, 10, 3), Color(0.35, 0.3, 0.32))
			_dots(img, [Color(0.55, 0.85, 1.0), Color(0.9, 0.75, 0.3)], 5, 5, Rect2i(3, 2, 10, 3))
			_disc(img, Vector2(4.5, 13), 2.0, Color(0.2, 0.2, 0.22))
			_disc(img, Vector2(11.5, 13), 2.0, Color(0.2, 0.2, 0.22))
		"rails":
			for x in range(1, 16, 4):
				_rect(img, Rect2i(x, 3, 2, 10), Color(0.4, 0.28, 0.15))
			_rect(img, Rect2i(0, 5, 16, 1), Color(0.55, 0.55, 0.6))
			_rect(img, Rect2i(0, 10, 16, 1), Color(0.55, 0.55, 0.6))
			return img
		"crystal":
			for spike: Array in [[Vector2i(8, 1), 3], [Vector2i(4, 7), 2], [Vector2i(12, 6), 2]]:
				var tip: Vector2i = spike[0]
				var half_width: int = spike[1]
				for y in range(tip.y, 19):
					var width: int = mini(half_width, (y - tip.y) / 2 + 1)
					_rect(img, Rect2i(tip.x - width, y, width * 2, 1), Color(0.45, 0.85, 1.0) if (y + tip.x) % 4 else Color(0.8, 0.97, 1.0))
		"throne":
			var wood := Color(0.42, 0.26, 0.14)
			_rect(img, Rect2i(6, 2, 20, 18), wood)
			_rect(img, Rect2i(3, 16, 26, 14), wood.darkened(0.15))
			_rect(img, Rect2i(9, 17, 14, 6), Color(0.6, 0.15, 0.15))
			for x: int in [6, 15, 24]:
				_disc(img, Vector2(x + 1, 3), 3.0, Color(0.9, 0.86, 0.74))
		"banner":
			_rect(img, Rect2i(7, 1, 2, 31), Color(0.35, 0.25, 0.15))
			_rect(img, Rect2i(9, 3, 6, 14), Color(0.6, 0.12, 0.12))
			_rect(img, Rect2i(10, 7, 3, 3), Color(0.9, 0.85, 0.7))
		"spider_nest":
			var silk := Color(0.88, 0.88, 0.92)
			_disc(img, Vector2(16, 18), 13.0, silk.darkened(0.15))
			_disc(img, Vector2(15, 16), 10.0, silk)
			for egg: Vector2 in [Vector2(10, 18), Vector2(18, 13), Vector2(21, 21), Vector2(14, 24)]:
				_disc(img, egg, 2.5, Color(0.8, 0.82, 0.6))
			for corner: Vector2i in [Vector2i(0, 4), Vector2i(31, 3), Vector2i(1, 31), Vector2i(31, 30)]:
				_line(img, Vector2i(16, 17), corner, Color(1, 1, 1, 0.8))
		"bush":
			_disc(img, Vector2(8, 9), 6.0, Color(0.2, 0.45, 0.18))
			_disc(img, Vector2(6, 7), 2.5, Color(0.32, 0.58, 0.26))
			_dots(img, [Color(0.8, 0.2, 0.25)], 3, 3, Rect2i(4, 5, 8, 8))
		"mushroom":
			_rect(img, Rect2i(7, 8, 2, 6), Color(0.9, 0.86, 0.75))
			_disc(img, Vector2(8, 7), 4.5, Color(0.75, 0.2, 0.15))
			img.set_pixel(6, 5, Color.WHITE)
			img.set_pixel(10, 6, Color.WHITE)
		"cactus":
			var green := Color(0.3, 0.55, 0.25)
			_rect(img, Rect2i(6, 3, 4, 21), green)
			_rect(img, Rect2i(2, 8, 3, 7), green)
			_rect(img, Rect2i(2, 14, 5, 2), green)
			_rect(img, Rect2i(11, 6, 3, 8), green)
			_rect(img, Rect2i(9, 12, 4, 2), green)
		"shrub":
			for end: Vector2i in [Vector2i(2, 4), Vector2i(8, 1), Vector2i(14, 5), Vector2i(4, 9), Vector2i(12, 9)]:
				_line(img, Vector2i(8, 14), end, Color(0.5, 0.42, 0.25))
		"lily":
			_disc(img, Vector2(7, 8), 4.5, Color(0.25, 0.55, 0.25))
			_line(img, Vector2i(7, 8), Vector2i(11, 6), Color(0.32, 0.58, 0.78))
			img.set_pixel(6, 6, Color(1, 0.8, 0.9))
			return img
		"boulder":
			_disc(img, Vector2(8, 9.5), 6.5, Color(0.45, 0.43, 0.42))
			_disc(img, Vector2(6.5, 7.5), 2.5, Color(0.6, 0.58, 0.56))
		"fog":
			for y in size.y:
				for x in size.x:
					var d: float = Vector2((x - w / 2.0) / (w / 2.0), (y - h / 2.0) / (h / 2.0)).length()
					var a: float = clampf(1.0 - d, 0.0, 1.0)
					a *= 0.5 + _hash(x / 6, y / 6, 77) * 0.5
					img.set_pixel(x, y, Color(0.85, 0.9, 0.85, a * a * 0.55))
			return img
	_outline(img)
	return img


# --- Drawing helpers ---

static func _hash(x: int, y: int, s: int) -> float:
	return float(posmod(hash(Vector3i(x, y, s)), 10007)) / 10007.0


static func _rng(s: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	return rng


static func _speckle(img: Image, base: Color, amount: float, s: int) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var d: float = (_hash(x, y, s) - 0.5) * 2.0 * amount
			img.set_pixel(x, y, Color(base.r + d, base.g + d, base.b + d * 0.6))


static func _speckle_over(img: Image, amount: float, s: int) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var d: float = (_hash(x, y, s) - 0.5) * 2.0 * amount
			var c: Color = img.get_pixel(x, y)
			img.set_pixel(x, y, Color(c.r + d, c.g + d, c.b + d, c.a))


static func _blades(img: Image, color: Color, count: int, s: int) -> void:
	var rng := _rng(s)
	for i in count:
		var x: int = rng.randi_range(0, 15)
		var y: int = rng.randi_range(2, 15)
		img.set_pixel(x, y, color)
		img.set_pixel(x, y - 1, color.lightened(0.15))


static func _dots(img: Image, colors: Array, count: int, s: int, area: Rect2i = Rect2i(0, 0, 16, 16),
		only_opaque: bool = false) -> void:
	var rng := _rng(s + 1)
	for i in count:
		var x: int = rng.randi_range(area.position.x, area.end.x - 1)
		var y: int = rng.randi_range(area.position.y, area.end.y - 1)
		if only_opaque and img.get_pixel(x, y).a < 0.5:
			continue
		img.set_pixel(x, y, colors[i % colors.size()])


static func _waves(img: Image, color: Color, count: int, s: int) -> void:
	var rng := _rng(s + 2)
	for i in count:
		var x: int = rng.randi_range(1, 8)
		var y: int = rng.randi_range(2, 13)
		for k in 5:
			img.set_pixel(x + k, y + (1 if k == 2 else 0) - 1 + (1 if k != 2 else 0), color)


static func _disc(img: Image, center: Vector2, radius: float, color: Color) -> void:
	for y in range(floori(center.y - radius), ceili(center.y + radius) + 1):
		for x in range(floori(center.x - radius), ceili(center.x + radius) + 1):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() \
					and Vector2(x + 0.5, y + 0.5).distance_to(center + Vector2(0.5, 0.5)) <= radius:
				img.set_pixel(x, y, color)


static func _ring(img: Image, center: Vector2, radius: float, color: Color) -> void:
	for i in 48:
		var p: Vector2 = center + Vector2.from_angle(TAU * i / 48.0) * radius
		var x: int = roundi(p.x)
		var y: int = roundi(p.y)
		if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
			img.set_pixel(x, y, color)


static func _rect(img: Image, rect: Rect2i, color: Color) -> void:
	var clipped: Rect2i = rect.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if clipped.has_area():
		img.fill_rect(clipped, color)


static func _line(img: Image, from: Vector2i, to: Vector2i, color: Color) -> void:
	var steps: int = maxi(absi(to.x - from.x), absi(to.y - from.y))
	for i in steps + 1:
		var p: Vector2 = Vector2(from).lerp(Vector2(to), float(i) / maxf(steps, 1))
		var x: int = roundi(p.x)
		var y: int = roundi(p.y)
		if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
			img.set_pixel(x, y, color)


static func _thick_line(img: Image, from: Vector2i, to: Vector2i, color: Color) -> void:
	_line(img, from, to, color)
	_line(img, from + Vector2i(0, 1), to + Vector2i(0, 1), color.darkened(0.2))


## Dark 1 px outline around the opaque shape (pixel-art look like the Kenney sprites).
static func _outline(img: Image) -> void:
	var source: Image = img.duplicate()
	for y in img.get_height():
		for x in img.get_width():
			if source.get_pixel(x, y).a > 0.5:
				continue
			for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + offset
				if n.x >= 0 and n.y >= 0 and n.x < img.get_width() and n.y < img.get_height() \
						and source.get_pixel(n.x, n.y).a > 0.5:
					img.set_pixel(x, y, OUTLINE)
					break
