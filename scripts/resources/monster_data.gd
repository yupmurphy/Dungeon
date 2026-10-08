class_name MonsterData
extends Resource
## Everything that defines one monster type. New monster = new .tres, no new code.

@export var display_name: String = "Monster"
@export var stats: Stats
## Fixed max health; 0 = from Stats (Strength), like the player. Use it when a monster needs less health than
## the Strength formula can give (e.g. the goblin: 35).
@export var max_health: float = 0.0
## XP given the first time this monster type is killed (bestiary, stage 4).
@export var xp_reward: int = 5
## Region this monster belongs to (RegionData.id). Informational; RegionData lists what spawns where.
@export var region_id: StringName = &""
## Behavior components to attach (filled in stage 2). Empty = basic chase + melee.
@export var behaviors: Array[StringName] = []

@export_group("Look")
## Animations "idle", "run", "attack".
@export var sprite_frames: SpriteFrames
## Or a sheet with one row per facing (LPC monsters): cut by MonsterSheet into idle_/run_/attack_<dir> + death.
## When set, it replaces sprite_frames and the monster faces 4 directions instead of flipping.
@export var sprite_sheet: Texture2D
@export var sheet_frame_size: Vector2i = Vector2i(64, 64)
## Sheet row of each facing, in the order down, left, up, right.
@export var sheet_direction_rows: Array[int] = [0, 1, 2, 3]
@export var sheet_idle_column: int = 0
## First column and frame count.
@export var sheet_run_columns: Vector2i = Vector2i(1, 7)
@export var sheet_attack_columns: Vector2i = Vector2i(8, 3)
@export var sheet_death_row: int = 4
@export var sheet_death_frames: int = 5
## Where the sprite sits from the body center, in reference pixels (LPC feet are low in the frame).
@export var sprite_offset: Vector2 = Vector2.ZERO
## Multiplied over the sprite, so one pack sprite can be reused for several monsters.
@export var sprite_tint: Color = Color.WHITE
@export var art_faces_right: bool = true
## Color of hit/death particles.
@export var body_color: Color = Color(0.45, 0.75, 0.35)
## Sprite is tinted toward this color during the attack wind-up (the visual warning).
@export var windup_color: Color = Color(1.0, 0.15, 0.1)
## Sizes below are in reference pixels (see GameScale). How wide the monster looks on screen:
@export var visual_size: float = 16.0
@export var body_radius: float = 6.0

@export_group("Movement")
@export var move_speed: float = 55.0
@export var detect_range: float = 160.0
## If the player gets farther than this, the enemy gives up the chase.
@export var lose_range: float = 280.0
@export var attack_range: float = 28.0

@export_group("Attack")
@export var windup_time: float = 0.5
@export var attack_active_time: float = 0.15
@export var lunge_speed: float = 170.0
@export var recovery_time: float = 0.8
## Width (reach) x height of the attack hitbox.
@export var attack_size: Vector2 = Vector2(20, 24)
@export var attack_damage: float = 15.0
@export var attack_knockback: float = 200.0

@export_group("Ranged")
## Set = the monster shoots this (e.g. an arrow, pointing right) instead of striking: the wind-up becomes aiming,
## with a line toward the target, then the shot flies. attack_range is then the shooting distance.
@export var projectile_texture: Texture2D
## Reference pixels per second / reference pixels.
@export var projectile_speed: float = 150.0
@export var projectile_range: float = 200.0
## Degrees per second the shot turns toward the target (partly homing); 0 = straight.
@export var projectile_turn_rate: float = 0.0
## Backs away from the target while reloading if it is closer than this.
@export var keep_distance: float = 0.0
## The aim stops following the target this long before the shot, so a sidestep at the right moment dodges it.
@export var aim_lock_time: float = 0.25

@export_group("Defense")
## 0 = full knockback, 1 = immune.
@export_range(0.0, 1.0) var knockback_resistance: float = 0.0

@export_group("Spawning")
## Spawned in groups of this many (min, max), close together.
@export var group_size: Vector2i = Vector2i(1, 1)
## Sometimes a group is led by another kind of monster (e.g. a grown goblin with the young ones).
@export var group_leader: MonsterData
@export_range(0.0, 1.0) var leader_chance: float = 0.0
## Groups also gather around every place of this kind in their zone (FloorLayout feature, e.g. goblin_camp).
@export var home_feature: StringName = &""
@export var groups_per_home: int = 0


func is_ranged() -> bool:
	return projectile_texture != null


func get_max_health() -> float:
	return max_health if max_health > 0.0 else stats.get_max_health()
