class_name Hitbox
extends Area2D
## The "deals damage" area. Stays off until activate() is called, then damages every Hurtbox
## it overlaps (once per activation). Knockback goes along the hitbox's facing (its local +X).

signal activated
signal deactivated

var damage: float = 0.0
var knockback_force: float = 0.0

var _already_hit: Array[Hurtbox] = []
var _timer: Timer


func _ready() -> void:
	monitoring = false
	monitorable = false
	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(deactivate)
	area_entered.connect(_on_area_entered)


func activate(duration: float) -> void:
	_already_hit.clear()
	monitoring = true
	_timer.start(maxf(duration, 0.01))
	activated.emit()


func deactivate() -> void:
	# Deferred: this can be called from inside a physics callback, where changing monitoring is blocked.
	set_deferred("monitoring", false)
	_timer.stop()
	deactivated.emit()


func _on_area_entered(area: Area2D) -> void:
	var hurtbox := area as Hurtbox
	if hurtbox == null or hurtbox in _already_hit:
		return
	var direction: Vector2 = global_transform.x.normalized()
	if hurtbox.receive_hit(damage, direction, knockback_force):
		_already_hit.append(hurtbox)
