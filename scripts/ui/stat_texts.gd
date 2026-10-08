class_name StatTexts
extends RefCounted
## Builds the character sheet's lines and tooltips. The words come from localization/texts.csv (editable
## without touching code); every number comes from Stats, so the texts always show the exact values.

## One line on the right side of the sheet: a derived value.
class Derived:
	var key: StringName
	var name: String
	var value: String
	var tooltip: String


const STAT_KEYS: Array[String] = ["STRENGTH", "AGILITY", "VITALITY", "MAGIC", "INTELLIGENCE", "PERCEPTION", "LUCK"]


static func stat_name(stat: Stats.Stat) -> String:
	return TranslationServer.translate("STAT_" + STAT_KEYS[stat])


## "Strength 5:" + what the stat does + what these points give, e.g. "+50 health", "+5% damage".
static func stat_tooltip(stats: Stats, stat: Stats.Stat) -> String:
	var value: int = stats.get_stat(stat)
	var lines: PackedStringArray = [
		_text("STAT_HEADER", {"name": stat_name(stat), "value": value}),
		_text("STAT_%s_DESC" % STAT_KEYS[stat]),
	]
	if stat == Stats.Stat.MAGIC and not stats.magic_unlocked:
		lines.append(_text("MAGIC_LOCKED_DESC"))
	for effect in stat_effects(stat, value):
		lines.append(effect)
	return "\n".join(lines)


## The exact contribution of `value` points of `stat`, one line per effect.
static func stat_effects(stat: Stats.Stat, value: int) -> PackedStringArray:
	var lines := PackedStringArray()
	match stat:
		Stats.Stat.STRENGTH:
			lines.append(_text("EFFECT_DAMAGE", {"value": _num(value * Stats.DAMAGE_BONUS_PER_STRENGTH * 100.0)}))
			lines.append(_text("EFFECT_HEALTH", {"value": _num(value * Stats.HEALTH_PER_STRENGTH)}))
			lines.append(_text("EFFECT_DEFENSE", {"value": _num(value * Stats.DEFENSE_PER_STRENGTH)}))
			lines.append(_text("EFFECT_KNOCKBACK", {"value": _num(value * Stats.KNOCKBACK_PER_STRENGTH * 100.0)}))
			lines.append(_text("EFFECT_CARRY", {"value": _num(value * Stats.CARRY_WEIGHT_PER_STRENGTH)}))
		Stats.Stat.AGILITY:
			lines.append(_text("EFFECT_DAMAGE", {"value": _num(value * Stats.DAMAGE_BONUS_PER_AGILITY * 100.0)}))
			lines.append(_text("EFFECT_ATTACK_SPEED", {"value": _num(value * Stats.ATTACK_SPEED_PER_AGILITY * 100.0)}))
			lines.append(_text("EFFECT_MOVE_SPEED", {"value": _num(value * Stats.MOVE_SPEED_PER_AGILITY * 100.0)}))
			lines.append(_text("EFFECT_EVADE", {"value": _num(minf(value * Stats.EVADE_PER_AGILITY, Stats.EVADE_MAX) * 100.0),
				"max": _num(Stats.EVADE_MAX * 100.0)}))
		Stats.Stat.VITALITY:
			lines.append(_text("EFFECT_EXHAUSTION", {"value": _num(minf(value * Stats.EXHAUSTION_GAIN_PER_VITALITY,
				1.0 - Stats.EXHAUSTION_GAIN_MIN) * 100.0)}))
		Stats.Stat.MAGIC:
			lines.append(_text("EFFECT_DAMAGE", {"value": _num(value * Stats.DAMAGE_BONUS_PER_MAGIC * 100.0)}))
			lines.append(_text("EFFECT_MAGIC_DAMAGE", {"value": _num(value * Stats.MAGIC_DAMAGE_PER_MAGIC * 100.0)}))
			lines.append(_text("EFFECT_MANA", {"value": _num(value * Stats.MANA_PER_MAGIC)}))
		Stats.Stat.INTELLIGENCE:
			lines.append(_text("EFFECT_INTELLIGENCE"))
		Stats.Stat.PERCEPTION:
			lines.append(_text("EFFECT_DAMAGE", {"value": _num(value * Stats.DAMAGE_BONUS_PER_PERCEPTION * 100.0)}))
			lines.append(_text("EFFECT_CRIT", {"value": _num(minf(value * Stats.CRIT_CHANCE_PER_PERCEPTION,
				Stats.CRIT_CHANCE_MAX) * 100.0)}))
			lines.append(_text("EFFECT_SIGHT", {"value": _num(_tiles(minf(value * Stats.SIGHT_RADIUS_PER_PERCEPTION,
				Stats.SIGHT_RADIUS_MAX - Stats.SIGHT_RADIUS_BASE)))}))
			lines.append(_text("EFFECT_LIGHT", {"value": _num(_tiles(minf(value * Stats.LIGHT_RADIUS_PER_PERCEPTION,
				Stats.LIGHT_RADIUS_MAX - Stats.LIGHT_RADIUS_BASE)))}))
			lines.append(_text("EFFECT_REVEAL", {"value": _num(minf(value * Stats.REVEAL_RADIUS_PER_PERCEPTION,
				Stats.REVEAL_RADIUS_MAX - Stats.REVEAL_RADIUS_BASE))}))
		Stats.Stat.LUCK:
			lines.append(_text("EFFECT_NONE"))
	return lines


## Every derived value, in the order shown on the sheet, with its "comes from" tooltip.
static func derived(stats: Stats) -> Array[Derived]:
	var list: Array[Derived] = []
	var health: float = stats.get_max_health()
	list.append(_derived("HEALTH", _num(health), {"base": _num(Stats.HEALTH_BASE),
		"per": _num(Stats.HEALTH_PER_STRENGTH), "stat": stats.strength, "value": _num(health)}))
	var mana: float = stats.get_max_mana()
	list.append(_derived("MANA", _num(mana), {"base": _num(Stats.MANA_BASE),
		"per": _num(Stats.MANA_PER_MAGIC), "stat": stats.magic, "value": _num(mana)}))
	var defense: float = stats.get_defense()
	list.append(_derived("DEFENSE", _num(defense), {"per": _num(Stats.DEFENSE_PER_STRENGTH),
		"taken": _num(Combat.damage_taken(100.0, stats))}))
	list.append(_derived("DAMAGE", "+%s%%" % _num(stats.get_damage_bonus() * 100.0), {
		"strength": _num(stats.strength * Stats.DAMAGE_BONUS_PER_STRENGTH * 100.0),
		"agility": _num(stats.agility * Stats.DAMAGE_BONUS_PER_AGILITY * 100.0),
		"magic": _num(stats.magic * Stats.DAMAGE_BONUS_PER_MAGIC * 100.0),
		"perception": _num(stats.perception * Stats.DAMAGE_BONUS_PER_PERCEPTION * 100.0)}))
	list.append(_derived("MAGIC_DAMAGE", "+%s%%" % _num(stats.get_magic_damage_bonus() * 100.0),
		{"per": _num(Stats.MAGIC_DAMAGE_PER_MAGIC * 100.0)}))
	list.append(_derived("ATTACK_SPEED", _percent_over(stats.get_attack_speed_multiplier()),
		{"per": _num(Stats.ATTACK_SPEED_PER_AGILITY * 100.0)}))
	list.append(_derived("MOVE_SPEED", _percent_over(stats.get_move_speed_multiplier()),
		{"per": _num(Stats.MOVE_SPEED_PER_AGILITY * 100.0)}))
	list.append(_derived("EVADE", "%s%%" % _num(stats.get_evade_chance() * 100.0),
		{"per": _num(Stats.EVADE_PER_AGILITY * 100.0), "max": _num(Stats.EVADE_MAX * 100.0)}))
	list.append(_derived("CRIT", "%s%%" % _num(stats.get_crit_chance() * 100.0),
		{"per": _num(Stats.CRIT_CHANCE_PER_PERCEPTION * 100.0), "critical": _num(Stats.CRITICAL_DAMAGE * 100.0)}))
	list.append(_derived("SIGHT", "%s tiles" % _num(_tiles(stats.get_sight_radius())),
		{"base": _num(_tiles(Stats.SIGHT_RADIUS_BASE)), "per": _num(_tiles(Stats.SIGHT_RADIUS_PER_PERCEPTION)),
		"max": _num(_tiles(Stats.SIGHT_RADIUS_MAX))}))
	list.append(_derived("LIGHT", "%s tiles" % _num(_tiles(stats.get_light_radius())),
		{"base": _num(_tiles(Stats.LIGHT_RADIUS_BASE)), "per": _num(_tiles(Stats.LIGHT_RADIUS_PER_PERCEPTION)),
		"max": _num(_tiles(Stats.LIGHT_RADIUS_MAX))}))
	list.append(_derived("REVEAL", "%d tiles" % stats.get_reveal_radius(),
		{"base": _num(Stats.REVEAL_RADIUS_BASE), "per": _num(Stats.REVEAL_RADIUS_PER_PERCEPTION),
		"max": Stats.REVEAL_RADIUS_MAX}))
	list.append(_derived("KNOCKBACK", _percent_over(stats.get_knockback_multiplier()),
		{"per": _num(Stats.KNOCKBACK_PER_STRENGTH * 100.0)}))
	list.append(_derived("CARRY", _num(stats.get_carry_weight()),
		{"base": _num(Stats.CARRY_WEIGHT_BASE), "per": _num(Stats.CARRY_WEIGHT_PER_STRENGTH)}))
	list.append(_derived("EXHAUSTION", "%s%%" % _num(stats.get_exhaustion_gain_multiplier() * 100.0),
		{"per": _num(Stats.EXHAUSTION_GAIN_PER_VITALITY * 100.0), "min": _num(Stats.EXHAUSTION_GAIN_MIN * 100.0),
		"sprint": _num(ExhaustionComponent.SPRINT_PER_SECOND), "attack": _num(ExhaustionComponent.ATTACK_COST),
		"tired": _num(ExhaustionComponent.TIRED_THRESHOLD)}))
	list.append(_derived("DASH", "+%s / %s s" % [_num(DashAttack.EXHAUSTION_COST), _num(DashAttack.COOLDOWN)],
		{"cost": _num(DashAttack.EXHAUSTION_COST), "cooldown": _num(DashAttack.COOLDOWN),
		"bonus": _num(DashAttack.DAMAGE_BONUS * 100.0)}))
	return list


static func _derived(key: String, value: String, params: Dictionary) -> Derived:
	var line := Derived.new()
	line.key = StringName(key)
	line.name = _text("DERIVED_" + key)
	line.value = value
	line.tooltip = "%s %s\n%s" % [line.name, value, _text("DERIVED_%s_FROM" % key, params)]
	return line


static func _text(key: String, params: Dictionary = {}) -> String:
	return TranslationServer.translate(key).format(params)


## Multiplier 1.15 -> "+15%".
static func _percent_over(multiplier: float) -> String:
	return "%+d%%" % roundi((multiplier - 1.0) * 100.0)


## Reference pixels -> tiles.
static func _tiles(reference_pixels: float) -> float:
	return reference_pixels / GameScale.REFERENCE_TILE


## Up to 2 decimals, without trailing zeros: 50 -> "50", 2.5 -> "2.5", 0.18 -> "0.18".
static func _num(value: float) -> String:
	var text: String = "%.2f" % value
	text = text.rstrip("0").rstrip(".")
	return "0" if text == "-0" else text
