class_name LpcCharacter
extends Node2D
## A 64 x 64 LPC character built from stacked layers (body, head, hair, clothes, helmet, weapon...), one
## AnimatedSprite2D per layer, sorted by the layer's z order. All layers show the same animation and the same
## frame, driven from here (so they never drift apart). Layers without the current animation hide.
## Actions: idle, walk, slash, thrust (4 directions) and hurt (falls down, one row).

signal action_finished(action: String)

## Frames per second of each action (walk is also scaled by movement speed).
const FPS: Dictionary = {"idle": 2.0, "walk": 10.0, "slash": 14.0, "thrust": 16.0, "hurt": 10.0}
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
	var key := StringName(LpcCatalog.animation_key(action_name, LpcCatalog.Direction.DOWN))
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
func play(new_action: String, new_direction: LpcCatalog.Direction, duration: float = 0.0) -> void:
	action = new_action
	direction = new_direction
	_time = 0.0
	_finished = false
	_speed = 1.0
	if duration > 0.0:
		_speed = _frame_count() / FPS.get(action, 10.0) / duration
	_apply_frame()


## Keeps a looping action going (walk/idle) without restarting it; `speed` scales the frame rate.
func loop(new_action: String, new_direction: LpcCatalog.Direction, speed: float = 1.0) -> void:
	if new_action != action:
		play(new_action, new_direction)
	direction = new_direction
	_speed = speed


func is_busy() -> bool:
	return action not in LOOPING and not _finished


func _process(delta: float) -> void:
	_time += delta * _speed
	_apply_frame()


func _apply_frame() -> void:
	var key := StringName(LpcCatalog.animation_key(action, direction))
	var count: int = _frame_count()
	var frame: int = int(_time * FPS.get(action, 10.0))
	if action == "walk":
		frame = WALK_FIRST_FRAME + frame % maxi(count - WALK_FIRST_FRAME, 1)
	elif action in LOOPING:
		frame = frame % maxi(count, 1)
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
	var key := StringName(LpcCatalog.animation_key(action, direction))
	for layer in _layers:
		if layer.sprite_frames.has_animation(key):
			return layer.sprite_frames.get_frame_count(key)
	return 1



## The LPC direction for a vector (screen y grows downwards).
static func direction_of(vector: Vector2) -> LpcCatalog.Direction:
	if absf(vector.x) >= absf(vector.y) * DIAGONAL_SIDE_BIAS:
		return LpcCatalog.Direction.RIGHT if vector.x > 0.0 else LpcCatalog.Direction.LEFT
	return LpcCatalog.Direction.DOWN if vector.y > 0.0 else LpcCatalog.Direction.UP
