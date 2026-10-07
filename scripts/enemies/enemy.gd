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
const LPC_FRAME_SIZE: float = 64.0
const LPC_RUN_THRESHOLD: float = 1.0
const LPC_DEATH_HOLD: float = 0.65
const DEFAULT_BEHAVIORS: Array[StringName] = [&"chase", &"melee"]
const CHASE_BEHAVIOR: Script = preload("res://scripts/components/enemy_chase_behavior.gd")
const MELEE_BEHAVIOR: Script = preload("res://scripts/components/enemy_melee_behavior.gd")

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
var chase_behavior: EnemyChaseBehavior
var melee_behavior: EnemyMeleeBehavior
var character: LpcCharacter

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
	data = data.runtime_copy()

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
	_setup_character()
	_setup_behaviors()
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
	var move: Vector2 = Vector2.ZERO
	match state:
		State.IDLE:
			_tick_idle()
		State.CHASE:
			move = _tick_chase()
		State.WINDUP, State.ATTACK, State.RECOVER:
			if melee_behavior != null:
				move = melee_behavior.tick(delta)
				_state_left = melee_behavior.time_left
		State.DEAD:
			pass

	velocity = move + _knockback
	move_and_slide()
	if state != State.DEAD:
		_update_facing()
		if character == null:
			animator.update_motion(move, delta)
		else:
			_update_lpc_motion(move)
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
	if chase_behavior != null:
		chase_behavior.scan()


func _tick_chase() -> Vector2:
	return chase_behavior.movement(_target) if chase_behavior != null else Vector2.ZERO


func _setup_behaviors() -> void:
	var ids: Array[StringName] = DEFAULT_BEHAVIORS if data.behaviors.is_empty() else data.behaviors
	for id in ids:
		match id:
			&"chase":
				if chase_behavior != null:
					continue
				chase_behavior = CHASE_BEHAVIOR.new() as EnemyChaseBehavior
				chase_behavior.name = "ChaseBehavior"
				add_child(chase_behavior)
				chase_behavior.setup(self, data)
				chase_behavior.target_found.connect(_on_target_found)
				chase_behavior.target_lost.connect(_on_target_lost)
				chase_behavior.attack_requested.connect(_on_attack_requested)
			&"melee":
				if melee_behavior != null:
					continue
				melee_behavior = MELEE_BEHAVIOR.new() as EnemyMeleeBehavior
				melee_behavior.name = "MeleeBehavior"
				add_child(melee_behavior)
				melee_behavior.setup(data)
				melee_behavior.windup_started.connect(_on_windup_started)
				melee_behavior.attack_started.connect(_on_attack_started)
				melee_behavior.recovery_started.connect(_on_recovery_started)
				melee_behavior.cycle_finished.connect(_on_attack_cycle_finished)
			_:
				push_warning("Unknown monster behavior: %s" % id)


func _on_target_found(target: Player) -> void:
	_target = target
	_set_state(State.CHASE, 0.0)


func _on_target_lost() -> void:
	_target = null
	_set_state(State.IDLE, 0.0)


func _on_attack_requested(direction: Vector2) -> void:
	if melee_behavior != null:
		melee_behavior.begin_windup(direction)


func _on_windup_started(direction: Vector2, duration: float) -> void:
	_attack_dir = direction
	_set_state(State.WINDUP, duration)


func _on_attack_started(direction: Vector2, duration: float) -> void:
	attack_pivot.rotation = direction.angle()
	hitbox.activate(duration)
	if character == null:
		animator.play_attack(duration)
	else:
		character.play(character.attack_action(), LpcCharacter.direction_of(direction), duration)
	_set_state(State.ATTACK, duration)


func _on_recovery_started(duration: float) -> void:
	_set_state(State.RECOVER, duration)


func _on_attack_cycle_finished() -> void:
	_set_state(State.CHASE, 0.0)


func _setup_character() -> void:
	if data.lpc_items.is_empty():
		return
	character = LpcCharacter.new()
	character.name = "LpcCharacter"
	character.body_type = data.lpc_body_type
	character.items = data.lpc_items
	character.item_tints = data.lpc_item_tints
	character.layer_material = _shader
	character.scale = Vector2.ONE * GameScale.world(data.visual_size) / LPC_FRAME_SIZE
	visual.add_child(character)
	sprite.hide()


func _update_lpc_motion(move: Vector2) -> void:
	if character.is_busy():
		return
	var action: String = "walk" if move.length() > GameScale.world(LPC_RUN_THRESHOLD) else "idle"
	var facing: Vector2 = _attack_dir if state == State.WINDUP else move
	if facing.is_zero_approx() and is_instance_valid(_target):
		facing = _target.global_position - global_position
	var direction: LpcCatalog.Direction = character.direction if facing.is_zero_approx() else LpcCharacter.direction_of(facing)
	character.loop(action, direction, data.stats.get_move_speed_multiplier())


func _update_facing() -> void:
	if character != null:
		return
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
	if _shader == null:
		return
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
	if character != null:
		character.play("flinch", character.direction)
	if state == State.WINDUP:
		melee_behavior.interrupt(STAGGER_TIME)
	elif state == State.IDLE:
		_target = _find_target()
		_set_state(State.CHASE, 0.0)


func _on_died() -> void:
	_set_state(State.DEAD, 0.0)
	if melee_behavior != null:
		melee_behavior.stop()
	if character != null:
		character.play("death", character.direction)
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
	if character != null:
		tween.tween_interval(LPC_DEATH_HOLD)
	tween.tween_property(visual, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)
