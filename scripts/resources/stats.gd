class_name Stats
extends Resource
## The main stats of a character or monster (player and monsters use the same system).
## Only the main stats are stored; every derived value (health, mana, speeds...) is computed
## from them by the getters below, so rebalancing = editing the constants here or a .tres file.

enum Stat { STRENGTH, AGILITY, MAGIC, INTELLIGENCE, PERCEPTION, LUCK }

## Every stat starts here for a new character (and is the default for monsters).
const STARTING_VALUE: int = 5
const MIN_VALUE: int = 0

## Property name of each stat, indexed by Stat.
const PROPERTY_NAMES: Array[StringName] = [&"strength", &"agility", &"magic", &"intelligence", &"perception",
	&"luck"]

# --- Pools: health from Strength, mana from Magic (0 while Magic is locked) ---
const HEALTH_BASE: float = 50.0
const HEALTH_PER_STRENGTH: float = 10.0
const MANA_BASE: float = 20.0
const MANA_PER_MAGIC: float = 5.0

# --- General damage bonus: each of these stats adds this much damage per point (0.01 = +1%) ---
const DAMAGE_BONUS_PER_STRENGTH: float = 0.01
const DAMAGE_BONUS_PER_AGILITY: float = 0.01
const DAMAGE_BONUS_PER_MAGIC: float = 0.01
const DAMAGE_BONUS_PER_PERCEPTION: float = 0.01

# --- Magic (locked until a story event) ---
## Magic starts here, even for a new character.
const MAGIC_STARTING_VALUE: int = 0
## Magic damage (spells, later): +4% per point.
const MAGIC_DAMAGE_PER_MAGIC: float = 0.04

# --- Strength ---
const DEFENSE_PER_STRENGTH: float = 0.5
const CARRY_WEIGHT_BASE: float = 20.0
const CARRY_WEIGHT_PER_STRENGTH: float = 3.0
## Knockback of your attacks: x (1 + this per point).
const KNOCKBACK_PER_STRENGTH: float = 0.03
## Exhaustion gained x (1 - this per point), never less than EXHAUSTION_GAIN_MIN (Strength).
const EXHAUSTION_GAIN_PER_STRENGTH: float = 0.01
const EXHAUSTION_GAIN_MIN: float = 0.1

# --- Agility ---
const ATTACK_SPEED_PER_AGILITY: float = 0.03
## Movement speed, no upper limit.
const MOVE_SPEED_PER_AGILITY: float = 0.01
## Chance that an enemy's hit misses you.
const EVADE_PER_AGILITY: float = 0.01
const EVADE_MAX: float = 0.8
## Dash distance and dash attack power: x (1 + this per point).
const DASH_POWER_PER_AGILITY: float = 0.05

# --- Perception ---
const CRIT_CHANCE_PER_PERCEPTION: float = 0.01
const CRIT_CHANCE_MAX: float = 1.0
## Damage of a critical hit, fixed (1.5 = 150%).
const CRITICAL_DAMAGE: float = 1.5
## Radius (reference pixels, 16 = one tile) in which you see monsters (and traps, later).
const SIGHT_RADIUS_BASE: float = 90.0
const SIGHT_RADIUS_PER_PERCEPTION: float = 6.0
const SIGHT_RADIUS_MAX: float = 240.0
## Light around the player (reference pixels): how far you see in the dark.
const LIGHT_RADIUS_BASE: float = 70.0
const LIGHT_RADIUS_PER_PERCEPTION: float = 6.0
## Capped near the screen size: a bigger light shows nothing more and makes the game heavier.
const LIGHT_RADIUS_MAX: float = 192.0
## Tiles revealed on the map around the player (with line of sight). Capped: big radii cost time on every step.
const REVEAL_RADIUS_BASE: float = 7.0
const REVEAL_RADIUS_PER_PERCEPTION: float = 0.4
const REVEAL_RADIUS_MAX: int = 16
## From this much Perception you see monster health bars, then also their names (colored by power).
const MONSTER_HEALTH_BAR_PERCEPTION: int = 10
const MONSTER_NAME_PERCEPTION: int = 20

# --- Damage taken = damage x DEFENSE_SCALE / (DEFENSE_SCALE + defense) ---
const DEFENSE_SCALE: float = 100.0

@export var strength: int = STARTING_VALUE:
	set(value):
		strength = maxi(value, MIN_VALUE)
		emit_changed()
@export var agility: int = STARTING_VALUE:
	set(value):
		agility = maxi(value, MIN_VALUE)
		emit_changed()
@export var magic: int = MAGIC_STARTING_VALUE:
	set(value):
		magic = maxi(value, MIN_VALUE)
		emit_changed()
## False until a story event; while locked Magic cannot be raised and gives no mana.
@export var magic_unlocked: bool = false:
	set(value):
		magic_unlocked = value
		emit_changed()
## Passive: no combat effect (later: item appraisal, learning spells).
@export var intelligence: int = STARTING_VALUE:
	set(value):
		intelligence = maxi(value, MIN_VALUE)
		emit_changed()
@export var perception: int = STARTING_VALUE:
	set(value):
		perception = maxi(value, MIN_VALUE)
		emit_changed()
## No effect yet (comes later), it only exists as a value.
@export var luck: int = STARTING_VALUE:
	set(value):
		luck = maxi(value, MIN_VALUE)
		emit_changed()


func get_stat(stat: Stat) -> int:
	return get(PROPERTY_NAMES[stat])


func set_stat(stat: Stat, value: int) -> void:
	set(PROPERTY_NAMES[stat], value)


## Locked Magic cannot be raised.
func add_stat(stat: Stat, amount: int) -> void:
	if stat == Stat.MAGIC and not magic_unlocked:
		return
	set_stat(stat, get_stat(stat) + amount)


# --- Derived values ---

func get_max_health() -> float:
	return maxf(1.0, HEALTH_BASE + strength * HEALTH_PER_STRENGTH)


func get_max_mana() -> float:
	if not magic_unlocked:
		return 0.0
	return maxf(0.0, MANA_BASE + magic * MANA_PER_MAGIC)


## General damage bonus (0.2 = +20%), from Strength, Agility, Magic and Perception.
func get_damage_bonus() -> float:
	return strength * DAMAGE_BONUS_PER_STRENGTH + agility * DAMAGE_BONUS_PER_AGILITY \
		+ magic * DAMAGE_BONUS_PER_MAGIC + perception * DAMAGE_BONUS_PER_PERCEPTION


## Magic damage bonus (0.2 = +20%), for spells (later).
func get_magic_damage_bonus() -> float:
	return magic * MAGIC_DAMAGE_PER_MAGIC


func get_defense() -> float:
	return strength * DEFENSE_PER_STRENGTH


func get_carry_weight() -> float:
	return CARRY_WEIGHT_BASE + strength * CARRY_WEIGHT_PER_STRENGTH


func get_knockback_multiplier() -> float:
	return 1.0 + strength * KNOCKBACK_PER_STRENGTH


func get_attack_speed_multiplier() -> float:
	return 1.0 + agility * ATTACK_SPEED_PER_AGILITY


func get_move_speed_multiplier() -> float:
	return 1.0 + agility * MOVE_SPEED_PER_AGILITY


## Dash distance and dash attack damage multiplier (1.25 = 25% farther and stronger).
func get_dash_power_multiplier() -> float:
	return 1.0 + agility * DASH_POWER_PER_AGILITY


## Chance (0..1) that an enemy's hit misses this character.
func get_evade_chance() -> float:
	return minf(agility * EVADE_PER_AGILITY, EVADE_MAX)


## Multiplier for every exhaustion gain (sprint, attacks, dashes), from Strength.
func get_exhaustion_gain_multiplier() -> float:
	return maxf(1.0 - strength * EXHAUSTION_GAIN_PER_STRENGTH, EXHAUSTION_GAIN_MIN)


## Chance (0..1) that this character's hit is critical.
func get_crit_chance() -> float:
	return minf(perception * CRIT_CHANCE_PER_PERCEPTION, CRIT_CHANCE_MAX)


## Radius in reference pixels (convert with GameScale.world) in which monsters (and traps, later) are visible.
func get_sight_radius() -> float:
	return minf(SIGHT_RADIUS_BASE + perception * SIGHT_RADIUS_PER_PERCEPTION, SIGHT_RADIUS_MAX)


## Radius of the player's light, in reference pixels.
func get_light_radius() -> float:
	return minf(LIGHT_RADIUS_BASE + perception * LIGHT_RADIUS_PER_PERCEPTION, LIGHT_RADIUS_MAX)


## Map tiles revealed around the player.
func get_reveal_radius() -> int:
	return mini(floori(REVEAL_RADIUS_BASE + perception * REVEAL_RADIUS_PER_PERCEPTION), REVEAL_RADIUS_MAX)


func shows_monster_health_bars() -> bool:
	return perception >= MONSTER_HEALTH_BAR_PERCEPTION


func shows_monster_names() -> bool:
	return perception >= MONSTER_NAME_PERCEPTION
