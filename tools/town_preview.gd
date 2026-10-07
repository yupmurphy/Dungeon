extends Node
## -- --town opens the exterior without changing the dungeon main scene.
const TOWN_SCENE: String = "res://scenes/town/town.tscn"
func run(_options: Dictionary) -> void:
	get_tree().change_scene_to_file.call_deferred(TOWN_SCENE)
