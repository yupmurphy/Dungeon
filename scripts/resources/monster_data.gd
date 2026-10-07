class_name MonsterData
extends Resource
## Everything that defines one monster type. New monster = new .tres, no new code.

const DEFAULT_GROUP_SPREAD_TILES: int = 2
const DEFAULT_SPAWN_RADIUS_TILES: float = 35.0

@export var id: StringName = &""
@export var name_key: StringName = &""
@export var display_name: String = "Monster"
@export var stats: Stats
## Species bases, before the Strength bonuses; -1 preserves existing defaults.
@export var base_health: float = Stats.USE_DEFAULT_BASE
@export var base_defense: float = Stats.USE_DEFAULT_BASE
## XP given the first time this monster type is killed (bestiary, stage 4).
@export var xp_reward: int = 5
## Region this monster belongs to (RegionData.id). Informational; RegionData lists what spawns where.
@export var region_id: StringName = &""
## Reusable child behavior ids. Empty preserves basic chase + telegraphed melee.
@export var behaviors: Array[StringName] = []

@export_group("Ecology")
## Empty = ordinary zone population; otherwise groups originate from this feature kind.
@export var spawn_feature: StringName = &""
@export var spawn_group_size: Vector2i = Vector2i.ONE
@export var spawn_radius_tiles: float = DEFAULT_SPAWN_RADIUS_TILES
@export var group_spread_tiles: int = DEFAULT_GROUP_SPREAD_TILES

@export_group("Look")
## Empty = legacy SpriteFrames; otherwise use the existing LPC paper-doll component.
@export var lpc_body_type: String = "male"
@export var lpc_items: Array[String] = []
## Optional per-item colors (for example, tint only the body, never the weapon/clothes).
@export var lpc_item_tints: Dictionary = {}
## Animations "idle", "run", "attack".
@export var sprite_frames: SpriteFrames
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

@export_group("Defense")
## 0 = full knockback, 1 = immune.
@export_range(0.0, 1.0) var knockback_resistance: float = 0.0


## Each enemy gets independent stats, so species bases never change the shared .tres/player.
func runtime_copy() -> MonsterData:
	var runtime := duplicate(false) as MonsterData
	runtime.stats = stats.duplicate(true) as Stats if stats != null else Stats.new()
	runtime.stats.configure_monster_bases(base_health, base_defense)
	return runtime


func localized_name() -> String:
	return tr(name_key) if not String(name_key).is_empty() else display_name
