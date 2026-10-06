class_name EnemyData
extends Resource
## Everything that defines one monster type. New monster = new .tres, no new code.

@export var display_name: String = "Grunt"
@export var stats: Stats

@export_group("Look")
## Animations "idle", "run", "attack".
@export var sprite_frames: SpriteFrames
@export var art_faces_right: bool = true
## Color of hit/death particles.
@export var body_color: Color = Color(0.45, 0.75, 0.35)
## Sprite is tinted toward this color during the attack wind-up (the visual warning).
@export var windup_color: Color = Color(1.0, 0.15, 0.1)
@export var body_radius: float = 6.0

@export_group("Behavior")
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
