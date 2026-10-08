extends Node
## Generates resources/items/*.tres from data/items/items.csv (see ItemPipeline). Run after every table change:
##   <godot.exe> --headless --path . -- --generate-items
## Nothing is written when the table has errors; exit code 0 = done.


func run(_options: Dictionary) -> void:
	var report: Array[String] = []
	var errors: Array[String] = ItemPipeline.generate(report)
	for line in report:
		print("  " + line)
	for error in errors:
		printerr("  ERROR " + error)
	print("items: %s (%d changed)" % ["FAILED" if not errors.is_empty() else "generated", report.size()])
	get_tree().quit(0 if errors.is_empty() else 1)
