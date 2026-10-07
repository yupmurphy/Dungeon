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

# --- Combat (temporary: the old effects, relative to STARTING_VALUE; stage 2 replaces them) ---
const DAMAGE_PER_STRENGTH: float = 0.05
const ATTACK_SPEED_PER_AGILITY: float = 0.04
const MOVE_SPEED_PER_AGILITY: float = 0.01
const DODGE_LENGTH_PER_AGILITY: float = 0.03
const MIN_MULTIPLIER: float = 0.2

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


func get_damage_multiplier() -> float:
	return _multiplier(strength, DAMAGE_PER_STRENGTH)


func get_attack_speed_multiplier() -> float:
	return _multiplier(agility, ATTACK_SPEED_PER_AGILITY)


func get_move_speed_multiplier() -> float:
	return _multiplier(agility, MOVE_SPEED_PER_AGILITY)


func get_dodge_length_multiplier() -> float:
	return _multiplier(agility, DODGE_LENGTH_PER_AGILITY)


func _multiplier(stat: int, per_point: float) -> float:
	return maxf(MIN_MULTIPLIER, 1.0 + (stat - STARTING_VALUE) * per_point)
