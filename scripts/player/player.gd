class_name Player
extends CharacterBody2D
## Top-down player: 8-direction movement, sprint (Shift), mouse-aimed melee attack and a dash (DashAttack):
## a short tap on Space dashes where the character faces; attacking during the dash is a normal attack.
## Sprint, dash and attacks raise exhaustion (ExhaustionComponent). All numbers scale through Stats.
## Sizes, distances and speeds are in reference pixels and converted with GameScale.

signal died

enum State { NORMAL, DEAD }

const ATTACK_ACTIVE_TIME: float = 0.12
const ATTACK_SLOW_TIME: float = 0.2
## How long the slash / thrust animation plays.
const ATTACK_ANIMATION_TIME: float = 0.3
const KNOCKBACK_DECAY: float = 900.0
## Below this speed (reference pixels / s) the character stands (idle animation).
const WALK_THRESHOLD: float = 8.0
const DAMAGE_TAKEN_COLOR: Color = Color(1.0, 0.35, 0.3)
const HURT_SHAKE: float = 6.0
## Movement speed while sprinting (Shift).
const SPRINT_SPEED_FACTOR: float = 1.6
## Space released before this many seconds = a tap = the short dash. Held longer = charging.
const DASH_TAP_TIME: float = 0.2
## The short dash: a little exhaustion and a short wait.
const DASH_EXHAUSTION_COST: float = 8.0
const DASH_COOLDOWN: float = 0.6
## Space held this long (seconds) = fully charged; holding longer keeps the full charge.
const DASH_FULL_CHARGE_TIME: float = 1.0
## Exhaustion per second while charging (stops once fully charged).
const DASH_CHARGE_EXHAUSTION_PER_SECOND: float = 30.0
## Charged dash distance compared with the short dash: from MIN (barely charged) to MAX (full charge).
const DASH_CHARGED_DISTANCE_MIN: float = 1.5
const DASH_CHARGED_DISTANCE_MAX: float = 3.0
## Dash attack (click while charging) damage: from MIN (barely charged) to MAX (full charge).
const DASH_ATTACK_DAMAGE_MIN: float = 1.2
const DASH_ATTACK_DAMAGE_MAX: float = 2.0
## While charging the character crouches a little (picture squashed by this much at full charge).
const DASH_CHARGE_SQUASH: float = 0.08

@export var stats: Stats
## Level and XP (shown on the character sheet).
var progression: Progression = Progression.new()

@export_group("Size")
@export var body_radius: float = 6.0
## Distance from the player's center to the center of the sword hitbox.
@export var attack_reach: float = 18.0
@export var attack_size: Vector2 = Vector2(22, 28)

@export_group("Movement")
@export var base_move_speed: float = 110.0
## Movement speed multiplier right after swinging.
@export var attack_move_factor: float = 0.5

@export_group("Attack")
@export var base_attack_damage: float = 20.0
@export var base_attack_cooldown: float = 0.45
@export var attack_knockback: float = 220.0


var state: State = State.NORMAL
var is_dead: bool:
	get:
		return state == State.DEAD

var _attack_cooldown_left: float = 0.0
var _attack_slow_left: float = 0.0
var _swing_left: float = 0.0
var _knockback: Vector2 = Vector2.ZERO
var _flash_tween: Tween
## Space: dash where the character faces.
var dash: DashAttack
## Space is held (seconds since pressed); -1 = not held.
var _dash_hold: float = -1.0
## Shows the dash charge above the head.
var _charge_bar: ChargeBar

@onready var health: HealthComponent = $HealthComponent
@onready var exhaustion: ExhaustionComponent = $ExhaustionComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var attack_pivot: Node2D = $AttackPivot
@onready var hitbox: Hitbox = $AttackPivot/Hitbox
@onready var slash_visual: Polygon2D = $AttackPivot/Hitbox/SlashVisual
@onready var visual: Node2D = $Visual
## The LPC look: stacked layers (body, clothes, weapon...) animated together.
@onready var character: LpcCharacter = $Visual/Character
## What the player wears; changing it changes the look right away.
@onready var equipment: Equipment = $Equipment


func _ready() -> void:
	if stats == null:
		stats = Stats.new()
	# Own copy: changing the stats in game must not edit the shared .tres.
	stats = stats.duplicate()
	_apply_sizes()
	health.setup(stats.get_max_health())
	exhaustion.gain_multiplier = stats.get_exhaustion_gain_multiplier()
	health.died.connect(_on_died)
	hurtbox.hit_received.connect(_on_hit_received)
	hurtbox.hit_missed.connect(_on_hit_missed)
	hurtbox.defender = stats
	hitbox.attacker = stats
	stats.changed.connect(_on_stats_changed)
	equipment.changed.connect(_refresh_look)
	_refresh_look()
	hitbox.activated.connect(slash_visual.show)
	hitbox.deactivated.connect(slash_visual.hide)
	dash = DashAttack.new()
	dash.visual = visual
	dash.hitbox = hitbox
	dash.attack_pivot = attack_pivot
	dash.exhaustion = exhaustion
	dash.hurtbox = hurtbox
	dash.exhaustion_cost = DASH_EXHAUSTION_COST
	dash.cooldown = DASH_COOLDOWN
	add_child(dash)
	_charge_bar = ChargeBar.new()
	add_child(_charge_bar)


## Builds collision shapes, hitbox placement and light size from the exported sizes.
func _apply_sizes() -> void:
	($CollisionShape2D.shape as CircleShape2D).radius = GameScale.world(body_radius)
	($Hurtbox/CollisionShape2D.shape as CircleShape2D).radius = GameScale.world(body_radius + 1.0)
	hitbox.position.x = GameScale.world(attack_reach)
	($AttackPivot/Hitbox/CollisionShape2D.shape as RectangleShape2D).size = GameScale.world_vector(attack_size)
	# The slash polygon is drawn for an 18 px reach; scale it with the actual reach.
	var reach_factor: float = GameScale.world(attack_reach) / 18.0
	slash_visual.scale = Vector2(reach_factor, reach_factor)
	_apply_light()


## The light radius comes from Perception (Stats).
func _apply_light() -> void:
	var light := $Torch as PointLight2D
	light.texture_scale = GameScale.world(stats.get_light_radius()) * 2.0 / light.texture.get_width()


func _physics_process(delta: float) -> void:
	_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)
	_attack_slow_left = maxf(_attack_slow_left - delta, 0.0)
	_swing_left = maxf(_swing_left - delta, 0.0)
	_knockback = _knockback.move_toward(Vector2.ZERO, GameScale.world(KNOCKBACK_DECAY) * delta)

	match state:
		State.NORMAL:
			_physics_normal()
		State.DEAD:
			velocity = _knockback
	move_and_slide()

	if state != State.DEAD:
		_update_animation()


func _physics_normal() -> void:
	if _swing_left <= 0.0:
		_aim_at_mouse()
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dash.is_busy():
		velocity = dash.dash_velocity() + _knockback
		if Input.is_action_just_pressed("attack"):
			_try_attack()
		return
	if _tick_dash_key(input_dir):
		velocity = dash.dash_velocity() + _knockback
		return
	# Shallow water, reeds, quicksand... slow you down.
	var speed: float = GameScale.world(base_move_speed) * stats.get_move_speed_multiplier() \
		* FloorLayout.speed_factor_at(global_position)
	if _attack_slow_left > 0.0:
		speed *= attack_move_factor
	# Tired (exhaustion above 70) = slower.
	speed *= exhaustion.speed_factor()
	if input_dir != Vector2.ZERO and Input.is_action_pressed("sprint") and exhaustion.can_sprint():
		speed *= SPRINT_SPEED_FACTOR
		exhaustion.add(ExhaustionComponent.SPRINT_PER_SECOND * get_physics_process_delta_time())
	velocity = input_dir * speed + _knockback

	if Input.is_action_just_pressed("attack"):
		_try_attack()


## Space, all launched where the character faces:
## - tap (released before DASH_TAP_TIME): the short dash;
## - held longer: charging, standing still and tiring; released = a long dash without damage;
## - attack while Space is held: Space counts as released and it launches the dash attack.
## Returns true when the player must not walk this frame (charging or just dashed).
func _tick_dash_key(input_dir: Vector2) -> bool:
	if Input.is_action_just_pressed("dash") and dash.can_dash():
		_dash_hold = 0.0
	if _dash_hold < 0.0:
		return false
	if Input.is_action_just_pressed("attack"):
		return _launch_dash(input_dir, true)
	if not Input.is_action_pressed("dash"):
		return _launch_dash(input_dir, false)
	var delta: float = get_physics_process_delta_time()
	_dash_hold += delta
	if _dash_hold < DASH_TAP_TIME:
		return false
	if _dash_charge() < 1.0:
		exhaustion.add(DASH_CHARGE_EXHAUSTION_PER_SECOND * delta)
	if exhaustion.exhausted:
		# Ran out of breath while charging: the charge stops and launches as a long dash.
		return _launch_dash(input_dir, false)
	_show_charge(_dash_charge())
	return true


## 0 at DASH_TAP_TIME, 1 at DASH_FULL_CHARGE_TIME and after.
func _dash_charge() -> float:
	return clampf((_dash_hold - DASH_TAP_TIME) / (DASH_FULL_CHARGE_TIME - DASH_TAP_TIME), 0.0, 1.0)


func _launch_dash(input_dir: Vector2, attack: bool) -> bool:
	var charged: bool = attack or _dash_hold >= DASH_TAP_TIME
	var charge: float = _dash_charge()
	_dash_hold = -1.0
	_show_charge(-1.0)
	# Agility makes every dash longer and the dash attack stronger.
	var power: float = stats.get_dash_power_multiplier()
	var distance: float = power
	if charged:
		distance *= lerpf(DASH_CHARGED_DISTANCE_MIN, DASH_CHARGED_DISTANCE_MAX, charge)
	if not dash.try_dash(_facing(input_dir), distance, true):
		return false
	if attack:
		var damage: float = base_attack_damage * exhaustion.damage_factor()
		var knockback_force: float = GameScale.world(attack_knockback) * stats.get_knockback_multiplier()
		dash.try_strike(damage, knockback_force, lerpf(DASH_ATTACK_DAMAGE_MIN, DASH_ATTACK_DAMAGE_MAX, charge) * power)
		exhaustion.add(ExhaustionComponent.ATTACK_COST)
		_attack_cooldown_left = base_attack_cooldown / (stats.get_attack_speed_multiplier() * exhaustion.speed_factor())
		# The aim stays along the dash while flying.
		_swing_left = dash.time_left()
		character.play("thrust", LpcCharacter.direction_of(dash.direction()), dash.time_left())
	return true


## Charge bar and crouch; `charge` < 0 = not charging.
func _show_charge(charge: float) -> void:
	_charge_bar.visible = charge >= 0.0
	_charge_bar.ratio = maxf(charge, 0.0)
	var squash: float = DASH_CHARGE_SQUASH * maxf(charge, 0.0)
	visual.scale = Vector2(1.0 + squash, 1.0 - squash)


## Where the character looks: where it walks, or toward the mouse when standing (like the animations).
func _facing(input_dir: Vector2) -> Vector2:
	if input_dir != Vector2.ZERO:
		return input_dir
	return get_global_mouse_position() - global_position


func _aim_at_mouse() -> void:
	var aim: Vector2 = get_global_mouse_position() - global_position
	if aim.length() > 0.001:
		attack_pivot.rotation = aim.angle()


## Walk / idle facing where you move (or the mouse when standing). An attack animation plays to its end.
func _update_animation() -> void:
	if character.is_busy():
		return
	var moving: Vector2 = velocity - _knockback
	var walk_speed: float = GameScale.world(base_move_speed)
	if moving.length() > GameScale.world(WALK_THRESHOLD):
		character.loop("walk", LpcCharacter.direction_of(moving), moving.length() / walk_speed)
	else:
		character.loop("idle", LpcCharacter.direction_of(get_global_mouse_position() - global_position))


func _try_attack() -> void:
	if _attack_cooldown_left > 0.0:
		return
	# Exhausted (reached 100, not yet below 70) = less damage.
	var damage: float = base_attack_damage * exhaustion.damage_factor()
	var knockback_force: float = GameScale.world(attack_knockback) * stats.get_knockback_multiplier()
	# Also during the dash: a normal attack toward the mouse, normal damage.
	_aim_at_mouse()
	hitbox.damage = damage
	hitbox.knockback_force = knockback_force
	hitbox.activate(ATTACK_ACTIVE_TIME)
	_swing_left = ATTACK_ACTIVE_TIME
	_attack_slow_left = ATTACK_SLOW_TIME
	exhaustion.add(ExhaustionComponent.ATTACK_COST)
	_attack_cooldown_left = base_attack_cooldown / (stats.get_attack_speed_multiplier() * exhaustion.speed_factor())
	var aim: Vector2 = Vector2.from_angle(attack_pivot.rotation)
	character.play(character.attack_action(), LpcCharacter.direction_of(aim), ATTACK_ANIMATION_TIME)


func _on_hit_missed() -> void:
	GameFeel.spawn_miss(global_position)


func _set_flash(amount: float) -> void:
	(character.layer_material as ShaderMaterial).set_shader_parameter("flash_amount", amount)


func _on_hit_received(damage: float, knockback: Vector2, critical: bool) -> void:
	_knockback = knockback
	GameFeel.shake(HURT_SHAKE)
	GameFeel.spawn_damage_number(global_position, damage, DAMAGE_TAKEN_COLOR, critical)
	if state == State.DEAD:
		return
	if _flash_tween != null:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_method(_set_flash, 1.0, 0.0, 0.2)
	# A short flinch, unless an attack is being drawn (it would cut the swing).
	if character.action not in ["slash", "thrust"]:
		character.play("flinch", character.direction)


func _on_died() -> void:
	state = State.DEAD
	_dash_hold = -1.0
	_show_charge(-1.0)
	dash.cancel()
	hurtbox.invulnerable = true
	hitbox.deactivate()
	visual.modulate = Color(0.75, 0.75, 0.8, 1.0)
	# The LPC fall to the ground.
	character.play("death", character.direction)
	_set_flash(0.0)
	died.emit()


## Stats changed in game (character sheet debug buttons, later level ups): refresh what is cached.
func _on_stats_changed() -> void:
	health.set_max_health(stats.get_max_health())
	exhaustion.gain_multiplier = stats.get_exhaustion_gain_multiplier()
	_apply_light()


## Rebuilds the layered look from the equipment (body type + worn pieces).
func _refresh_look() -> void:
	character.body_type = equipment.body_type
	character.items = equipment.look_items()
	character.rebuild()
