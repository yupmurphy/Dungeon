class_name Stats
extends Resource
## Core attributes of a character or monster.
## Every derived number (health, damage, speeds) is computed here, so rebalancing
## means editing these constants or a .tres file, not hunting through other scripts.

## A stat value of 10 is "average": it gives a multiplier of exactly 1.0.
const BASELINE: int = 10

const BASE_HEALTH: float = 50.0
const HEALTH_PER_VITALITY: float = 5.0
const DAMAGE_PER_STRENGTH: float = 0.05
const ATTACK_SPEED_PER_AGILITY: float = 0.04
const MOVE_SPEED_PER_AGILITY: float = 0.01
const DODGE_LENGTH_PER_AGILITY: float = 0.03
const MIN_MULTIPLIER: float = 0.2

@export var strength: int = 10
@export var agility: int = 10
@export var vitality: int = 10


func get_max_health() -> float:
	return maxf(1.0, BASE_HEALTH + vitality * HEALTH_PER_VITALITY)


func get_damage_multiplier() -> float:
	return _multiplier(strength, DAMAGE_PER_STRENGTH)


func get_attack_speed_multiplier() -> float:
	return _multiplier(agility, ATTACK_SPEED_PER_AGILITY)


func get_move_speed_multiplier() -> float:
	return _multiplier(agility, MOVE_SPEED_PER_AGILITY)


func get_dodge_length_multiplier() -> float:
	return _multiplier(agility, DODGE_LENGTH_PER_AGILITY)


func _multiplier(stat: int, per_point: float) -> float:
	return maxf(MIN_MULTIPLIER, 1.0 + (stat - BASELINE) * per_point)
