class_name MonsterSheet
extends RefCounted
## Cuts a monster sprite sheet with one row per facing (LPC style) into SpriteFrames:
## idle_<dir>, run_<dir>, attack_<dir> for every direction, and death. Frames are taken as they are
## (no scaling: LPC monsters are drawn at their real size). Built once per sheet and cached.

const DIRECTIONS: Array[StringName] = [&"down", &"left", &"up", &"right"]
const RUN_FPS: float = 10.0
const ATTACK_FPS: float = 8.0
const DEATH_FPS: float = 8.0

static var _cache: Dictionary = {}


## `layout` comes from MonsterData: row of each direction, columns of idle / run / attack, death row + count.
static func frames(data: MonsterData) -> SpriteFrames:
	var key: String = "%s|%s" % [data.sprite_sheet.resource_path, data.sheet_frame_size]
	if _cache.has(key):
		return _cache[key]
	var result := SpriteFrames.new()
	result.remove_animation(&"default")
	for d in DIRECTIONS.size():
		var row: int = data.sheet_direction_rows[d]
		_add(result, StringName("idle_%s" % DIRECTIONS[d]), data, row, data.sheet_idle_column, 1, 1.0, true)
		_add(result, StringName("run_%s" % DIRECTIONS[d]), data, row, data.sheet_run_columns.x,
			data.sheet_run_columns.y, RUN_FPS, true)
		_add(result, StringName("attack_%s" % DIRECTIONS[d]), data, row, data.sheet_attack_columns.x,
			data.sheet_attack_columns.y, ATTACK_FPS, false)
	_add(result, &"death", data, data.sheet_death_row, 0, data.sheet_death_frames, DEATH_FPS, false)
	_cache[key] = result
	return result


static func _add(target: SpriteFrames, animation: StringName, data: MonsterData, row: int, first_column: int,
		count: int, fps: float, loop: bool) -> void:
	target.add_animation(animation)
	target.set_animation_speed(animation, fps)
	target.set_animation_loop(animation, loop)
	var size: Vector2i = data.sheet_frame_size
	for i in count:
		var frame := AtlasTexture.new()
		frame.atlas = data.sprite_sheet
		frame.region = Rect2(Vector2((first_column + i) * size.x, row * size.y), Vector2(size))
		frame.filter_clip = true
		target.add_frame(animation, frame)
