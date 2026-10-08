class_name SpriteAnimator
extends Node
## Picks idle / run / attack on an AnimatedSprite2D and adds procedural motion on top
## (run bob, idle breathing, attack squash). The art pack has one frame per creature, so the
## motion comes from code; when real multi-frame animations exist, only the SpriteFrames change.
## fit_to() sizes the sprite on screen independently of the texture resolution (16 or 32 px art).
## Directional mode (SpriteFrames with idle_/run_/attack_<down|left|up|right>, e.g. LPC monsters cut by
## MonsterSheet): real frames for each facing, no flipping and no procedural motion.

@export var sprite: AnimatedSprite2D
## Set to false if the source art faces left.
@export var art_faces_right: bool = true
## Distances in reference pixels (see GameScale).
@export var run_threshold: float = 8.0
@export var bob_height: float = 2.0
@export var bob_speed: float = 14.0

var _time: float = 0.0
var _attack_left: float = 0.0
var _base_position: Vector2
var _base_scale: Vector2 = Vector2.ONE
## Set by use_frames(): the frames have one animation per facing.
var directional: bool = false
var _facing: StringName = &"down"


func _ready() -> void:
	_base_position = sprite.position


## Gives the sprite its frames and starts idling; directional frames are detected by their names.
func use_frames(frames: SpriteFrames) -> void:
	sprite.sprite_frames = frames
	directional = frames.has_animation(&"run_down")
	sprite.play(&"idle_down" if directional else &"idle")


## Scales the sprite so it appears `visual_size` reference pixels wide. Call after setting sprite_frames.
func fit_to(visual_size: float) -> void:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(sprite.animation):
		return
	var texture: Texture2D = sprite.sprite_frames.get_frame_texture(sprite.animation, 0)
	if texture != null:
		_base_scale = GameScale.fit_scale(texture.get_size(), visual_size)
		sprite.scale = _base_scale


func play_attack(duration: float) -> void:
	_attack_left = duration
	_play(&"attack")
	if directional and duration > 0.0:
		# The whole swing (raise + strike) fits the given time.
		var frame_count: int = sprite.sprite_frames.get_frame_count(sprite.animation)
		sprite.speed_scale = frame_count / (sprite.sprite_frames.get_animation_speed(sprite.animation) * duration)


## Cancels a swing (the monster was interrupted).
func stop_attack() -> void:
	_attack_left = 0.0


## Plays the death animation if the frames have one; false = nothing to play (fade only).
func play_death() -> bool:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(&"death"):
		return false
	sprite.speed_scale = 1.0
	sprite.play(&"death")
	return true


## Turns toward `direction`: one of 4 facings in directional mode, otherwise a left/right flip.
func face_vector(direction: Vector2) -> void:
	if not directional:
		face(direction.x)
		return
	if direction.length_squared() < 0.0001:
		return
	if absf(direction.x) > absf(direction.y):
		_facing = &"right" if direction.x > 0.0 else &"left"
	else:
		_facing = &"down" if direction.y > 0.0 else &"up"


func face(direction_x: float) -> void:
	if absf(direction_x) < 0.01:
		return
	var looking_left: bool = direction_x < 0.0
	sprite.flip_h = looking_left == art_faces_right


func update_motion(velocity: Vector2, delta: float) -> void:
	_time += delta
	_attack_left = maxf(_attack_left - delta, 0.0)
	if directional:
		if _attack_left > 0.0:
			_play(&"attack")
		else:
			sprite.speed_scale = 1.0
			_play(&"run" if velocity.length() > GameScale.world(run_threshold) else &"idle")
		return
	sprite.position = _base_position
	sprite.rotation = 0.0
	var squash: Vector2 = Vector2.ONE

	if _attack_left > 0.0:
		_play(&"attack")
		squash = Vector2(1.15, 0.88)
	elif velocity.length() > GameScale.world(run_threshold):
		_play(&"run")
		var wave: float = sin(_time * bob_speed)
		sprite.position.y -= absf(wave) * GameScale.world(bob_height)
		sprite.rotation = wave * 0.08
	else:
		_play(&"idle")
		squash.y = 1.0 + sin(_time * 3.0) * 0.04
	sprite.scale = _base_scale * squash


func _play(animation_name: StringName) -> void:
	var base: StringName = animation_name
	if directional:
		animation_name = StringName("%s_%s" % [animation_name, _facing])
	if sprite.animation != animation_name and sprite.sprite_frames != null \
			and sprite.sprite_frames.has_animation(animation_name):
		# Turning mid-animation (an archer following its target while aiming) keeps the animation's progress.
		var turning: bool = directional and String(sprite.animation).begins_with(String(base) + "_")
		var frame: int = sprite.frame
		var progress: float = sprite.frame_progress
		sprite.play(animation_name)
		if turning:
			sprite.set_frame_and_progress(frame, progress)
