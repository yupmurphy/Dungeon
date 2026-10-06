extends Camera2D
## Smooth follow camera (child of the player) with trauma-based screen shake.
## GameFeel.shake() reaches it through the "game_camera" group.

@export var max_offset: float = 6.0
@export var trauma_decay: float = 2.5

var _trauma: float = 0.0


func _ready() -> void:
	add_to_group("game_camera")


func add_trauma(amount: float) -> void:
	# Callers pass "pixels of shake"; trauma is stored as 0..1 of max_offset.
	_trauma = minf(_trauma + amount / max_offset, 1.0)


func set_room_limits(rect: Rect2i) -> void:
	limit_left = rect.position.x
	limit_top = rect.position.y
	limit_right = rect.end.x
	limit_bottom = rect.end.y


func _process(delta: float) -> void:
	if _trauma <= 0.0:
		offset = Vector2.ZERO
		return
	_trauma = maxf(_trauma - trauma_decay * delta, 0.0)
	var power: float = _trauma * max_offset
	offset = Vector2(randf_range(-power, power), randf_range(-power, power))
