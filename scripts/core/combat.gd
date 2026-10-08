class_name Combat
extends RefCounted
## One attack against one target, the same rules for player and monsters:
##   1. miss roll against the target's evade chance (Agility),
##   2. critical roll against the attacker's crit chance (Perception),
##   damage dealt = weapon damage x (1 + damage bonus) x (Stats.CRITICAL_DAMAGE if critical),
##   damage taken = damage dealt x DEFENSE_SCALE / (DEFENSE_SCALE + target's defense).
## All numbers live in Stats. A null attacker/target simply has no bonuses/defense.

class Hit:
	var damage: float
	var missed: bool
	var critical: bool

	func _init(hit_damage: float = 0.0, hit_missed: bool = false, hit_critical: bool = false) -> void:
		damage = hit_damage
		missed = hit_missed
		critical = hit_critical


## Tests can queue rolls (0..1) here for a known outcome; each roll takes the first one, otherwise randf().
## Every attack rolls twice: miss first, then critical.
static var forced_rolls: Array[float] = []


static func resolve(attacker: Stats, target: Stats, weapon_damage: float) -> Hit:
	var miss_roll: float = _roll()
	var crit_roll: float = _roll()
	if target != null and miss_roll < target.get_evade_chance():
		return Hit.new(0.0, true, false)
	var critical: bool = attacker != null and crit_roll < attacker.get_crit_chance()
	return Hit.new(damage_taken(damage_dealt(attacker, weapon_damage, critical), target), false, critical)


static func damage_dealt(attacker: Stats, weapon_damage: float, critical: bool) -> float:
	var damage: float = weapon_damage
	if attacker != null:
		damage *= 1.0 + attacker.get_damage_bonus()
	if critical:
		damage *= Stats.CRITICAL_DAMAGE
	return damage


static func damage_taken(damage: float, target: Stats) -> float:
	if target == null:
		return damage
	return damage * Stats.DEFENSE_SCALE / (Stats.DEFENSE_SCALE + target.get_defense())


static func _roll() -> float:
	if not forced_rolls.is_empty():
		return forced_rolls.pop_front()
	return randf()


## Rough strength of a fighter, to compare monsters with the player: max health x damage of one normal hit.
## `max_health` overrides the Stats formula (monsters with a fixed health, MonsterData.max_health).
static func power_rating(stats: Stats, weapon_damage: float, max_health: float = 0.0) -> float:
	var health: float = max_health if max_health > 0.0 else stats.get_max_health()
	return health * damage_dealt(stats, weapon_damage, false)
