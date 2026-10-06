extends Node2D
## Closed test room. Only job here: R restarts the scene.


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
