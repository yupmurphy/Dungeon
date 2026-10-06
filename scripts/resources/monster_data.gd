class_name MonsterData
extends Resource
## Everything that defines one monster type. New monster = new .tres, no new code.

@export var display_name: String = "Monster"
@export var stats: Stats
## XP given the first time this monster type is killed (bestiary, stage 4).
@export var xp_reward: int = 5
## Region this monster belongs to (RegionData.id). Informational; RegionData lists what spawns where.
@export var region_id: StringName = &""
## Behavior components to attach (filled in stage 2). Empty = basic chase + melee.
@export var behaviors: Array[StringName] = []

@export_group("Look")
## Animations "idle", "run", "attack".
@export var sprite_frames: SpriteFrames
## Multiplied over the sprite, so one pack sprite can be reused for several monsters.
@export var sprite_tint: Color = Color.WHITE
@export var art_faces_right: bool = true
## Color of hit/death particles.
@export var body_color: Color = Color(0.45, 0.75, 0.35)
## Sprite is tinted toward this color during the attack wind-up (the visual warning).
@export var windup_color: Color = Color(1.0, 0.15, 0.1)
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
@export var attack_damage: float = 15.0
@export var attack_knockback: float = 200.0

@export_group("Defense")
## 0 = full knockback, 1 = immune.
@export_range(0.0, 1.0) var knockback_resistance: float = 0.0
