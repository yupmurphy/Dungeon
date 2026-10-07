class_name Hurtbox
extends Area2D
## The "can be hit" area. Applies damage to the linked HealthComponent and tells its owner
## (via hit_received / hit_missed) so the owner can react with knockback, flashes, "miss" text, etc.

signal hit_received(damage: float, knockback: Vector2, critical: bool)
## The attack reached us but missed (the owner's Agility).
signal hit_missed

@export var health: HealthComponent
## Short grace period after each hit so one attack cannot land several times.
@export var invulnerable_after_hit: float = 0.0

## Stats of the owner (evade chance, defense), set by the owner. Null = no evade, no defense.
var defender: Stats
## Set by the owner for invulnerability windows (e.g. while dodging).
var invulnerable: bool = false
## Debug invincibility (F3); separate so dodges don't switch it off.
var god_mode: bool = false
var _grace_left: float = 0.0


func _process(delta: float) -> void:
	if _grace_left > 0.0:
		_grace_left -= delta


func is_invulnerable() -> bool:
	return invulnerable or god_mode or _grace_left > 0.0 or (health != null and health.is_dead)


## `hit` comes from Combat.resolve (damage already after bonus, critical and defense).
## Returns true if the attack reached us (hit or miss), false if we were invulnerable.
func receive_hit(hit: Combat.Hit, direction: Vector2, force: float) -> bool:
	if is_invulnerable():
		return false
	_grace_left = invulnerable_after_hit
	if hit.missed:
		hit_missed.emit()
		return true
	if health != null:
		health.take_damage(hit.damage)
	hit_received.emit(hit.damage, direction * force, hit.critical)
	return true
