extends Node2D
## Wall torch: flickering warm light.

@export var base_energy: float = 0.9
@export var flicker_amount: float = 0.2

var _time: float = 0.0

@onready var _light: PointLight2D = $Light


func _ready() -> void:
	# Different start phase so torches don't flicker in sync.
	_time = randf() * 10.0


func _process(delta: float) -> void:
	_time += delta
	var wave: float = sin(_time * 9.0) * 0.5 + sin(_time * 23.0) * 0.3 + randf_range(-0.2, 0.2)
	_light.energy = base_energy + wave * flicker_amount
