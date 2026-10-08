extends Node
## Items pipeline checks: the generated files match the tables, the values follow the rules, bad tables are refused.
## Run:  <godot.exe> --headless --path . -- --items-test     (exit code 0 = all passed)

var _failures: int = 0


func run(_options: Dictionary) -> void:
	print("--- generated items match the tables in data/items/")
	var problems: Array[String] = ItemPipeline.check()
	for problem in problems:
		print("    " + problem)
	_check(problems.is_empty(), "every generated item matches its row, none edited by hand, none left over")
	var errors: Array[String] = []
	var rows: Array[ItemPipeline.Row] = ItemPipeline.read_table(errors)
	_check(errors.is_empty() and rows.size() >= 20, "the table has the example items (%d)" % rows.size())
	var rules: ItemPipeline.Rules = ItemPipeline.read_rules(errors)
	_check(errors.is_empty(), "every rule table reads without errors %s" % [errors])
	_check(rules.tiers.size() == rules.roles.size() * EquipmentData.TIER_NAMES.size(),
		"tier_rules.csv has every role at every tier F-S (%d rows)" % rules.tiers.size())
	var sword := Equipment.find(&"weapon_sword")
	_check(sword != null and sword.resource_path.begins_with(ItemPipeline.OUTPUT_DIR) and sword.tier_name() == "F"
		and sword.role == &"sword" and sword.source == &"start", "an item loads from the generated file with its table values")
	var text: String = FileAccess.get_file_as_string(ItemPipeline.output_path("weapon_sword"))
	_check(text.begins_with("; GENERATED"), "generated files say they must not be edited")
	var bob := Equipment.find(&"hair_bob")
	_check(bob != null and not bob.is_item(), "hair styles are looks, not items")

	print("--- values from the rules")
	var leggings := Equipment.find(&"legs_leggings")
	# leather D: defense 6 (x0.7 for pants) + pants D: carry 3, exhaustion -0.016
	_check(is_equal_approx(leggings.bonuses.get(&"defense", 0.0), 4.2)
		and is_equal_approx(leggings.bonuses.get(&"carry_weight", 0.0), 3.0)
		and is_equal_approx(leggings.bonuses.get(&"exhaustion_gain", 0.0), -0.016),
		"pants: 0.7 of the role's values + the pants' own bonus (%s)" % leggings.bonuses)
	var boots := Equipment.find(&"feet_boots")
	_check(boots.bonuses.get(&"move_speed", 0.0) > 0.0, "boots make you faster (%s)" % boots.bonuses)
	var helmet := Equipment.find(&"helmet_kettle")
	_check(helmet.bonuses.get(&"sight_radius", 0.0) > 0.0 and helmet.bonuses.get(&"light_radius", 0.0) > 0.0
		and helmet.bonuses.get(&"move_speed", 0.0) < 0.0, "a plate helmet: you see farther, but plate slows (%s)" % helmet.bonuses)
	var shirt := Equipment.find(&"torso_longsleeve")
	_check(not shirt.bonuses.has(&"strength") and not shirt.bonuses.has(&"price"), "zeros and item stats are not bonuses")
	_check(shirt.price == 10.0 and shirt.weight == 1.0, "price and weight are the item's own values (%s, %s)" % [shirt.price,
		shirt.weight])
	var tier_s: Dictionary = rules.tiers["spear:%d" % ItemPipeline.tier_index("S")]
	_check(tier_s.get(&"damage", 0.0) > rules.tiers["spear:0"].get(&"damage", 0.0), "tier S is stronger than tier F")
	var spear := Equipment.find(&"weapon_spear")
	_check(spear.melee and not spear.splash and spear.attack_range == 36.0, "weapons get melee / splash / range from their role")
	var axe := Equipment.find(&"weapon_axe")
	_check(axe.splash, "an axe hits an area (splash)")
	var ring := Equipment.find(&"ring_copper")
	_check(ring != null and ring.lpc_item.is_empty() and ring.bonuses.get(&"luck", 0.0) > 0.0,
		"jewelry: not drawn, gives its role's stats (%s)" % ring.bonuses)
	var knife := Equipment.find(&"weapon_goblin_knife")
	_check(is_equal_approx(knife.bonuses.get(&"attack_speed", 0.0), 0.25) and knife.bonuses.get(&"damage", 0.0) > 0.0,
		"a special value replaces one value, the rest comes from the rules (%s)" % knife.bonuses)
	var hunter := Equipment.find(&"weapon_hunter_spear")
	_check(is_equal_approx(hunter.bonuses.get(&"crit_chance", 0.0), 0.05), "a special value can add a stat (%s)" % hunter.bonuses)

	print("--- bad tables are refused")
	var bad := ItemPipeline.Row.new()
	bad.line = 7
	bad.values = {"id": "x y", "name": "Bad", "slot": "hair", "tier": "Z", "role": "dagger", "set_id": "",
		"sprite": "weapon_axe", "source": "shop_smithy", "special": ""}
	var bad_errors: Array[String] = ItemPipeline.row_errors(bad, rules)
	_check(bad_errors.size() == 3, "bad id, unknown slot and unknown tier are all reported (%s)" % [bad_errors])
	bad.values["slot"] = "helmet"
	bad.values["id"] = "dagger_hat"
	bad.values["tier"] = "C"
	bad_errors = ItemPipeline.row_errors(bad, rules)
	_check(bad_errors.size() == 1 and "can't go in" in bad_errors[0], "a dagger can't be a helmet")
	bad.values = {"id": "ring_drawn", "name": "Ring", "slot": "ring", "tier": "F", "role": "might", "set_id": "",
		"sprite": "weapon_axe", "source": "shop_smithy", "special": "speed=fast"}
	bad_errors = ItemPipeline.row_errors(bad, rules)
	_check(bad_errors.size() == 1 and "not drawn" in bad_errors[0], "jewelry with a sprite is refused")
	var value_errors: Array[String] = []
	ItemPipeline.item_values(bad, rules, value_errors)
	_check(value_errors.size() == 1, "badly written special values are reported (%s)" % [value_errors])
	bad.values["special"] = "flying=1"
	value_errors.clear()
	ItemPipeline.item_values(bad, rules, value_errors)
	_check(value_errors.size() == 1 and "not in stats.csv" in value_errors[0], "an unknown stat is refused")
	var table_errors: Array[String] = []
	ItemPipeline.read_table(table_errors, "res://localization/texts.csv")
	_check(not table_errors.is_empty(), "a table with the wrong columns is refused")

	print("--- result: %s" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  " + label)
	else:
		_failures += 1
		print("  FAIL  " + label)
