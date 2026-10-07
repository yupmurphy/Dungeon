class_name Player
extends CharacterBody2D
## Top-down player: 8-direction movement, sprint (Shift), mouse-aimed melee attack.
## Sprint and attacks raise exhaustion (ExhaustionComponent). All numbers scale through Stats.
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
	exhaustion.add(ExhaustionComponent.ATTACK_COST)
	_aim_at_mouse()
	# Exhausted (reached 100, not yet below 70) = less damage.
	hitbox.damage = base_attack_damage * exhaustion.damage_factor()
	hitbox.knockback_force = GameScale.world(attack_knockback) * stats.get_knockback_multiplier()
	hitbox.activate(ATTACK_ACTIVE_TIME)
	_swing_left = ATTACK_ACTIVE_TIME
	_attack_slow_left = ATTACK_SLOW_TIME
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
