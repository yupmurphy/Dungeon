extends Node
## Generates resources/items/*.tres from the tables in data/items/ (see ItemPipeline). Run after every table change
## (or double-click tools/generate_items.bat):
##   <godot.exe> --headless --path . -- --generate-items
## Nothing is written when the table has errors; exit code 0 = done.


func run(_options: Dictionary) -> void:
	var report: Array[String] = []
	var errors: Array[String] = ItemPipeline.generate(report)
	for line in report:
		print("  " + line)
	if errors.is_empty():
		print("  special items (special column): %s" % ", ".join(ItemPipeline.special_items()))
	for error in errors:
		printerr("  ERROR " + error)
	print("items: %s (%d changed)" % ["FAILED" if not errors.is_empty() else "generated", report.size()])
	get_tree().quit(0 if errors.is_empty() else 1)
