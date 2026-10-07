extends Node
## Global "juice" service (autoload GameFeel): hit-stop, screen shake, floating damage numbers,
## particle bursts and dodge ghosts. Gameplay code only says *what* happened; how it looks lives here.
## Effects go on their own CanvasLayer that follows the camera, so the dark CanvasModulate does not dim them.

const DAMAGE_NUMBER_SCENE: PackedScene = preload("res://scenes/effects/damage_number.tscn")
const PARTICLE_BURST_SCENE: PackedScene = preload("res://scenes/effects/particle_burst.tscn")

const GHOST_FADE_TIME: float = 0.25
## Critical hits show their number bigger and in this color.
const CRITICAL_COLOR: Color = Color(1.0, 0.5, 0.1)
const MISS_COLOR: Color = Color(0.8, 0.85, 0.9)

var _layer: CanvasLayer
var _hit_stop_until_msec: int = 0


func _ready() -> void:
	# Keep running while the game is slowed down by hit-stop.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 5
	_layer.follow_viewport_enabled = true
	add_child(_layer)


func _process(_delta: float) -> void:
	if Engine.time_scale < 1.0 and Time.get_ticks_msec() >= _hit_stop_until_msec:
		Engine.time_scale = 1.0


## Freezes the game almost completely for `duration` real seconds.
func hit_stop(duration: float) -> void:
	_hit_stop_until_msec = maxi(_hit_stop_until_msec, Time.get_ticks_msec() + int(duration * 1000.0))
	Engine.time_scale = 0.05


## `strength` in reference pixels (see GameScale).
func shake(strength: float) -> void:
	get_tree().call_group("game_camera", "add_trauma", GameScale.world(strength))


func spawn_damage_number(world_position: Vector2, amount: float, color: Color, critical: bool = false) -> void:
	_spawn_popup(world_position, str(roundi(amount)), CRITICAL_COLOR if critical else color, critical)


## "Miss" above whoever was missed (text from the translation file, key MISS).
func spawn_miss(world_position: Vector2) -> void:
	_spawn_popup(world_position, tr(&"MISS"), MISS_COLOR, false)


func _spawn_popup(world_position: Vector2, text: String, color: Color, critical: bool) -> void:
	var number: DamageNumber = DAMAGE_NUMBER_SCENE.instantiate()
	_layer.add_child(number)
	number.setup(world_position, text, color, critical)


func spawn_burst(world_position: Vector2, color: Color, amount: int, speed: float) -> void:
	var burst: ParticleBurst = PARTICLE_BURST_SCENE.instantiate()
	_layer.add_child(burst)
	burst.setup(world_position, color, amount, GameScale.world(speed))


## Leaves a fading copy of the sprite's current frame (dodge trail).
func spawn_ghost(sprite: AnimatedSprite2D, tint: Color) -> void:
	if sprite.sprite_frames == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	ghost.flip_h = sprite.flip_h
	ghost.scale = sprite.global_scale
	ghost.global_position = sprite.global_position
	ghost.rotation = sprite.global_rotation
	ghost.modulate = tint
	_layer.add_child(ghost)
	var tween: Tween = ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, GHOST_FADE_TIME)
	tween.tween_callback(ghost.queue_free)


## Adds something drawn above the darkness in world coordinates (e.g. monster health bars and names).
func add_overlay(node: Node2D) -> void:
	_layer.add_child(node)
