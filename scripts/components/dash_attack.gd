class_name DashAttack
extends Node
## Short, fast dash in a chosen direction, used the same way by the player and by monsters.
## The dasher passes through other bodies (walls still stop it). A strike during the dash hits harder
## (DAMAGE_BONUS) and hits everything the attack hitbox touches on the way.
## Costs exhaustion and has a cooldown; not usable while exhausted (the owner's ExhaustionComponent reached 100).
## Optional wind-up: the owner leans back first (the warning monsters give before a dash attack).
## The owner asks dash_velocity() every physics frame and moves with it while is_busy().
## Defaults are the constants below; a monster can change the exported values (e.g. a slow, heavy dash).

signal dash_started(direction: Vector2)
signal dash_finished
## A strike began (the owner plays its attack animation).
signal struck(direction: Vector2)

## Reference pixels per second (see GameScale) and seconds: 320 * 0.18 = about 58 px.
const DASH_SPEED: float = 320.0
const DASH_TIME: float = 0.18
## +30% damage for a strike made during the dash.
const DAMAGE_BONUS: float = 0.3
const EXHAUSTION_COST: float = 15.0
const COOLDOWN: float = 1.5
## Off by default; turn on to test a dodge-like dash.
const INVULNERABLE: bool = false
## A strike made late in the dash still stays active at least this long.
const MIN_STRIKE_TIME: float = 0.1
## Ghost trail: one fading copy of the sprite every GHOST_INTERVAL seconds.
const GHOST_INTERVAL: float = 0.03
const GHOST_TINT: Color = Color(0.6, 0.85, 1.0, 0.6)
## Wind-up lean: the picture tilts and moves back (reference pixels) against the dash direction.
const LEAN_ANGLE: float = 0.3
const LEAN_DISTANCE: float = 3.0
## While dashing the owner collides only with these layers (the world): it passes through other bodies.
const PASS_THROUGH_MASK: int = 1

@export var speed: float = DASH_SPEED
@export var duration: float = DASH_TIME
@export var damage_bonus: float = DAMAGE_BONUS
@export var exhaustion_cost: float = EXHAUSTION_COST
@export var cooldown: float = COOLDOWN
@export var invulnerable: bool = INVULNERABLE
## Monsters: lean back this long before dashing (0 = dash at once, the player).
@export var windup_time: float = 0.0
## Knockback of the dash strike compared with the owner's normal attack.
@export var knockback_multiplier: float = 1.0

@export_group("Owner parts")
## The picture that leaves the ghost trail and leans during the wind-up (every visible AnimatedSprite2D in it).
@export var visual: Node2D
## The owner's attack hitbox and the pivot that points it; null = the dash cannot strike (e.g. a fleeing archer).
@export var hitbox: Hitbox
@export var attack_pivot: Node2D
## Null = dashing is free (monsters have no exhaustion).
@export var exhaustion: ExhaustionComponent
@export var hurtbox: Hurtbox

var _direction: Vector2 = Vector2.ZERO
var _windup_left: float = 0.0
var _dash_left: float = 0.0
var _cooldown_left: float = 0.0
var _ghost_left: float = 0.0
var _struck: bool = false
var _made_invulnerable: bool = false
var _saved_mask: int = -1
var _visual_position: Vector2
var _visual_rotation: float = 0.0


func is_dashing() -> bool:
	return _dash_left > 0.0


func is_winding_up() -> bool:
	return _windup_left > 0.0


## Winding up or dashing: the owner lets the dash move it and does nothing else.
func is_busy() -> bool:
	return is_dashing() or is_winding_up()


func cooldown_left() -> float:
	return _cooldown_left


func can_dash() -> bool:
	return not is_busy() and _cooldown_left <= 0.0 and (exhaustion == null or not exhaustion.exhausted)


## Starts the dash (after the wind-up, if any). Returns false when it can't be used now.
func try_dash(direction: Vector2) -> bool:
	if not can_dash() or direction.length_squared() < 0.0001:
		return false
	_direction = direction.normalized()
	_struck = false
	_cooldown_left = cooldown
	if exhaustion != null:
		exhaustion.add(exhaustion_cost)
	if windup_time > 0.0:
		_windup_left = windup_time
		_lean(true)
	else:
		_start_dash()
	return true


## Strikes during the dash (once per dash): `damage` and `knockback_force` are the owner's normal attack.
func try_strike(damage: float, knockback_force: float) -> bool:
	if not is_dashing() or _struck or hitbox == null:
		return false
	_struck = true
	if attack_pivot != null:
		attack_pivot.rotation = _direction.angle()
	hitbox.damage = damage * (1.0 + damage_bonus)
	hitbox.knockback_force = knockback_force * knockback_multiplier
	# Stays on for the rest of the dash: everything met on the way is hit (once each).
	hitbox.activate(maxf(_dash_left, MIN_STRIKE_TIME))
	struck.emit(_direction)
	return true


## Movement the owner should use this frame (zero while winding up or not dashing).
func dash_velocity() -> Vector2:
	return _direction * GameScale.world(speed) if is_dashing() else Vector2.ZERO


func direction() -> Vector2:
	return _direction


## Stops a wind-up or dash right away (the owner was hit, died...). The cooldown still counts.
func cancel() -> void:
	if is_winding_up():
		_lean(false)
	_windup_left = 0.0
	if is_dashing():
		_end_dash()


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if _windup_left > 0.0:
		_windup_left -= delta
		if _windup_left <= 0.0:
			_lean(false)
			_start_dash()
		return
	if _dash_left > 0.0:
		_dash_left -= delta
		_ghost_left -= delta
		if _ghost_left <= 0.0:
			_ghost_left = GHOST_INTERVAL
			_spawn_ghosts()
		if _dash_left <= 0.0:
			_end_dash()


func _start_dash() -> void:
	_dash_left = duration
	_ghost_left = 0.0
	if invulnerable and hurtbox != null and not hurtbox.invulnerable:
		hurtbox.invulnerable = true
		_made_invulnerable = true
	var body := get_parent() as CollisionObject2D
	if body != null:
		_saved_mask = body.collision_mask
		body.collision_mask = PASS_THROUGH_MASK
	dash_started.emit(_direction)


func _end_dash() -> void:
	_dash_left = 0.0
	if _made_invulnerable:
		hurtbox.invulnerable = false
		_made_invulnerable = false
	if _saved_mask >= 0:
		# Deferred: a dash can end inside a physics callback (the owner was hit).
		get_parent().set_deferred("collision_mask", _saved_mask)
		_saved_mask = -1
	dash_finished.emit()


func _spawn_ghosts() -> void:
	if visual == null:
		return
	for sprite in visual.find_children("*", "AnimatedSprite2D", true, false):
		if (sprite as AnimatedSprite2D).is_visible_in_tree():
			GameFeel.spawn_ghost(sprite, GHOST_TINT)


## Wind-up warning: tilt back and step back from the dash direction; `on` = false puts the picture back.
func _lean(on: bool) -> void:
	if visual == null:
		return
	if on:
		_visual_position = visual.position
		_visual_rotation = visual.rotation
		var side: float = -1.0 if _direction.x >= 0.0 else 1.0
		visual.rotation = _visual_rotation + side * LEAN_ANGLE
		visual.position = _visual_position - _direction * GameScale.world(LEAN_DISTANCE)
	else:
		visual.position = _visual_position
		visual.rotation = _visual_rotation
