extends Node
## Bakes the young goblins' sprite sheets from the Universal LPC generator clone (kept outside the project):
## child body + child head with long pointed ears (a simple, young face), recolored from the light skin palette
## to green, with a child shirt and pants.
##   <godot.exe> --headless --path . -- --bake-goblin=D:/DungeonHunters/lpc-generator
## Writes (assets/monsters/goblin/):
##   young_goblin.png  - with a knife (LPC dagger), the Galleries goblin
##   goblin_archer.png - with a bow (LPC normal bow), the Forest goblin
##   arrow.png         - the archer's arrow, pointing right
## Output rows: down, left, up, right, then death. Columns: 0 idle, 1-8 walk, 9-14 attack.
## The child clothes only exist for walking: attack frames wear the clothes of the standing frame.
## LPC weapons are drawn for adult bodies: _fit() moves each weapon frame toward the feet so it lands in the
## smaller child's hand. The child body has no bow animation either: the archer stands still and only its front
## arm (taken from the adult shoot animation, side views) and the bow move.

const FOLDER: String = "res://assets/monsters/goblin/"
const FRAME: int = 64
## LPC sheets go up, left, down, right; the baked sheet goes down, left, up, right.
const SOURCE_ROWS: Array[int] = [2, 1, 0, 3]
const WALK_FRAMES: int = 9
const ATTACK_FRAMES: int = 6
const HURT_FRAMES: int = 6
## Death frames that still wear clothes and hold the weapon (the goblin is still upright).
const DRESSED_DEATH_FRAMES: int = 2
const COLUMNS: int = WALK_FRAMES + ATTACK_FRAMES
## Child body size / adult body size, and the point both stand on (frame pixels).
const CHILD_SCALE: float = 0.8
const FEET: Vector2 = Vector2(32, 62)
## Adult shoot animation columns used for the attack: nock, draw, aim, release (6 frames).
const SHOOT_FIRST: int = 4
## Front arm of the adult archer: pixels outside the standing body, above this line, on the facing side.
const ARM_BOTTOM: int = 50
const ARM_FRONT_LEFT: int = 30
const ARM_FRONT_RIGHT: int = 33
## Adult shoot frame (right-facing row) where the drawn arrow is cut from.
const ARROW_FRAME: Vector2i = Vector2i(6, 3)
## ULPC body palette "light" -> "green" (palette_definitions/body/body_ulpc.json in the clone).
const LIGHT_SKIN: Array[String] = ["#271920", "#99423c", "#cc8665", "#E4A47C", "#F9D5BA", "#FAECE7"]
const GREEN_SKIN: Array[String] = ["#140C09", "#09320B", "#19541D", "#228236", "#39AA4E", "#53BF71"]
const BODY: String = "/spritesheets/body/bodies/child/%s.png"
const ADULT_BODY: String = "/spritesheets/body/bodies/male/%s.png"
const HEAD: String = "/spritesheets/head/heads/human/child/%s.png"
const EARS: String = "/spritesheets/head/ears/long/child/%s.png"
const CLOTHES: Array[String] = ["/spritesheets/legs/pants/child/walk/brown.png",
	"/spritesheets/torso/clothes/shirt/child/walk/brown.png"]
const DAGGER: String = "/spritesheets/weapon/sword/dagger/%s/dagger.png"
const DAGGER_BEHIND: String = "/spritesheets/weapon/sword/dagger/behind/%s/dagger.png"
const BOW_WALK: String = "/spritesheets/weapon/ranged/bow/normal/walk/%s/normal.png"
const BOW_SHOOT: String = "/spritesheets/weapon/ranged/bow/normal/universal/%s/shoot/normal.png"
const ARROW: String = "/spritesheets/weapon/ranged/bow/arrow/shoot/arrow.png"

var _clone: String
var _skin: Dictionary = {}


func run(options: Dictionary) -> void:
	_clone = String(options.get("--bake-goblin", "")).trim_suffix("/")
	if not DirAccess.dir_exists_absolute(_clone + "/spritesheets"):
		push_error("Give the LPC generator clone: --bake-goblin=<folder>")
		get_tree().quit(1)
		return
	for i in LIGHT_SKIN.size():
		_skin[Color.html(LIGHT_SKIN[i]).to_html(false)] = Color.html(GREEN_SKIN[i])
	var ok: bool = _save(_knife_goblin(), "young_goblin.png")
	ok = _save(_archer(), "goblin_archer.png") and ok
	ok = _save(_arrow(), "arrow.png") and ok
	get_tree().quit(0 if ok else 1)


## Walk with the knife in hand, slash with it.
func _knife_goblin() -> Image:
	var walk: Array[Image] = _fit([_load(DAGGER_BEHIND % "walk"), _load(DAGGER % "walk")])
	var slash: Array[Image] = _fit([_load(DAGGER_BEHIND % "slash"), _load(DAGGER % "slash")])
	var hurt: Array[Image] = _fit([_load(DAGGER % "hurt")])
	var body: Dictionary = _body_parts()
	var sheet: Image = _new_sheet()
	for row in SOURCE_ROWS.size():
		var source_row: int = SOURCE_ROWS[row]
		for column in WALK_FRAMES:
			var from := Vector2i(column, source_row)
			var to := Vector2i(column, row)
			_copy(sheet, walk[0], from, to)
			_dress(sheet, body, "walk", from, from, to)
			_copy(sheet, walk[1], from, to)
		for column in ATTACK_FRAMES:
			var from := Vector2i(column, source_row)
			var to := Vector2i(WALK_FRAMES + column, row)
			_copy(sheet, slash[0], from, to)
			_dress(sheet, body, "slash", from, Vector2i(0, source_row), to)
			_copy(sheet, slash[1], from, to)
	_death_row(sheet, body, hurt[0])
	return sheet


## Walk with the bow, stand still and shoot (front arm + bow from the adult shoot animation).
func _archer() -> Image:
	var walk: Array[Image] = _fit([_from_128(_load(BOW_WALK % "background")),
		_from_128(_load(BOW_WALK % "foreground"))])
	var arms: Image = _front_arms()
	var shoot: Array[Image] = _fit([_load(BOW_SHOOT % "background"), arms, _load(BOW_SHOOT % "foreground"),
		_load(ARROW)])
	var body: Dictionary = _body_parts()
	var sheet: Image = _new_sheet()
	for row in SOURCE_ROWS.size():
		var source_row: int = SOURCE_ROWS[row]
		for column in WALK_FRAMES:
			var from := Vector2i(column, source_row)
			var to := Vector2i(column, row)
			_copy(sheet, walk[0], from, to)
			_dress(sheet, body, "walk", from, from, to)
			_copy(sheet, walk[1], from, to)
		var standing := Vector2i(0, source_row)
		for column in ATTACK_FRAMES:
			var from := Vector2i(SHOOT_FIRST + column, source_row)
			var to := Vector2i(WALK_FRAMES + column, row)
			_copy(sheet, shoot[0], from, to)
			_dress(sheet, body, "walk", standing, standing, to)
			for layer in shoot.slice(1):
				_copy(sheet, layer, from, to)
	_death_row(sheet, body, null)
	return sheet


## The drawn arrow of the adult shoot animation, cropped.
func _arrow() -> Image:
	var arrows: Image = _load(ARROW)
	var frame: Image = arrows.get_region(Rect2i(ARROW_FRAME * FRAME, Vector2i(FRAME, FRAME)))
	return frame.get_region(frame.get_used_rect())


## The bow walk sheets have 128 px frames (the 64 px character in the middle) and no standing frame:
## cut back to 64 px frames, walk frame n from column n - 1, standing = first walk frame.
func _from_128(image: Image) -> Image:
	var big: int = FRAME * 2
	var result := Image.create(WALK_FRAMES * FRAME, 4 * FRAME, false, Image.FORMAT_RGBA8)
	for row in 4:
		for column in WALK_FRAMES:
			var from := Vector2i(maxi(column - 1, 0) * big, row * big) + Vector2i(FRAME, FRAME) / 2
			result.blit_rect(image, Rect2i(from, Vector2i(FRAME, FRAME)), Vector2i(column, row) * FRAME)
	return result


## Body, clothes and head sheets per animation (green).
func _body_parts() -> Dictionary:
	var parts: Dictionary = {"clothes": _clothes()}
	for animation in ["walk", "slash", "hurt"]:
		parts["body_" + animation] = _green(_load(BODY % animation))
		parts["head_" + animation] = _head(animation)
	return parts


## Body, clothes (always from the walk sheet, frame `clothes_from`) and head of one frame.
func _dress(sheet: Image, parts: Dictionary, animation: String, from: Vector2i, clothes_from: Vector2i,
		to: Vector2i) -> void:
	_copy(sheet, parts["body_" + animation], from, to)
	_copy(sheet, parts["clothes"], clothes_from, to)
	_copy(sheet, parts["head_" + animation], from, to)


## Hurt animation (one row) as the death row; the weapon (if any) stays in hand while still upright.
func _death_row(sheet: Image, parts: Dictionary, weapon: Image) -> void:
	for column in HURT_FRAMES:
		var from := Vector2i(column, 0)
		var to := Vector2i(column, 4)
		_copy(sheet, parts["body_hurt"], from, to)
		if column < DRESSED_DEATH_FRAMES:
			_copy(sheet, parts["clothes"], Vector2i(0, SOURCE_ROWS[0]), to)
		_copy(sheet, parts["head_hurt"], from, to)
		if weapon != null and column < DRESSED_DEATH_FRAMES:
			_copy(sheet, weapon, from, to)


## The adult archer's front arm in the side views (green), on an otherwise empty shoot-sized sheet.
func _front_arms() -> Image:
	var shoot: Image = _green(_load(ADULT_BODY % "shoot"))
	var standing: Image = _load(ADULT_BODY % "walk")
	var arms := Image.create(shoot.get_width(), shoot.get_height(), false, Image.FORMAT_RGBA8)
	for row in [1, 3]:
		for column in shoot.get_width() / FRAME:
			for y in ARM_BOTTOM:
				for x in FRAME:
					var front: bool = x < ARM_FRONT_LEFT if row == 1 else x > ARM_FRONT_RIGHT
					var pixel: Color = shoot.get_pixel(column * FRAME + x, row * FRAME + y)
					if front and pixel.a > 0.0 and standing.get_pixel(x, row * FRAME + y).a == 0.0:
						arms.set_pixel(column * FRAME + x, row * FRAME + y, pixel)
	return arms


## Moves adult weapon frames into the child's hands: every frame is shifted so its center gets CHILD_SCALE times
## closer to the feet. Layers of one weapon move together (the shift comes from all of them).
func _fit(layers: Array[Image]) -> Array[Image]:
	var result: Array[Image] = []
	for layer in layers:
		result.append(Image.create(layer.get_width(), layer.get_height(), false, Image.FORMAT_RGBA8))
	var size: Vector2i = layers[0].get_size()
	for row in size.y / FRAME:
		for column in size.x / FRAME:
			var corner := Vector2i(column, row) * FRAME
			var sum := Vector2.ZERO
			var count: int = 0
			for layer in layers:
				for y in FRAME:
					for x in FRAME:
						if layer.get_pixel(corner.x + x, corner.y + y).a > 0.5:
							sum += Vector2(x, y)
							count += 1
			if count == 0:
				continue
			var center: Vector2 = sum / count
			var shift := Vector2i((FEET + (center - FEET) * CHILD_SCALE - center).round())
			for i in layers.size():
				result[i].blend_rect(layers[i], Rect2i(corner, Vector2i(FRAME, FRAME)), corner + shift)
	return result


## A sheet with the light skin turned green.
func _green(image: Image) -> Image:
	for y in image.get_height():
		for x in image.get_width():
			var pixel: Color = image.get_pixel(x, y)
			var key: String = pixel.to_html(false)
			if pixel.a > 0.0 and _skin.has(key):
				image.set_pixel(x, y, _skin[key])
	return image


## Head with the ears on top, green.
func _head(animation: String) -> Image:
	var head: Image = _green(_load(HEAD % animation))
	head.blend_rect(_green(_load(EARS % animation)), Rect2i(Vector2i.ZERO, head.get_size()), Vector2i.ZERO)
	return head


func _clothes() -> Image:
	var result: Image = _load(CLOTHES[0])
	for path in CLOTHES.slice(1):
		result.blend_rect(_load(path), Rect2i(Vector2i.ZERO, result.get_size()), Vector2i.ZERO)
	return result


func _new_sheet() -> Image:
	return Image.create(COLUMNS * FRAME, 5 * FRAME, false, Image.FORMAT_RGBA8)


func _load(path: String) -> Image:
	var image: Image = Image.load_from_file(_clone + path)
	image.convert(Image.FORMAT_RGBA8)
	return image


func _save(image: Image, file: String) -> bool:
	var error: Error = image.save_png(ProjectSettings.globalize_path(FOLDER + file))
	print("Goblin sheet: ", FOLDER + file, " (", error, ")")
	return error == OK


## Blends one frame of `source` (frame coordinates) onto `sheet`.
func _copy(sheet: Image, source: Image, from: Vector2i, to: Vector2i) -> void:
	sheet.blend_rect(source, Rect2i(from * FRAME, Vector2i(FRAME, FRAME)), to * FRAME)
