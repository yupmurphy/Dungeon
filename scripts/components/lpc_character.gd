class_name LpcCharacter
extends Node2D
## A 64 x 64 LPC character built from stacked layers (body, head, hair, clothes, helmet, weapon...), one
## AnimatedSprite2D per layer, sorted by the layer's z order. All layers show the same animation and the same
## frame, driven from here (so they never drift apart). Layers without the current animation hide.
## Actions: idle, walk, slash, thrust (4 directions); flinch (hit) and death use the LPC "hurt" sheet (the fall,
## one row): flinch shows only its first frames, death all of them.

signal action_finished(action: String)

## Frames per second of each action (walk is also scaled by movement speed).
const FPS: Dictionary = {"idle": 2.0, "walk": 10.0, "slash": 14.0, "thrust": 16.0, "flinch": 12.0, "death": 10.0}
## Actions drawn from another action's sheet.
const SHEET_OF: Dictionary = {"flinch": "hurt", "death": "hurt"}
## A flinch is the start of the fall: this many frames.
const FLINCH_FRAMES: int = 2
## Actions that repeat; the others play once and hold their last frame.
const LOOPING: Array[String] = ["idle", "walk"]
## LPC walk sheets: frame 0 is the standing pose, 1-8 the cycle.
const WALK_FIRST_FRAME: int = 1
## The frame's center is above the feet: lift the sprites so the node's origin sits at the feet.
const FEET_OFFSET: Vector2 = Vector2(0, -22)
## LPC art has 4 directions only. Diagonals (W+D, S+A...) use the side view, which reads best; up/down only
## when the movement is closer than this to vertical (1.0 would split exactly at 45 degrees).
const DIAGONAL_SIDE_BIAS: float = 0.5

@export var body_type: String = "male"
## Item ids from the LPC catalog (assets/lpc/catalog.json), one per slot.
@export var items: Array[String] = []
## Shared by every layer (hit flash shader).
@export var layer_material: Material

var action: String = "idle"
var direction: LpcCatalog.Direction = LpcCatalog.Direction.DOWN

var _layers: Array[AnimatedSprite2D] = []
var _time: float = 0.0
var _speed: float = 1.0
var _finished: bool = false
## >= 0: the action stops on this frame and stays busy until release() (the dash attack holds the thrust).
var _hold_frame: int = -1


func _ready() -> void:
	rebuild()


## (Re)creates the layer sprites from `items` and `body_type`.
func rebuild() -> void:
	for layer in _layers:
		layer.queue_free()
	_layers.clear()
	var stack: Array = []
	for id in items:
		for layer: Dictionary in LpcCatalog.item(id).get("layers", []):
			if layer["bodies"].has(body_type):
				stack.append([int(layer["z"]), layer])
	stack.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for entry: Array in stack:
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = LpcCatalog.layer_frames(entry[1], body_type)
		sprite.position = FEET_OFFSET
		sprite.material = layer_material
		add_child(sprite)
		_layers.append(sprite)
	_apply_frame()


func layers() -> Array[AnimatedSprite2D]:
	return _layers


## True if some layer has this action (e.g. a spear has "thrust" but no "slash").
func has_action(action_name: String) -> bool:
	var key := StringName(LpcCatalog.animation_key(SHEET_OF.get(action_name, action_name), LpcCatalog.Direction.DOWN))
	return _layers.any(func(layer: AnimatedSprite2D) -> bool: return layer.sprite_frames.has_animation(key))


## The attack the equipped weapon is drawn for: slash (sword, axe, dagger) or thrust (spear).
## No weapon = slash.
func attack_action() -> String:
	for id in items:
		var item: Dictionary = LpcCatalog.item(id)
		if item.get("slot", "") != "weapon":
			continue
		for preferred: String in ["slash", "thrust"]:
			for layer: Dictionary in item["layers"]:
				if layer["bodies"].get(body_type, {}).has(preferred):
					return preferred
	return "slash"


## Starts an action from its first frame. `duration` > 0 stretches a one-shot action to last that long.
## `hold_frame` >= 0: reach that frame in `duration`, then stay on it (busy) until release().
func play(new_action: String, new_direction: LpcCatalog.Direction, duration: float = 0.0, hold_frame: int = -1) -> void:
	action = new_action
	direction = new_direction
	_time = 0.0
	_finished = false
	_hold_frame = hold_frame
	_speed = 1.0
	if duration > 0.0:
		var frames: int = hold_frame + 1 if hold_frame >= 0 else _frame_count()
		_speed = frames / FPS.get(action, 10.0) / duration
	_apply_frame()


## Keeps a looping action going (walk/idle) without restarting it; `speed` scales the frame rate.
func loop(new_action: String, new_direction: LpcCatalog.Direction, speed: float = 1.0) -> void:
	if new_action != action:
		play(new_action, new_direction)
	direction = new_direction
	_speed = speed


func is_busy() -> bool:
	return action not in LOOPING and not _finished


func is_holding() -> bool:
	return _hold_frame >= 0


## Ends a held action: the next loop() takes over.
func release() -> void:
	if _hold_frame >= 0:
		_hold_frame = -1
		_finished = true


func _process(delta: float) -> void:
	_time += delta * _speed
	_apply_frame()


func _apply_frame() -> void:
	var key := StringName(LpcCatalog.animation_key(SHEET_OF.get(action, action), direction))
	var count: int = _frame_count()
	var frame: int = int(_time * FPS.get(action, 10.0))
	if action == "walk":
		frame = WALK_FIRST_FRAME + frame % maxi(count - WALK_FIRST_FRAME, 1)
	elif action in LOOPING:
		frame = frame % maxi(count, 1)
	elif _hold_frame >= 0:
		frame = mini(frame, mini(_hold_frame, count - 1))
	elif frame >= count:
		frame = count - 1
		if not _finished:
			_finished = true
			action_finished.emit(action)
	for layer in _layers:
		var has: bool = layer.sprite_frames.has_animation(key)
		layer.visible = has
		if has:
			layer.animation = key
			layer.frame = mini(frame, layer.sprite_frames.get_frame_count(key) - 1)


## Frames in the current animation (the body decides; all layers of an action have the same count).
func _frame_count() -> int:
	var key := StringName(LpcCatalog.animation_key(SHEET_OF.get(action, action), direction))
	for layer in _layers:
		if layer.sprite_frames.has_animation(key):
			var count: int = layer.sprite_frames.get_frame_count(key)
			return mini(count, FLINCH_FRAMES) if action == "flinch" else count
	return 1



## The LPC direction for a vector (screen y grows downwards).
static func direction_of(vector: Vector2) -> LpcCatalog.Direction:
	if absf(vector.x) >= absf(vector.y) * DIAGONAL_SIDE_BIAS:
		return LpcCatalog.Direction.RIGHT if vector.x > 0.0 else LpcCatalog.Direction.LEFT
	return LpcCatalog.Direction.DOWN if vector.y > 0.0 else LpcCatalog.Direction.UP
