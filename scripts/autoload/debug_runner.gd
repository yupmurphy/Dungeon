extends Node
## Dev-only command line hooks (autoload DebugRunner). Does nothing unless Godot gets user args after "--":
##   -- --smoke-test                                  automated combat checks, exit code 0 = all passed
##   -- --screenshot=<file.png> [--mode=idle|fight|dodge]   save one rendered frame (not headless)
##   -- --build-room                                  regenerate tileset + test room tiles
## Tools run inside the real game (with autoloads), which a plain `--script` run does not provide.

const TOOLS: Dictionary = {
	"--smoke-test": "res://tools/smoke_test.gd",
	"--screenshot": "res://tools/screenshot.gd",
	"--build-room": "res://tools/room_builder.gd",
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
