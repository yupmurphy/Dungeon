class_name Projectile
extends Hitbox
## A flying shot (the goblin archer's arrow): a Hitbox that moves along its facing (local +X), turns a little
## toward its target (limited homing), hurts the first Hurtbox it reaches and stops at walls, trees and rocks
## (the world layer) or when its range is used up. Dodging through it works like with any Hitbox.
## Built in code by Enemy (no scene); speeds and distances are world pixels.

const WORLD_LAYER: int = 1
const PLAYER_HURTBOX_LAYER: int = 8
const ENEMY_HITBOX_LAYER: int = 64
## Reference pixels (see GameScale).
const RADIUS: float = 2.0
## Homing stops once the target is this far off the flight line (the shot went past it).
const MAX_HOMING_ANGLE: float = PI / 2.0

var texture: Texture2D
var speed: float = 300.0
var max_distance: float = 400.0
## Radians per second the shot may turn toward `target`; 0 = straight.
var turn_rate: float = 0.0
var target: Node2D

var _distance_left: float


func _ready() -> void:
	super._ready()
	collision_layer = ENEMY_HITBOX_LAYER
	collision_mask = PLAYER_HURTBOX_LAYER | WORLD_LAYER
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = GameScale.world(RADIUS)
	shape.shape = circle
	add_child(shape)
	if texture != null:
		var sprite := Sprite2D.new()
		sprite.texture = texture
		add_child(sprite)
	_distance_left = max_distance
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_hit)
	deactivated.connect(queue_free)
	activate(max_distance / maxf(speed, 1.0))


func _physics_process(delta: float) -> void:
	if turn_rate > 0.0 and is_instance_valid(target):
		var wanted: float = (target.global_position - global_position).angle()
		if absf(angle_difference(rotation, wanted)) < MAX_HOMING_ANGLE:
			rotation = rotate_toward(rotation, wanted, turn_rate * delta)
	var step: float = speed * delta
	global_position += global_transform.x.normalized() * step
	_distance_left -= step
	if _distance_left <= 0.0:
		queue_free()


func _on_body_entered(_body: Node2D) -> void:
	queue_free()


## Hitbox already dealt the damage (or the miss); the shot is used up when it reached someone.
func _on_area_hit(_area: Area2D) -> void:
	if not _already_hit.is_empty():
		queue_free()
