extends Node
## Stat formulas checked with known values (pure math, no scene needed).
## Run:  <godot.exe> --headless --path . -- --stats-test     (exit code 0 = all passed)

const MONSTER_STATS: Array[String] = ["res://resources/stats/bat_stats.tres",
	"res://resources/stats/slime_stats.tres", "res://resources/stats/spider_stats.tres"]

var _failures: int = 0


func run(_options: Dictionary) -> void:
	print("--- main stats")
	var fresh := Stats.new()
	for stat in Stats.Stat.values():
		_check(fresh.get_stat(stat) == 5, "%s starts at 5" % Stats.PROPERTY_NAMES[stat])
	var player_stats: Stats = load("res://resources/stats/player_stats.tres")
	for stat in Stats.Stat.values():
		_check(player_stats.get_stat(stat) == 5, "player file: %s = 5" % Stats.PROPERTY_NAMES[stat])
	fresh.luck = 12
	_check(fresh.luck == 12, "luck is stored as a value")
	fresh.add_stat(Stats.Stat.STRENGTH, -100)
	_check(fresh.strength == 0, "a stat never goes below 0")
	var changed: Array[bool] = [false]
	fresh.changed.connect(func() -> void: changed[0] = true)
	fresh.add_stat(Stats.Stat.AGILITY, 10)
	_check(changed[0] and fresh.agility == 15, "changing a stat notifies listeners")

	print("--- only main stats are saved")
	var saved: Array[String] = []
	for property in Stats.new().get_property_list():
		if property["usage"] & PROPERTY_USAGE_STORAGE and property["name"] not in ["script", "resource_local_to_scene",
				"resource_name", "resource_path"]:
			saved.append(property["name"])
	saved.sort()
	_check(saved == ["agility", "intelligence", "luck", "perception", "strength", "vitality"],
		"saved properties are exactly the 6 main stats (%s)" % ", ".join(saved))

	print("--- pools")
	_check_value(_with(Stats.Stat.VITALITY, 5).get_max_health(), 100.0, "Vitality 5 -> 100 health")
	_check_value(_with(Stats.Stat.VITALITY, 0).get_max_health(), 50.0, "Vitality 0 -> 50 health")
	_check_value(_with(Stats.Stat.VITALITY, 20).get_max_health(), 250.0, "Vitality 20 -> 250 health")
	_check_value(_with(Stats.Stat.VITALITY, 5).get_max_stamina(), 70.0, "Vitality 5 -> 70 stamina")
	_check_value(_with(Stats.Stat.VITALITY, 15).get_max_stamina(), 110.0, "Vitality 15 -> 110 stamina")
	_check_value(_with(Stats.Stat.INTELLIGENCE, 5).get_max_mana(), 45.0, "Intelligence 5 -> 45 mana")
	_check_value(_with(Stats.Stat.INTELLIGENCE, 0).get_max_mana(), 20.0, "Intelligence 0 -> 20 mana")

	print("--- what each stat does")
	_check_value(Stats.new().get_damage_bonus(), 0.2, "all stats 5 -> +20% damage (4 stats x 5 x 1%)")
	_check_value(_with(Stats.Stat.LUCK, 50).get_damage_bonus(), 0.2, "Luck does not add damage")
	_check_value(_with(Stats.Stat.STRENGTH, 10).get_defense(), 5.0, "Strength 10 -> 5 defense")
	_check_value(_with(Stats.Stat.STRENGTH, 5).get_carry_weight(), 35.0, "Strength 5 -> carry 35")
	_check(_with(Stats.Stat.STRENGTH, 20).get_knockback_multiplier() > _with(Stats.Stat.STRENGTH, 5).get_knockback_multiplier(),
		"more Strength -> more knockback")
	_check_value(_with(Stats.Stat.AGILITY, 10).get_attack_speed_multiplier(), 1.3, "Agility 10 -> attack speed x1.3")
	_check_value(_with(Stats.Stat.AGILITY, 5).get_move_speed_multiplier(), 1.05, "Agility 5 -> move speed x1.05")
	_check_value(_with(Stats.Stat.AGILITY, 300).get_move_speed_multiplier(), 4.0, "Agility 300 -> move speed x4 (no limit)")
	_check_value(_with(Stats.Stat.AGILITY, 30).get_evade_chance(), 0.3, "Agility 30 -> 30% of enemy hits miss")
	_check_value(_with(Stats.Stat.AGILITY, 80).get_evade_chance(), 0.8, "Agility 80 -> 80% miss")
	_check_value(_with(Stats.Stat.AGILITY, 100).get_evade_chance(), 0.8, "Agility 100 -> still 80% miss (cap)")
	_check_value(_with(Stats.Stat.AGILITY, 5).get_dodge_invulnerability(), 0.18, "Agility 5 -> 0.18 s dodge invulnerability")
	_check_value(_with(Stats.Stat.AGILITY, 15).get_dodge_invulnerability(), 0.28, "Agility 15 -> 0.28 s")
	_check_value(_with(Stats.Stat.VITALITY, 10).get_poison_duration_multiplier(), 0.7, "Vitality 10 -> poison lasts 70%")
	_check_value(_with(Stats.Stat.VITALITY, 100).get_poison_duration_multiplier(), 0.1, "Vitality 100 -> poison 10% (floor)")
	_check_value(_with(Stats.Stat.PERCEPTION, 5).get_crit_chance(), 0.05, "Perception 5 -> 5% critical")
	_check_value(_with(Stats.Stat.PERCEPTION, 150).get_crit_chance(), 1.0, "Perception 150 -> 100% critical (cap)")
	_check(_with(Stats.Stat.PERCEPTION, 20).get_sight_radius() > _with(Stats.Stat.PERCEPTION, 5).get_sight_radius(),
		"more Perception -> see monsters farther")

	print("--- damage formulas")
	var average := Stats.new()
	_check_value(Combat.damage_dealt(average, 20.0, false), 24.0, "weapon 20, stats 5 -> deals 24")
	_check_value(Combat.damage_dealt(average, 20.0, true), 36.0, "critical -> 150% = 36")
	_check_value(Combat.damage_dealt(null, 20.0, false), 20.0, "no stats -> weapon damage only")
	_check_value(Combat.damage_taken(50.0, _with(Stats.Stat.STRENGTH, 0)), 50.0, "defense 0 -> takes all 50")
	_check_value(Combat.damage_taken(50.0, _with(Stats.Stat.STRENGTH, 200)), 25.0, "defense 100 -> takes half (25)")
	Combat.forced_rolls.assign([0.04, 0.99])
	var hit: Combat.Hit = Combat.resolve(average, average, 20.0)
	_check(hit.missed and hit.damage == 0.0, "miss roll 0.04 < 5% evade -> missed, no damage")
	Combat.forced_rolls.assign([0.06, 0.04])
	hit = Combat.resolve(average, _with(Stats.Stat.STRENGTH, 0), 20.0)
	_check(not hit.missed and hit.critical and is_equal_approx(hit.damage, 36.0),
		"miss roll 0.06 hits, crit roll 0.04 < 5%% -> critical 36 (got %s)" % hit.damage)
	Combat.forced_rolls.assign([0.85, 0.99])
	hit = Combat.resolve(average, _with(Stats.Stat.AGILITY, 100), 20.0)
	_check(not hit.missed, "Agility 100: a 0.85 roll still hits (evade capped at 80%, not 100%)")
	Combat.forced_rolls.clear()
	var misses: int = 0
	for i in 2000:
		if Combat.resolve(average, _with(Stats.Stat.AGILITY, 100), 20.0).missed:
			misses += 1
	_check(misses > 1500 and misses < 1700, "Agility 100: ~80%% of 2000 random hits miss (%d)" % misses)

	print("--- monsters use the same system")
	for path in MONSTER_STATS:
		var stats: Stats = load(path)
		_check(stats is Stats and stats.get_max_health() >= 50.0, "%s: Stats with health %d" % [path.get_file(),
			stats.get_max_health()])

	print("--- result: %s" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)


## Fresh stats (all 5) with one stat changed.
func _with(stat: Stats.Stat, value: int) -> Stats:
	var stats := Stats.new()
	stats.set_stat(stat, value)
	return stats


func _check_value(actual: float, expected: float, label: String) -> void:
	_check(is_equal_approx(actual, expected), "%s (got %s)" % [label, actual])


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  ", label)
	else:
		_failures += 1
		print("  FAIL  ", label)
