class_name WallTorch
extends Node2D
## Riveted wall torch with cached flame frames and subtle, smooth warm-light flicker.

const SOUTH_SHADOW_OFFSET: Vector2 = Vector2(2, 1)
const SHADOW_FLOOR_GAP: float = 3.0
const SHADOW_SIDE_OFFSET: float = 2.0
const FLAME_LIGHT_OFFSET: Vector2 = Vector2(0, -4)
const FLAME_FPS: float = 8.0
const LIGHT_COLOR: Color = Color(1.0, 0.64, 0.3)
const FLICKER_FREQUENCY: Vector2 = Vector2(3.5, 7.0)
const FLICKER_WEIGHTS: Vector2 = Vector2(0.6, 0.4)
const PHASE_RANGE: float = 10.0

@export var base_energy: float = 0.85
@export var flicker_amount: float = 0.07
## Reach of the light, in reference pixels (see GameScale).
@export var light_radius: float = 56.0
@export var mount_direction: Vector2i = Vector2i.DOWN

var _time: float = 0.0
var _frame: int = -1

@onready var _light: PointLight2D = $Light
@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("wall_torch")
	_sprite.region_enabled = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2.ONE * GameScale.TILE_SIZE / WallArt.SIZE.x
	_sprite.position = GameScale.world_vector(Vector2(WallArt.mount_offset(mount_direction)))
	var shadow := Sprite2D.new()
	shadow.name = "CastShadow"
	shadow.texture = WallArt.shadow_texture()
	shadow.scale = _sprite.scale
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sideways := Vector2(-mount_direction.y, mount_direction.x)
	if mount_direction == Vector2i.DOWN:
		# Cast on the face behind the raised fixture, not on the floor under its handle.
		shadow.position = _sprite.position + GameScale.world_vector(SOUTH_SHADOW_OFFSET)
	else:
		shadow.position = Vector2(mount_direction) * (GameScale.TILE_SIZE / 2.0 + GameScale.world(SHADOW_FLOOR_GAP)) \
			+ sideways * GameScale.world(SHADOW_SIDE_OFFSET)
	add_child(shadow)
	move_child(shadow, 0)
	var bracket := Sprite2D.new()
	bracket.name = "Bracket"
	bracket.texture = WallArt.bracket_texture(mount_direction)
	bracket.scale = _sprite.scale
	bracket.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(bracket)
	move_child(bracket, 1)
	_light.position = _sprite.position + GameScale.world_vector(FLAME_LIGHT_OFFSET)
	_light.color = LIGHT_COLOR
	_light.texture_scale = GameScale.world(light_radius) * 2.0 / _light.texture.get_width()
	_time = randf() * PHASE_RANGE
	_update_flame()


func _process(delta: float) -> void:
	_time += delta
	var wave: float = sin(_time * FLICKER_FREQUENCY.x) * FLICKER_WEIGHTS.x \
		+ sin(_time * FLICKER_FREQUENCY.y) * FLICKER_WEIGHTS.y
	_light.energy = base_energy + wave * flicker_amount
	_update_flame()


func _update_flame() -> void:
	var next: int = posmod(int(_time * FLAME_FPS), WallArt.FLAME_FRAMES)
	if next != _frame:
		_frame = next
		_sprite.texture = WallArt.torch_texture(_frame)
