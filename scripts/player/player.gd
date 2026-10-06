class_name Player
extends CharacterBody2D
## Top-down player: 8-direction movement, mouse-aimed melee attack, dodge with i-frames.
## Attack and dodge both cost stamina. All numbers scale through Stats.

signal died

enum State { NORMAL, DODGE, DEAD }

const ATTACK_ACTIVE_TIME: float = 0.12
const ATTACK_SLOW_TIME: float = 0.2
const KNOCKBACK_DECAY: float = 900.0
const DEAD_COLOR: Color = Color(0.35, 0.35, 0.4)

@export var stats: Stats

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
@export var base_dodge_duration: float = 0.18
@export var dodge_cooldown: float = 0.6
@export var dodge_stamina_cost: float = 25.0

var state: State = State.NORMAL
var is_dead: bool:
	get:
		return state == State.DEAD

var _attack_cooldown_left: float = 0.0
var _attack_slow_left: float = 0.0
var _swing_left: float = 0.0
var _dodge_cooldown_left: float = 0.0
var _dodge_time_left: float = 0.0
var _dodge_dir: Vector2 = Vector2.ZERO
var _knockback: Vector2 = Vector2.ZERO
var _base_color: Color

@onready var health: HealthComponent = $HealthComponent
@onready var stamina: StaminaComponent = $StaminaComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var attack_pivot: Node2D = $AttackPivot
@onready var hitbox: Hitbox = $AttackPivot/Hitbox
@onready var swing_visual: Polygon2D = $AttackPivot/Hitbox/SwingVisual
@onready var visual: Node2D = $Visual
@onready var body: ColorRect = $Visual/Body


func _ready() -> void:
	if stats == null:
		stats = Stats.new()
	_base_color = body.color
	health.setup(stats.get_max_health())
	health.died.connect(_on_died)
	hurtbox.hit_received.connect(_on_hit_received)
	hitbox.activated.connect(swing_visual.show)
	hitbox.deactivated.connect(swing_visual.hide)


func _physics_process(delta: float) -> void:
	_attack_cooldown_left = maxf(_attack_cooldown_left - delta, 0.0)
	_attack_slow_left = maxf(_attack_slow_left - delta, 0.0)
	_swing_left = maxf(_swing_left - delta, 0.0)
	_dodge_cooldown_left = maxf(_dodge_cooldown_left - delta, 0.0)
	_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)

	match state:
		State.NORMAL:
			_physics_normal()
		State.DODGE:
			_physics_dodge(delta)
		State.DEAD:
			velocity = _knockback
	move_and_slide()


func _physics_normal() -> void:
	if _swing_left <= 0.0:
		_aim_at_mouse()
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var speed: float = base_move_speed * stats.get_move_speed_multiplier()
	if _attack_slow_left > 0.0:
		speed *= attack_move_factor
	velocity = input_dir * speed + _knockback

	if Input.is_action_just_pressed("attack"):
		_try_attack()
	if Input.is_action_just_pressed("dodge"):
		_try_dodge(input_dir)


func _physics_dodge(delta: float) -> void:
	velocity = _dodge_dir * dodge_speed + _knockback
	_dodge_time_left -= delta
	if _dodge_time_left <= 0.0:
		_end_dodge()


func _aim_at_mouse() -> void:
	var aim: Vector2 = get_global_mouse_position() - global_position
	if aim.length() > 0.001:
		attack_pivot.rotation = aim.angle()


func _try_attack() -> void:
	if _attack_cooldown_left > 0.0 or not stamina.spend(attack_stamina_cost):
		return
	_aim_at_mouse()
	hitbox.damage = base_attack_damage * stats.get_damage_multiplier()
	hitbox.knockback_force = attack_knockback
	hitbox.activate(ATTACK_ACTIVE_TIME)
	_swing_left = ATTACK_ACTIVE_TIME
	_attack_slow_left = ATTACK_SLOW_TIME
	_attack_cooldown_left = base_attack_cooldown / stats.get_attack_speed_multiplier()


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
	_dodge_time_left = base_dodge_duration * stats.get_dodge_length_multiplier()
	_dodge_cooldown_left = dodge_cooldown
	hurtbox.invulnerable = true
	visual.modulate.a = 0.4
	state = State.DODGE


func _end_dodge() -> void:
	hurtbox.invulnerable = false
	visual.modulate.a = 1.0
	state = State.NORMAL


func _on_hit_received(_damage: float, knockback: Vector2) -> void:
	_knockback = knockback
	if state == State.DEAD:
		return
	body.color = Color.WHITE
	create_tween().tween_property(body, "color", _base_color, 0.15)


func _on_died() -> void:
	state = State.DEAD
	hurtbox.invulnerable = true
	hitbox.deactivate()
	visual.modulate.a = 1.0
	body.color = DEAD_COLOR
	died.emit()
