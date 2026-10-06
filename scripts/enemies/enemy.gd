class_name Enemy
extends CharacterBody2D
## Data-driven melee enemy. Chases the player when it sees them, telegraphs its attack by
## shifting color for `windup_time`, lunges, then recovers. Everything tunable lives in EnemyData.

signal died(enemy: Enemy)

enum State { IDLE, CHASE, WINDUP, ATTACK, RECOVER, DEAD }

const KNOCKBACK_DECAY: float = 800.0
const STAGGER_TIME: float = 0.35
const HIT_FLASH_TIME: float = 0.1

@export var data: EnemyData

var state: State = State.IDLE

var _state_left: float = 0.0
var _target: Player
var _knockback: Vector2 = Vector2.ZERO
var _attack_dir: Vector2 = Vector2.RIGHT
var _flash_left: float = 0.0

@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var attack_pivot: Node2D = $AttackPivot
@onready var hitbox: Hitbox = $AttackPivot/Hitbox
@onready var swing_visual: Polygon2D = $AttackPivot/Hitbox/SwingVisual
@onready var visual: Node2D = $Visual
@onready var body: ColorRect = $Visual/Body
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var hurtbox_shape: CollisionShape2D = $Hurtbox/CollisionShape2D


func _ready() -> void:
	if data == null:
		data = EnemyData.new()
	if data.stats == null:
		data.stats = Stats.new()

	var radius: float = data.body_radius
	(body_shape.shape as CircleShape2D).radius = radius
	(hurtbox_shape.shape as CircleShape2D).radius = radius + 1.0
	body.size = Vector2.ONE * radius * 2.0
	body.position = -Vector2.ONE * radius
	body.color = data.body_color
	hitbox.position.x = radius + 9.0
	hitbox.damage = data.attack_damage * data.stats.get_damage_multiplier()
	hitbox.knockback_force = data.attack_knockback

	health.setup(data.stats.get_max_health())
	health.died.connect(_on_died)
	hurtbox.hit_received.connect(_on_hit_received)
	hitbox.activated.connect(swing_visual.show)
	hitbox.deactivated.connect(swing_visual.hide)


func _physics_process(delta: float) -> void:
	_knockback = _knockback.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)
	_flash_left = maxf(_flash_left - delta, 0.0)
	_state_left -= delta

	var move: Vector2 = Vector2.ZERO
	match state:
		State.IDLE:
			_tick_idle()
		State.CHASE:
			move = _tick_chase()
		State.WINDUP:
			if _state_left <= 0.0:
				_begin_attack()
		State.ATTACK:
			move = _attack_dir * data.lunge_speed
			if _state_left <= 0.0:
				_set_state(State.RECOVER, data.recovery_time / data.stats.get_attack_speed_multiplier())
		State.RECOVER:
			if _state_left <= 0.0:
				_set_state(State.CHASE, 0.0)
		State.DEAD:
			pass

	velocity = move + _knockback
	move_and_slide()
	_update_color()


func _set_state(new_state: State, duration: float) -> void:
	state = new_state
	_state_left = duration


func _find_target() -> Player:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null and not player.is_dead:
		return player
	return null


func _tick_idle() -> void:
	_target = _find_target()
	if _target != null and global_position.distance_to(_target.global_position) <= data.detect_range:
		_set_state(State.CHASE, 0.0)


func _tick_chase() -> Vector2:
	if not is_instance_valid(_target) or _target.is_dead:
		_target = null
		_set_state(State.IDLE, 0.0)
		return Vector2.ZERO
	var to_target: Vector2 = _target.global_position - global_position
	var distance: float = to_target.length()
	if distance > data.lose_range:
		_target = null
		_set_state(State.IDLE, 0.0)
		return Vector2.ZERO
	if distance <= data.attack_range:
		# Direction is locked now, so a player who moves away can dodge the attack.
		_attack_dir = to_target.normalized()
		_set_state(State.WINDUP, data.windup_time)
		return Vector2.ZERO
	return to_target.normalized() * data.move_speed * data.stats.get_move_speed_multiplier()


func _begin_attack() -> void:
	attack_pivot.rotation = _attack_dir.angle()
	hitbox.activate(data.attack_active_time)
	_set_state(State.ATTACK, data.attack_active_time)


func _update_color() -> void:
	if _flash_left > 0.0:
		body.color = Color.WHITE
	elif state == State.WINDUP:
		var progress: float = 1.0 - clampf(_state_left / maxf(data.windup_time, 0.01), 0.0, 1.0)
		body.color = data.body_color.lerp(data.windup_color, progress)
	elif state == State.ATTACK:
		body.color = data.windup_color
	else:
		body.color = data.body_color


func _on_hit_received(_damage: float, knockback: Vector2) -> void:
	_knockback = knockback * (1.0 - data.knockback_resistance)
	if state == State.DEAD:
		return
	_flash_left = HIT_FLASH_TIME
	if state == State.WINDUP:
		_set_state(State.RECOVER, STAGGER_TIME)
	elif state == State.IDLE:
		_target = _find_target()
		_set_state(State.CHASE, 0.0)


func _on_died() -> void:
	_set_state(State.DEAD, 0.0)
	hurtbox.invulnerable = true
	hitbox.deactivate()
	# Deferred: we are probably inside a physics callback (the player's hit).
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	died.emit(self)
	var tween: Tween = create_tween()
	tween.tween_property(visual, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)
