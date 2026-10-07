class_name LpcCatalog
## The LPC pieces in assets/lpc/ (made by tools/lpc_import.gd): for each item its slot, name and layers;
## each layer has a z order and, per body type, one sheet per animation. Sheets are cut into SpriteFrames
## here: one row per direction (up, left, down, right), frames left to right; "hurt" has a single row.

enum Direction { UP, LEFT, DOWN, RIGHT }

const CATALOG_PATH: String = "res://assets/lpc/catalog.json"
const DIRECTION_NAMES: Array[String] = ["up", "left", "down", "right"]
## Animations with only one row (no directions).
const SINGLE_ROW: Array[String] = ["hurt"]

static var _items: Dictionary = {}
static var _frames: Dictionary = {}


static func items() -> Dictionary:
	if _items.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
		if parsed is Dictionary:
			_items = parsed
		else:
			push_error("LPC catalog missing or broken: " + CATALOG_PATH)
	return _items


static func has_item(id: String) -> bool:
	return items().has(id)


static func item(id: String) -> Dictionary:
	return items().get(id, {})


## Ids of every item for one slot ("hair", "weapon"...), sorted.
static func items_for_slot(slot: String) -> Array[String]:
	var ids: Array[String] = []
	for id: String in items():
		if items()[id]["slot"] == slot:
			ids.append(id)
	ids.sort()
	return ids


## Animation name inside the SpriteFrames: "walk_down", "slash_left", "hurt".
static func animation_key(action: String, direction: Direction) -> String:
	return action if action in SINGLE_ROW else "%s_%s" % [action, DIRECTION_NAMES[direction]]


## SpriteFrames for one layer of one item on one body type: every animation that layer has.
## Cached, so many characters wearing the same piece share the textures.
static func layer_frames(layer: Dictionary, body_type: String) -> SpriteFrames:
	var sheets: Dictionary = layer["bodies"].get(body_type, {})
	var key: String = JSON.stringify(sheets)
	if _frames.has(key):
		return _frames[key]
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for action: String in sheets:
		var sheet: Dictionary = sheets[action]
		var texture := load("res://assets/" + sheet["file"]) as Texture2D
		if texture == null:
			continue
		var size: int = int(sheet["frame"])
		var columns: int = texture.get_width() / size
		var rows: Array = [0] if action in SINGLE_ROW else range(4)
		for row: int in rows:
			var name := StringName(animation_key(action, row))
			frames.add_animation(name)
			frames.set_animation_loop(name, false)
			for column in columns:
				var atlas := AtlasTexture.new()
				atlas.atlas = texture
				atlas.region = Rect2(column * size, row * size, size, size)
				atlas.filter_clip = true
				frames.add_frame(name, atlas)
	_frames[key] = frames
	return frames
