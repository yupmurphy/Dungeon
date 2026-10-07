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
