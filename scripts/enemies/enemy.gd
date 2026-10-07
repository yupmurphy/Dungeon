class_name Enemy
extends CharacterBody2D
## Data-driven melee enemy. Chases the player when it sees them, telegraphs its attack by
## turning red for `windup_time`, lunges, then recovers. Everything tunable lives in MonsterData.

signal died(enemy: Enemy)

enum State { IDLE, CHASE, WINDUP, ATTACK, RECOVER, DEAD }

const KNOCKBACK_DECAY: float = 800.0
const STAGGER_TIME: float = 0.35
const HIT_FLASH_TIME: float = 0.1
const MAX_WINDUP_TINT: float = 0.75
const HIT_STOP_TIME: float = 0.05
const HIT_SHAKE: float = 2.0
const DEATH_SHAKE: float = 3.5
const DAMAGE_DEALT_COLOR: Color = Color(1.0, 0.95, 0.6)
const SPARK_COLOR: Color = Color(1.0, 0.95, 0.8)
## Reference pixels: monsters fade in over this distance at the edge of the player's sight radius (Perception).
const SIGHT_FADE: float = 20.0

@export var data: MonsterData

var state: State = State.IDLE

var _state_left: float = 0.0
var _target: Player
var _knockback: Vector2 = Vector2.ZERO
var _attack_dir: Vector2 = Vector2.RIGHT
var _flash_left: float = 0.0
var _shader: ShaderMaterial
## Whoever looks at us (the player), for the Perception sight radius.
var _viewer: Player

@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var attack_pivot: Node2D = $AttackPivot
@onready var hitbox: Hitbox = $AttackPivot/Hitbox
@onready var slash_visual: Polygon2D = $AttackPivot/Hitbox/SlashVisual
@onready var visual: Node2D = $Visual
@onready var sprite: AnimatedSprite2D = $Visual/Sprite
@onready var animator: SpriteAnimator = $SpriteAnimator
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var hurtbox_shape: CollisionShape2D = $Hurtbox/CollisionShape2D


func _ready() -> void:
	if data == null:
		data = MonsterData.new()
	if data.stats == null:
		data.stats = Stats.new()

	# Sizes come from the data in reference pixels (see GameScale).
	var radius: float = GameScale.world(data.body_radius)
	(body_shape.shape as CircleShape2D).radius = radius
	(hurtbox_shape.shape as CircleShape2D).radius = radius + GameScale.world(1.0)
	if data.sprite_frames != null:
		sprite.sprite_frames = data.sprite_frames
		sprite.play(&"idle")
	animator.fit_to(data.visual_size)
	sprite.modulate = data.sprite_tint
	animator.art_faces_right = data.art_faces_right
	_shader = sprite.material as ShaderMaterial
	var attack_size: Vector2 = GameScale.world_vector(data.attack_size)
	(hitbox.get_node("CollisionShape2D").shape as RectangleShape2D).size = attack_size
	hitbox.position.x = radius + attack_size.x / 2.0 - GameScale.world(1.0)
	# The slash polygon is drawn for a 20 px wide attack.
	slash_visual.scale = Vector2.ONE * attack_size.x / 20.0
	hitbox.damage = data.attack_damage
	hitbox.attacker = data.stats
	hurtbox.defender = data.stats
	hitbox.knockback_force = GameScale.world(data.attack_knockback) * data.stats.get_knockback_multiplier()

	health.setup(data.stats.get_max_health())
	health.died.connect(_on_died)
	hurtbox.hit_received.connect(_on_hit_received)
	hurtbox.hit_missed.connect(_on_hit_missed)
	hitbox.activated.connect(slash_visual.show)
	hitbox.deactivated.connect(slash_visual.hide)
	# Health bar and name, shown by the player's Perception.
	var info := EnemyInfo.new()
	info.enemy = self
	GameFeel.add_overlay(info)
	_update_visibility()


func _process(_delta: float) -> void:
	_update_visibility()


## Only seen inside the player's sight radius (Perception), with a short fade at its edge.
func _update_visibility() -> void:
	if not is_instance_valid(_viewer):
		_viewer = get_tree().get_first_node_in_group("player") as Player
		if _viewer == null or _viewer.stats == null:
			return
	var radius: float = GameScale.world(_viewer.stats.get_sight_radius())
	var distance: float = global_position.distance_to(_viewer.global_position)
	modulate.a = clampf((radius - distance) / GameScale.world(SIGHT_FADE) + 1.0, 0.0, 1.0)


func _on_hit_missed() -> void:
	GameFeel.spawn_miss(global_position)


func _physics_process(delta: float) -> void:
	_knockback = _knockback.move_toward(Vector2.ZERO, GameScale.world(KNOCKBACK_DECAY) * delta)
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
			move = _attack_dir * GameScale.world(data.lunge_speed)
			if _state_left <= 0.0:
				_set_state(State.RECOVER, data.recovery_time / data.stats.get_attack_speed_multiplier())
		State.RECOVER:
			if _state_left <= 0.0:
				_set_state(State.CHASE, 0.0)
		State.DEAD:
			pass

	velocity = move + _knockback
	move_and_slide()
	if state != State.DEAD:
		_update_facing()
		animator.update_motion(move, delta)
	_update_tint()


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
	if _target != null and global_position.distance_to(_target.global_position) <= GameScale.world(data.detect_range):
		_set_state(State.CHASE, 0.0)


func _tick_chase() -> Vector2:
	if not is_instance_valid(_target) or _target.is_dead:
		_target = null
		_set_state(State.IDLE, 0.0)
		return Vector2.ZERO
	var to_target: Vector2 = _target.global_position - global_position
	var distance: float = to_target.length()
	if distance > GameScale.world(data.lose_range):
		_target = null
		_set_state(State.IDLE, 0.0)
		return Vector2.ZERO
	if distance <= GameScale.world(data.attack_range):
		# Direction is locked now, so a player who moves away can dodge the attack.
		_attack_dir = to_target.normalized()
		_set_state(State.WINDUP, data.windup_time)
		return Vector2.ZERO
	return to_target.normalized() * GameScale.world(data.move_speed) * data.stats.get_move_speed_multiplier() \
		* FloorLayout.speed_factor_at(global_position)


func _begin_attack() -> void:
	attack_pivot.rotation = _attack_dir.angle()
	hitbox.activate(data.attack_active_time)
	animator.play_attack(data.attack_active_time)
	_set_state(State.ATTACK, data.attack_active_time)


func _update_facing() -> void:
	if state in [State.WINDUP, State.ATTACK]:
		animator.face(_attack_dir.x)
	elif is_instance_valid(_target):
		animator.face(_target.global_position.x - global_position.x)


func _update_tint() -> void:
	if _flash_left > 0.0:
		_set_tint(Color.WHITE, 1.0)
	elif state == State.WINDUP:
		var progress: float = 1.0 - clampf(_state_left / maxf(data.windup_time, 0.01), 0.0, 1.0)
		_set_tint(data.windup_color, progress * MAX_WINDUP_TINT)
	elif state == State.ATTACK:
		_set_tint(data.windup_color, MAX_WINDUP_TINT)
	else:
		_set_tint(Color.WHITE, 0.0)


func _set_tint(color: Color, amount: float) -> void:
	_shader.set_shader_parameter("flash_color", color)
	_shader.set_shader_parameter("flash_amount", amount)


func _on_hit_received(damage: float, knockback: Vector2, critical: bool) -> void:
	_knockback = knockback * (1.0 - data.knockback_resistance)
	GameFeel.hit_stop(HIT_STOP_TIME)
	GameFeel.shake(HIT_SHAKE)
	GameFeel.spawn_damage_number(global_position, damage, DAMAGE_DEALT_COLOR, critical)
	GameFeel.spawn_burst(global_position, SPARK_COLOR, 6, 90.0)
	_flash_left = HIT_FLASH_TIME
	if state == State.DEAD:
		return
	if state == State.WINDUP:
		_set_state(State.RECOVER, STAGGER_TIME)
	elif state == State.IDLE:
		_target = _find_target()
		_set_state(State.CHASE, 0.0)


func _on_died() -> void:
	_set_state(State.DEAD, 0.0)
	# Out of the "enemy" group so EnemyActivator can't pause it mid fade-out (it would never be freed).
	remove_from_group("enemy")
	process_mode = Node.PROCESS_MODE_INHERIT
	hurtbox.invulnerable = true
	hitbox.deactivate()
	# Deferred: we are probably inside a physics callback (the player's hit).
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	GameFeel.shake(DEATH_SHAKE)
	GameFeel.spawn_burst(global_position, data.body_color, 18, 120.0)
	died.emit(self)
	var tween: Tween = create_tween()
	tween.tween_property(visual, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)
