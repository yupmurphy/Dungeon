extends Node
## Bakes the young goblin's sprite sheet from the Universal LPC generator clone (kept outside the project):
## child body + "goblin child" head, recolored from the light skin palette to green, with a child shirt and
## pants. Writes assets/monsters/goblin/young_goblin.png in the MonsterSheet layout used by goblin.tres.
##   <godot.exe> --headless --path . -- --bake-goblin=D:/DungeonHunters/lpc-generator
## Output rows: down, left, up, right, then death. Columns: 0 idle, 1-8 walk, 9-14 attack (slash).
## The child clothes only exist for walking: attack frames wear the clothes of the standing frame.

const OUTPUT: String = "res://assets/monsters/goblin/young_goblin.png"
const FRAME: int = 64
## LPC sheets go up, left, down, right; the baked sheet goes down, left, up, right.
const SOURCE_ROWS: Array[int] = [2, 1, 0, 3]
const WALK_FRAMES: int = 9
const SLASH_FRAMES: int = 6
const HURT_FRAMES: int = 6
## Death frames that still wear clothes (the goblin is still upright).
const DRESSED_DEATH_FRAMES: int = 2
const COLUMNS: int = WALK_FRAMES + SLASH_FRAMES
## ULPC body palette "light" -> "green" (palette_definitions/body/body_ulpc.json in the clone).
const LIGHT_SKIN: Array[String] = ["#271920", "#99423c", "#cc8665", "#E4A47C", "#F9D5BA", "#FAECE7"]
const GREEN_SKIN: Array[String] = ["#140C09", "#09320B", "#19541D", "#228236", "#39AA4E", "#53BF71"]
const BODY: String = "/spritesheets/body/bodies/child/%s.png"
const HEAD: String = "/spritesheets/head/heads/goblin/child/%s.png"
const CLOTHES: Array[String] = ["/spritesheets/legs/pants/child/walk/brown.png",
	"/spritesheets/torso/clothes/shirt/child/walk/brown.png"]

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
	var walk: Image = _green(BODY % "walk")
	var slash: Image = _green(BODY % "slash")
	var hurt: Image = _green(BODY % "hurt")
	var walk_head: Image = _green(HEAD % "walk")
	var slash_head: Image = _green(HEAD % "slash")
	var hurt_head: Image = _green(HEAD % "hurt")
	var clothes: Image = _clothes()
	var sheet := Image.create(COLUMNS * FRAME, 5 * FRAME, false, Image.FORMAT_RGBA8)
	for row in SOURCE_ROWS.size():
		var source_row: int = SOURCE_ROWS[row]
		for column in WALK_FRAMES:
			_copy(sheet, walk, Vector2i(column, source_row), Vector2i(column, row))
			_copy(sheet, clothes, Vector2i(column, source_row), Vector2i(column, row))
			_copy(sheet, walk_head, Vector2i(column, source_row), Vector2i(column, row))
		for column in SLASH_FRAMES:
			var target := Vector2i(WALK_FRAMES + column, row)
			_copy(sheet, slash, Vector2i(column, source_row), target)
			_copy(sheet, clothes, Vector2i(0, source_row), target)
			_copy(sheet, slash_head, Vector2i(column, source_row), target)
	for column in HURT_FRAMES:
		_copy(sheet, hurt, Vector2i(column, 0), Vector2i(column, 4))
		if column < DRESSED_DEATH_FRAMES:
			_copy(sheet, clothes, Vector2i(0, SOURCE_ROWS[0]), Vector2i(column, 4))
		_copy(sheet, hurt_head, Vector2i(column, 0), Vector2i(column, 4))
	var error: Error = sheet.save_png(ProjectSettings.globalize_path(OUTPUT))
	print("Young goblin sheet: ", OUTPUT, " (", error, ")")
	get_tree().quit(0 if error == OK else 1)


## A body or head sheet with the light skin turned green.
func _green(path: String) -> Image:
	var body: Image = _load(path)
	for y in body.get_height():
		for x in body.get_width():
			var pixel: Color = body.get_pixel(x, y)
			var key: String = pixel.to_html(false)
			if pixel.a > 0.0 and _skin.has(key):
				body.set_pixel(x, y, _skin[key])
	return body


func _clothes() -> Image:
	var result: Image = _load(CLOTHES[0])
	for path in CLOTHES.slice(1):
		result.blend_rect(_load(path), Rect2i(Vector2i.ZERO, result.get_size()), Vector2i.ZERO)
	return result


func _load(path: String) -> Image:
	var image: Image = Image.load_from_file(_clone + path)
	image.convert(Image.FORMAT_RGBA8)
	return image


## Blends one frame of `source` (frame coordinates) onto `sheet`.
func _copy(sheet: Image, source: Image, from: Vector2i, to: Vector2i) -> void:
	sheet.blend_rect(source, Rect2i(from * FRAME, Vector2i(FRAME, FRAME)), to * FRAME)
