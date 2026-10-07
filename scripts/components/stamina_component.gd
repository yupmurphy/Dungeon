class_name StaminaComponent
extends Node
## Reusable stamina: spend() for actions, automatic regeneration after a short delay.

signal stamina_changed(current: float, maximum: float)

@export var max_stamina: float = 100.0
@export var regen_per_second: float = 35.0
## Seconds after spending before regeneration starts.
@export var regen_delay: float = 0.7

var current_stamina: float = 0.0
var _delay_left: float = 0.0


func _ready() -> void:
	current_stamina = max_stamina
	stamina_changed.emit(current_stamina, max_stamina)


## Called by the owner with the max stamina computed from its stats; refills the bar.
func setup(new_max: float) -> void:
	max_stamina = new_max
	current_stamina = new_max
	stamina_changed.emit(current_stamina, max_stamina)


func spend(cost: float) -> bool:
	if current_stamina < cost:
		return false
	current_stamina -= cost
	_delay_left = regen_delay
	stamina_changed.emit(current_stamina, max_stamina)
	return true


func _process(delta: float) -> void:
	if _delay_left > 0.0:
		_delay_left -= delta
		return
	if current_stamina < max_stamina:
		current_stamina = minf(current_stamina + regen_per_second * delta, max_stamina)
		stamina_changed.emit(current_stamina, max_stamina)


## Max stamina changed (e.g. Strength went up): a gain is added to current stamina too, a loss only caps it.
func set_max_stamina(new_max: float) -> void:
	current_stamina = clampf(current_stamina + maxf(new_max - max_stamina, 0.0), 0.0, new_max)
	max_stamina = new_max
	stamina_changed.emit(current_stamina, max_stamina)
