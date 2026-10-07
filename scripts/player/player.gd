class_name Player
extends CharacterBody2D
## Top-down player: 8-direction movement, mouse-aimed melee attack, dodge with i-frames.
## Attack and dodge both cost stamina. All numbers scale through Stats.
## Sizes, distances and speeds are in reference pixels and converted with GameScale.

signal died

enum State { NORMAL, DODGE, DEAD }

const ATTACK_ACTIVE_TIME: float = 0.12
const ATTACK_SLOW_TIME: float = 0.2
const KNOCKBACK_DECAY: float = 900.0
## Sword swing arc, in radians, on each side of the aim direction.
const SWING_HALF_ARC: float = 1.3
const GHOST_INTERVAL: float = 0.03
const GHOST_TINT: Color = Color(0.5, 0.8, 1.0, 0.6)
const DAMAGE_TAKEN_COLOR: Color = Color(1.0, 0.35, 0.3)
const HURT_SHAKE: float = 6.0

@export var stats: Stats
## Level and XP (shown on the character sheet).
var progression: Progression = Progression.new()

@export_group("Size")
## How wide the character looks on screen.
@export var visual_size: float = 16.0
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
@export var attack_stamina_cost: float = 15.0

@export_group("Dodge")
@export var dodge_speed: float = 280.0
## How long the dodge dash lasts. Invulnerability is separate and comes from Agility (Stats).
@export var dodge_duration: float = 0.18
@export var dodge_cooldown: float = 0.6
@export var dodge_stamina_cost: float = 25.0

var state: State = State.NORMAL
var is_dead: bool:
	get:
		return state == State.DEAD

var _attack_cooldown_left: float = 0.0
var _attack_slow_left: float = 0.0
var _swing_left: float = 0.0
var _swing_side: float = 1.0
var _dodge_cooldown_left: float = 0.0
var _dodge_time_left: float = 0.0
var _invulnerable_left: float = 0.0
var _dodge_dir: Vector2 = Vector2.ZERO
var _ghost_left: float = 0.0
var _knockback: Vector2 = Vector2.ZERO
var _flash_tween: Tween

@onready var health: HealthComponent = $HealthComponent
@onready var stamina: StaminaComponent = $StaminaComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var attack_pivot: Node2D = $AttackPivot
@onready var weapon_pivot: Node2D = $AttackPivot/WeaponPivot
@onready var hitbox: Hitbox = $AttackPivot/Hitbox
@onready var slash_visual: Polygon2D = $AttackPivot/Hitbox/SlashVisual
@onready var visual: Node2D = $Visual
@onready var sprite: AnimatedSprite2D = $Visual/Sprite
@onready var animator: SpriteAnimator = $SpriteAnimator


func _ready() -> void:
	if stats == null:
		stats = Stats.new()
	# Own copy: changing the stats in game must not edit the shared .tres.
	stats = stats.duplicate()
	_apply_sizes()
	health.setup(stats.get_max_health())
	stamina.setup(stats.get_max_stamina())
	health.died.connect(_on_died)
	hurtbox.hit_received.connect(_on_hit_received)
	hurtbox.hit_missed.connect(_on_hit_missed)
	hurtbox.defender = stats
	hitbox.attacker = stats
	stats.changed.connect(_on_stats_changed)
	hitbox.activated.connect(slash_visual.show)
	hitbox.deactivated.connect(slash_visual.hide)


## Builds collision shapes, weapon placement and light size from the exported sizes.
func _apply_sizes() -> void:
	animator.fit_to(visual_size)
	($CollisionShape2D.shape as CircleShape2D).radius = GameScale.world(body_radius)
	($Hurtbox/CollisionShape2D.shape as CircleShape2D).radius = GameScale.world(body_radius + 1.0)
	hitbox.position.x = GameScale.world(attack_reach)
	($AttackPivot/Hitbox/CollisionShape2D.shape as RectangleShape2D).size = GameScale.world_vector(attack_size)
	# The slash polygon and sword are drawn for an 18 px reach; scale them with the actual reach.
	var reach_factor: float = GameScale.world(attack_reach) / 18.0
	slash_visual.scale = Vector2(reach_factor, reach_factor)
	var sword := $AttackPivot/WeaponPivot/Sword as Sprite2D
	sword.position.x = GameScale.world(attack_reach * 0.6)
	sword.scale = GameScale.fit_scale(sword.texture.get_size(), visual_size)
	_apply_light()


## The light radius comes from Perception (Stats).
func _apply_light() -> void:
	var light := $Torch as PointLight2D
	light.texture_scale = GameScale.world(stats.get_light_radius()) * 2.0 / light.texture.get_width()


func _physics_process(delta: float) -> void:
	_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)
	_attack_slow_left = maxf(_attack_slow_left - delta, 0.0)
	_swing_left = maxf(_swing_left - delta, 0.0)
	_dodge_cooldown_left = maxf(_dodge_cooldown_left - delta, 0.0)
	_tick_invulnerability(delta)
	_knockback = _knockback.move_toward(Vector2.ZERO, GameScale.world(KNOCKBACK_DECAY) * delta)

	match state:
		State.NORMAL:
			_physics_normal()
		State.DODGE:
			_physics_dodge(delta)
		State.DEAD:
			velocity = _knockback
	move_and_slide()

	if state != State.DEAD:
		animator.face(get_global_mouse_position().x - global_position.x)
		animator.update_motion(velocity, delta)
		_update_weapon()


func _physics_normal() -> void:
	if _swing_left <= 0.0:
		_aim_at_mouse()
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# Shallow water, reeds, quicksand... slow you down.
	var speed: float = GameScale.world(base_move_speed) * stats.get_move_speed_multiplier() \
		* FloorLayout.speed_factor_at(global_position)
	if _attack_slow_left > 0.0:
		speed *= attack_move_factor
	velocity = input_dir * speed + _knockback

	if Input.is_action_just_pressed("attack"):
		_try_attack()
	if Input.is_action_just_pressed("dodge"):
		_try_dodge(input_dir)


func _physics_dodge(delta: float) -> void:
	velocity = _dodge_dir * GameScale.world(dodge_speed) + _knockback
	_dodge_time_left -= delta
	_ghost_left -= delta
	if _ghost_left <= 0.0:
		_ghost_left = GHOST_INTERVAL
		GameFeel.spawn_ghost(sprite, GHOST_TINT)
	if _dodge_time_left <= 0.0:
		_end_dodge()


func _aim_at_mouse() -> void:
	var aim: Vector2 = get_global_mouse_position() - global_position
	if aim.length() > 0.001:
		attack_pivot.rotation = aim.angle()


## Sword rests slightly to one side of the aim; during a swing it sweeps across the arc.
func _update_weapon() -> void:
	if _swing_left > 0.0:
		var progress: float = 1.0 - _swing_left / ATTACK_ACTIVE_TIME
		weapon_pivot.rotation = lerpf(-SWING_HALF_ARC, SWING_HALF_ARC, progress) * _swing_side
	else:
		weapon_pivot.rotation = SWING_HALF_ARC * 0.5 * _swing_side


func _try_attack() -> void:
	if _attack_cooldown_left > 0.0 or not stamina.spend(attack_stamina_cost):
		return
	_aim_at_mouse()
	hitbox.damage = base_attack_damage
	hitbox.knockback_force = GameScale.world(attack_knockback) * stats.get_knockback_multiplier()
	hitbox.activate(ATTACK_ACTIVE_TIME)
	_swing_left = ATTACK_ACTIVE_TIME
	_swing_side = -_swing_side
	_attack_slow_left = ATTACK_SLOW_TIME
	_attack_cooldown_left = base_attack_cooldown / stats.get_attack_speed_multiplier()
	animator.play_attack(ATTACK_SLOW_TIME)


func _try_dodge(input_dir: Vector2) -> void:
	if _dodge_cooldown_left > 0.0 or not stamina.spend(dodge_stamina_cost):
		return
	# Dodge where you are moving; standing still = backstep away from the mouse.
	var dir: Vector2 = input_dir
	if dir == Vector2.ZERO:
		dir = (global_position - get_global_mouse_position()).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	_dodge_dir = dir
	_dodge_time_left = dodge_duration
	_invulnerable_left = stats.get_dodge_invulnerability()
	_dodge_cooldown_left = dodge_cooldown
	_ghost_left = 0.0
	hurtbox.invulnerable = true
	visual.modulate.a = 0.5
	state = State.DODGE


func _end_dodge() -> void:
	state = State.NORMAL


## Dodge invulnerability (from Agility) can last longer or shorter than the dash itself.
func _tick_invulnerability(delta: float) -> void:
	if _invulnerable_left <= 0.0 or state == State.DEAD:
		return
	_invulnerable_left -= delta
	if _invulnerable_left <= 0.0:
		hurtbox.invulnerable = false
		visual.modulate.a = 1.0


func _on_hit_missed() -> void:
	GameFeel.spawn_miss(global_position)


func _set_flash(amount: float) -> void:
	(sprite.material as ShaderMaterial).set_shader_parameter("flash_amount", amount)


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


func _on_died() -> void:
	state = State.DEAD
	hurtbox.invulnerable = true
	hitbox.deactivate()
	visual.modulate = Color(0.55, 0.55, 0.6, 1.0)
	visual.rotation = PI / 2.0
	weapon_pivot.hide()
	_set_flash(0.0)
	died.emit()


## Stats changed in game (character sheet debug buttons, later level ups): refresh what is cached.
func _on_stats_changed() -> void:
	health.set_max_health(stats.get_max_health())
	stamina.set_max_stamina(stats.get_max_stamina())
	_apply_light()
