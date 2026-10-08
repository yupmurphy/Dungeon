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
