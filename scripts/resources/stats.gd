class_name Stats
extends Resource
## The six main stats of a character or monster (player and monsters use the same system).
## Only the main stats are stored; every derived value (health, stamina, mana, speeds...) is computed
## from them by the getters below, so rebalancing = editing the constants here or a .tres file.

enum Stat { STRENGTH, AGILITY, VITALITY, INTELLIGENCE, PERCEPTION, LUCK }

## Every stat starts here for a new character (and is the default for monsters).
const STARTING_VALUE: int = 5
const MIN_VALUE: int = 0

## Property name of each stat, indexed by Stat.
const PROPERTY_NAMES: Array[StringName] = [&"strength", &"agility", &"vitality", &"intelligence",
	&"perception", &"luck"]

# --- Pools ---
const HEALTH_BASE: float = 50.0
const HEALTH_PER_VITALITY: float = 10.0
const STAMINA_BASE: float = 50.0
const STAMINA_PER_VITALITY: float = 4.0
const MANA_BASE: float = 20.0
const MANA_PER_INTELLIGENCE: float = 5.0

# --- General damage bonus: each of these stats adds this much damage per point (0.01 = +1%) ---
const DAMAGE_BONUS_PER_STRENGTH: float = 0.01
const DAMAGE_BONUS_PER_AGILITY: float = 0.01
const DAMAGE_BONUS_PER_INTELLIGENCE: float = 0.01
const DAMAGE_BONUS_PER_PERCEPTION: float = 0.01

# --- Strength ---
const DEFENSE_PER_STRENGTH: float = 0.5
const CARRY_WEIGHT_BASE: float = 20.0
const CARRY_WEIGHT_PER_STRENGTH: float = 3.0
## Knockback of your attacks: x (1 + this per point).
const KNOCKBACK_PER_STRENGTH: float = 0.03

# --- Agility ---
const ATTACK_SPEED_PER_AGILITY: float = 0.03
## Movement speed, no upper limit.
const MOVE_SPEED_PER_AGILITY: float = 0.01
## Chance that an enemy's hit misses you.
const EVADE_PER_AGILITY: float = 0.01
const EVADE_MAX: float = 0.8
## Seconds of invulnerability when you dodge.
const DODGE_INVULNERABILITY_BASE: float = 0.13
const DODGE_INVULNERABILITY_PER_AGILITY: float = 0.01

# --- Vitality ---
## Poison lasts x (1 - this per point), never less than POISON_DURATION_MIN.
const POISON_DURATION_PER_VITALITY: float = 0.03
const POISON_DURATION_MIN: float = 0.1

# --- Perception ---
const CRIT_CHANCE_PER_PERCEPTION: float = 0.01
const CRIT_CHANCE_MAX: float = 1.0
## Damage of a critical hit, fixed (1.5 = 150%).
const CRITICAL_DAMAGE: float = 1.5
## Radius (reference pixels, 16 = one tile) in which you see monsters (and traps, later).
const SIGHT_RADIUS_BASE: float = 90.0
const SIGHT_RADIUS_PER_PERCEPTION: float = 6.0

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
@export var vitality: int = STARTING_VALUE:
	set(value):
		vitality = maxi(value, MIN_VALUE)
		emit_changed()
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


func add_stat(stat: Stat, amount: int) -> void:
	set_stat(stat, get_stat(stat) + amount)


# --- Derived values ---

func get_max_health() -> float:
	return maxf(1.0, HEALTH_BASE + vitality * HEALTH_PER_VITALITY)


func get_max_stamina() -> float:
	return maxf(1.0, STAMINA_BASE + vitality * STAMINA_PER_VITALITY)


func get_max_mana() -> float:
	return maxf(0.0, MANA_BASE + intelligence * MANA_PER_INTELLIGENCE)


## General damage bonus (0.2 = +20%), from Strength, Agility, Intelligence and Perception.
func get_damage_bonus() -> float:
	return strength * DAMAGE_BONUS_PER_STRENGTH + agility * DAMAGE_BONUS_PER_AGILITY \
		+ intelligence * DAMAGE_BONUS_PER_INTELLIGENCE + perception * DAMAGE_BONUS_PER_PERCEPTION


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


## Chance (0..1) that an enemy's hit misses this character.
func get_evade_chance() -> float:
	return minf(agility * EVADE_PER_AGILITY, EVADE_MAX)


func get_dodge_invulnerability() -> float:
	return DODGE_INVULNERABILITY_BASE + agility * DODGE_INVULNERABILITY_PER_AGILITY


## Multiplier for how long poison lasts (no poison yet; ready for it).
func get_poison_duration_multiplier() -> float:
	return maxf(1.0 - vitality * POISON_DURATION_PER_VITALITY, POISON_DURATION_MIN)


## Chance (0..1) that this character's hit is critical.
func get_crit_chance() -> float:
	return minf(perception * CRIT_CHANCE_PER_PERCEPTION, CRIT_CHANCE_MAX)


## Radius in reference pixels (convert with GameScale.world) in which monsters (and traps, later) are visible.
func get_sight_radius() -> float:
	return SIGHT_RADIUS_BASE + perception * SIGHT_RADIUS_PER_PERCEPTION
