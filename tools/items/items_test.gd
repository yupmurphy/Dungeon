extends Node
## Items pipeline checks: the generated files match the table, and the generator handles bad tables.
## Run:  <godot.exe> --headless --path . -- --items-test     (exit code 0 = all passed)

var _failures: int = 0


func run(_options: Dictionary) -> void:
	print("--- generated items match data/items/items.csv")
	var problems: Array[String] = ItemPipeline.check()
	for problem in problems:
		print("    " + problem)
	_check(problems.is_empty(), "every generated item matches its row, none edited by hand, none left over")
	var errors: Array[String] = []
	var rows: Array[ItemPipeline.Row] = ItemPipeline.read_table(errors)
	_check(errors.is_empty() and rows.size() == 20, "the table has the 20 example items (%d)" % rows.size())
	var sword := Equipment.find(&"weapon_sword")
	_check(sword != null and sword.resource_path.begins_with(ItemPipeline.OUTPUT_DIR) and sword.tier == 1
		and sword.role == &"balanced" and sword.source == &"start", "an item loads from the generated file with its table values")
	var spear := Equipment.find(&"weapon_hunter_spear")
	_check(spear != null and spear.display_name == "Hunter's spear" and spear.set_id == &"hunter"
		and spear.lpc_item == "weapon_spear", "a new item can reuse another item's sprite (Hunter's spear)")
	var bob := Equipment.find(&"hair_bob")
	_check(bob != null and not bob.is_item(), "hair styles are looks, not items")
	var text: String = FileAccess.get_file_as_string(ItemPipeline.output_path("weapon_sword"))
	_check(text.begins_with("; GENERATED"), "generated files say they must not be edited")

	print("--- stats from the tier rules (stage 2)")
	var leggings := Equipment.find(&"legs_leggings")
	_check(leggings != null and is_equal_approx(leggings.bonuses.get(&"defense", 0.0), 4.9),
		"leather tier 2 = 7 defense, legs get 0.7 of it: 4.9 (%s)" % (leggings.bonuses if leggings else {}))
	var shirt := Equipment.find(&"torso_longsleeve")
	_check(shirt != null and shirt.bonuses == {&"defense": 2.0}, "cloth tier 1 torso: 2 defense (%s)" % shirt.bonuses)
	var knife := Equipment.find(&"weapon_goblin_knife")
	_check(knife != null and is_equal_approx(knife.bonuses.get(&"attack_speed", 0.0), 0.25)
		and is_equal_approx(knife.bonuses.get(&"damage", 0.0), 0.1),
		"a special item's override replaces one value, the rest comes from its rule (%s)" % knife.bonuses)
	_check(is_equal_approx(spear.bonuses.get(&"crit_chance", 0.0), 0.05) and is_equal_approx(spear.bonuses.get(&"damage", 0.0), 0.3),
		"an override can add a stat the rule doesn't give (%s)" % spear.bonuses)
	var special: Array[String] = ItemPipeline.special_items()
	_check(special.size() <= 4, "only a few special items have overrides (%s)" % ", ".join(special))
	var rule_errors: Array[String] = []
	var rules: ItemPipeline.Rules = ItemPipeline.read_rules(rule_errors)
	_check(rule_errors.is_empty(), "the tier and slot rule tables read without errors %s" % [rule_errors])
	var no_rule := ItemPipeline.Row.new()
	no_rule.line = 9
	no_rule.values = {"id": "odd", "name": "Odd", "slot": "torso", "tier": "9", "role": "plate", "set_id": "",
		"sprite": "torso_leather", "source": "drop_goblin", "overrides": ""}
	var no_rule_errors: Array[String] = []
	ItemPipeline.item_bonuses(no_rule, rules, no_rule_errors)
	_check(no_rule_errors.size() == 1 and "no tier rule" in no_rule_errors[0], "an item without a tier rule is refused")
	var parse_errors: Array[String] = []
	var parsed: Dictionary = ItemPipeline.parse_bonuses("defense=3;evade;speed=fast", "test", parse_errors)
	_check(parsed == {&"defense": 3.0} and parse_errors.size() == 2, "badly written bonuses are reported (%d)" % parse_errors.size())

	print("--- bad tables are refused")
	var bad := ItemPipeline.Row.new()
	bad.line = 7
	bad.values = {"id": "x y", "name": "Bad", "slot": "hair", "tier": "zero", "role": "", "set_id": "",
		"sprite": "weapon_axe", "source": "shop_smithy", "overrides": ""}
	var bad_errors: Array[String] = ItemPipeline.row_errors(bad)
	_check(bad_errors.size() == 4, "bad id, hair slot, bad tier and empty role are all reported (%d)" % bad_errors.size())
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
