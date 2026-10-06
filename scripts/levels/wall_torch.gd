extends Node2D
## Wall torch: flickering warm light.

@export var base_energy: float = 0.9
@export var flicker_amount: float = 0.2
## Reach of the light, in reference pixels (see GameScale).
@export var light_radius: float = 64.0

var _time: float = 0.0

@onready var _light: PointLight2D = $Light


func _ready() -> void:
	var sprite := $Sprite2D as Sprite2D
	sprite.scale = Vector2.ONE * GameScale.TILE_SIZE / TileAtlas.TILE_SIZE
	_light.position.y = GameScale.world(10.0)
	_light.texture_scale = GameScale.world(light_radius) * 2.0 / _light.texture.get_width()
	# Different start phase so torches don't flicker in sync.
	_time = randf() * 10.0


func _process(delta: float) -> void:
	_time += delta
	var wave: float = sin(_time * 9.0) * 0.5 + sin(_time * 23.0) * 0.3 + randf_range(-0.2, 0.2)
	_light.energy = base_energy + wave * flicker_amount
