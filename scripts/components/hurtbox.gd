class_name Hurtbox
extends Area2D
## The "can be hit" area. Applies damage to the linked HealthComponent and tells its owner
## (via hit_received) so the owner can react with knockback, flashes, etc.

signal hit_received(damage: float, knockback: Vector2)

@export var health: HealthComponent
## Short grace period after each hit so one attack cannot land several times.
@export var invulnerable_after_hit: float = 0.0

## Set by the owner for invulnerability windows (e.g. while dodging).
var invulnerable: bool = false
var _grace_left: float = 0.0


func _process(delta: float) -> void:
	if _grace_left > 0.0:
		_grace_left -= delta


func is_invulnerable() -> bool:
	return invulnerable or _grace_left > 0.0 or (health != null and health.is_dead)


## Returns true if the hit actually landed.
func receive_hit(damage: float, direction: Vector2, force: float) -> bool:
	if is_invulnerable():
		return false
	_grace_left = invulnerable_after_hit
	if health != null:
		health.take_damage(damage)
	hit_received.emit(damage, direction * force)
	return true
