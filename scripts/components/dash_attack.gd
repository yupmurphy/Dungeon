class_name DashAttack
extends Node
## Short, fast dash in a chosen direction, used the same way by the player and by monsters.
## The dasher passes through other bodies (walls still stop it). A strike during the dash hits harder
## (DAMAGE_BONUS) and hits everything the attack hitbox touches on the way. Air rushes around the dasher (AirFlow,
## more of it on longer dashes); no tint on the dasher itself.
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
## Air during the dash: the default dash gets AIR_INTENSITY_MIN, a dash AIR_FULL_DISTANCE times as far gets the most.
const AIR_INTENSITY_MIN: float = 0.15
const AIR_FULL_DISTANCE: float = 3.0
## Air gathering during a wind-up (monsters).
const WINDUP_AIR_INTENSITY: float = 0.6
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
## The picture that leans during the wind-up.
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
var _struck: bool = false
var _made_invulnerable: bool = false
var _saved_mask: int = -1
var _visual_position: Vector2
var _visual_rotation: float = 0.0
## This dash, compared with the default one (see try_dash).
var _speed_scale: float = 1.0
var _time_scale: float = 1.0
var _air_intensity: float = 0.0
var _air: AirFlow


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
## `distance_scale`: how far compared with the default dash (speed and time both grow, by its square root).
## `ignore_exhaustion`: dash even when exhausted (a charge that ran the owner to 100 still launches).
func try_dash(direction: Vector2, distance_scale: float = 1.0, ignore_exhaustion: bool = false) -> bool:
	if direction.length_squared() < 0.0001 or is_busy() or _cooldown_left > 0.0:
		return false
	if not ignore_exhaustion and not can_dash():
		return false
	_direction = direction.normalized()
	_speed_scale = sqrt(maxf(distance_scale, 0.01))
	_time_scale = _speed_scale
	_air_intensity = lerpf(AIR_INTENSITY_MIN, 1.0, clampf(inverse_lerp(1.0, AIR_FULL_DISTANCE, distance_scale), 0.0, 1.0))
	_struck = false
	_cooldown_left = cooldown
	if exhaustion != null:
		exhaustion.add(exhaustion_cost)
	if windup_time > 0.0:
		_windup_left = windup_time
		_lean(true)
		_set_air(AirFlow.Mode.GATHER, WINDUP_AIR_INTENSITY)
	else:
		_start_dash()
	return true


## Strikes during the dash (once per dash): `damage` and `knockback_force` are the owner's normal attack.
## `damage_multiplier`: 0 = the default (1 + damage_bonus); the player's charged dash attack passes its own.
func try_strike(damage: float, knockback_force: float, damage_multiplier: float = 0.0) -> bool:
	if not is_dashing() or _struck or hitbox == null:
		return false
	_struck = true
	if attack_pivot != null:
		attack_pivot.rotation = _direction.angle()
	hitbox.damage = damage * (damage_multiplier if damage_multiplier > 0.0 else 1.0 + damage_bonus)
	hitbox.knockback_force = knockback_force * knockback_multiplier
	# Stays on for the rest of the dash: everything met on the way is hit (once each).
	hitbox.activate(maxf(_dash_left, MIN_STRIKE_TIME))
	struck.emit(_direction)
	return true


## Movement the owner should use this frame (zero while winding up or not dashing).
func dash_velocity() -> Vector2:
	return _direction * GameScale.world(speed) * _speed_scale if is_dashing() else Vector2.ZERO


func direction() -> Vector2:
	return _direction


## Seconds of dashing left (0 when not dashing).
func time_left() -> float:
	return _dash_left


## Stops a wind-up or dash right away (the owner was hit, died...). The cooldown still counts.
func cancel() -> void:
	if is_winding_up():
		_lean(false)
		_set_air(AirFlow.Mode.OFF, 0.0)
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
		if _dash_left <= 0.0:
			_end_dash()


func _start_dash() -> void:
	_dash_left = duration * _time_scale
	_set_air(AirFlow.Mode.TRAIL, _air_intensity)
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
	_set_air(AirFlow.Mode.OFF, 0.0)
	dash_finished.emit()


## Air drawn in while charging (the player holding Space): `charge` 0..1, below 0 = stop gathering.
func gather(charge: float) -> void:
	if charge >= 0.0:
		_set_air(AirFlow.Mode.GATHER, charge)
	elif _air != null and is_instance_valid(_air) and _air.mode == AirFlow.Mode.GATHER:
		_set_air(AirFlow.Mode.OFF, 0.0)


func _set_air(mode: AirFlow.Mode, intensity: float) -> void:
	if _air != null and not is_instance_valid(_air):
		_air = null
	if mode == AirFlow.Mode.OFF:
		if _air != null:
			_air.mode = AirFlow.Mode.OFF
		_air = null
		return
	if _air == null:
		_air = AirFlow.new()
		_air.target = get_parent() as Node2D
		GameFeel.add_overlay(_air)
	_air.mode = mode
	_air.intensity = intensity
	_air.direction = _direction


## The air effect now (null when none), for tests.
func air() -> AirFlow:
	return _air if _air != null and is_instance_valid(_air) else null


func _exit_tree() -> void:
	_set_air(AirFlow.Mode.OFF, 0.0)


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
