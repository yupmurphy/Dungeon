class_name HealthComponent
extends Node
## Reusable health. The owner calls setup() with its max health and listens to the signals.

signal health_changed(current: float, maximum: float)
signal damaged(amount: float)
signal died

var max_health: float = 100.0
var current_health: float = 100.0
var is_dead: bool = false


func setup(new_max: float) -> void:
	max_health = new_max
	current_health = new_max
	is_dead = false
	health_changed.emit(current_health, max_health)


func take_damage(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current_health = maxf(current_health - amount, 0.0)
	damaged.emit(amount)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		is_dead = true
		died.emit()


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	current_health = minf(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)
