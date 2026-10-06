class_name SpriteAnimator
extends Node
## Picks idle / run / attack on an AnimatedSprite2D and adds procedural motion on top
## (run bob, idle breathing, attack squash). The art pack has one frame per creature, so the
## motion comes from code; when real multi-frame animations exist, only the SpriteFrames change.

@export var sprite: AnimatedSprite2D
## Set to false if the source art faces left.
@export var art_faces_right: bool = true
@export var run_threshold: float = 8.0
@export var bob_height: float = 2.0
@export var bob_speed: float = 14.0

var _time: float = 0.0
var _attack_left: float = 0.0
var _base_position: Vector2


func _ready() -> void:
	_base_position = sprite.position


func play_attack(duration: float) -> void:
	_attack_left = duration
	_play(&"attack")


func face(direction_x: float) -> void:
	if absf(direction_x) < 0.01:
		return
	var looking_left: bool = direction_x < 0.0
	sprite.flip_h = looking_left == art_faces_right


func update_motion(velocity: Vector2, delta: float) -> void:
	_time += delta
	_attack_left = maxf(_attack_left - delta, 0.0)
	sprite.position = _base_position
	sprite.rotation = 0.0
	sprite.scale = Vector2.ONE

	if _attack_left > 0.0:
		_play(&"attack")
		sprite.scale = Vector2(1.15, 0.88)
	elif velocity.length() > run_threshold:
		_play(&"run")
		var wave: float = sin(_time * bob_speed)
		sprite.position.y -= absf(wave) * bob_height
		sprite.rotation = wave * 0.08
	else:
		_play(&"idle")
		sprite.scale.y = 1.0 + sin(_time * 3.0) * 0.04


func _play(animation_name: StringName) -> void:
	if sprite.animation != animation_name and sprite.sprite_frames != null \
			and sprite.sprite_frames.has_animation(animation_name):
		sprite.play(animation_name)
