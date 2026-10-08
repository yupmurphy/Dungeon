extends Node
## Dev-only command line hooks (autoload DebugRunner). Does nothing unless Godot gets user args after "--":
##   -- --smoke-test                                  automated combat checks, exit code 0 = all passed
##   -- --floor-test                                  floor generator + floor scene checks
##   -- --stats-test                                  stat formulas checked with known values
##   -- --seed=<number>                               (read by FloorLevel) start the floor with this seed
##   -- --screenshot=<file.png> [--mode=idle|fight|room]   save one rendered frame (not headless)
##   -- --build-room                                  regenerate tileset + test room tiles
##   -- --terrain-map=<folder> [--seeds=<first>:<n>]  save floor terrain pictures (works headless)
##   -- --lpc-import=<LPC generator clone>             copy the LPC pieces we use into assets/lpc/ + credits
##   -- --build-town [--force]                      lay out the town scene (scenes/town/town.tscn), once
##   -- --bake-goblin=<LPC generator clone>          bake the young goblin sheet (assets/monsters/goblin/)
##   -- --town-test                                   town scene checks (layout, doors, walls, gates, night)
##   -- --generate-items                              items table (data/items/items.csv) -> resources/items/*.tres
##   -- --items-test                                  items pipeline checks (generated files match the table)
## Tools run inside the real game (with autoloads), which a plain `--script` run does not provide.

const TOOLS: Dictionary = {
	"--smoke-test": "res://tools/smoke_test.gd",
	"--floor-test": "res://tools/floor_test.gd",
	"--stats-test": "res://tools/stats_test.gd",
	"--screenshot": "res://tools/screenshot.gd",
	"--build-room": "res://tools/room_builder.gd",
	"--terrain-map": "res://tools/terrain_map.gd",
	"--lpc-import": "res://tools/lpc_import.gd",
	"--build-town": "res://tools/town_builder.gd",
	"--bake-goblin": "res://tools/goblin_baker.gd",
	"--town-test": "res://tools/town_test.gd",
	"--generate-items": "res://tools/items/item_generator.gd",
	"--items-test": "res://tools/items/items_test.gd",
}


func _ready() -> void:
	var options: Dictionary = _parse(OS.get_cmdline_user_args())
	for flag: String in TOOLS:
		if options.has(flag):
			var tool: Node = load(TOOLS[flag]).new()
			add_child(tool)
			tool.call("run", options)
			return


func _parse(args: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	for arg in args:
		var parts: PackedStringArray = arg.split("=", true, 1)
		result[parts[0]] = parts[1] if parts.size() > 1 else ""
	return result
