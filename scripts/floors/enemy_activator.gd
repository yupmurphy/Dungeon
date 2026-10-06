class_name EnemyActivator
extends Node
## Performance: enemies far from the player are paused (no AI, no physics process).
## Checked a few times per second instead of every frame.

@export var active_radius: float = 480.0
@export var check_interval: float = 0.25

var _time_left: float = 0.0


func _physics_process(delta: float) -> void:
	_time_left -= delta
	if _time_left > 0.0:
		return
	_time_left = check_interval
	refresh()


func refresh() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var radius_squared: float = active_radius * active_radius
	for enemy: Node2D in get_tree().get_nodes_in_group("enemy"):
		var near: bool = enemy.global_position.distance_squared_to(player.global_position) <= radius_squared
		var wanted: ProcessMode = Node.PROCESS_MODE_INHERIT if near else Node.PROCESS_MODE_DISABLED
		if enemy.process_mode != wanted:
			enemy.process_mode = wanted


func active_count() -> int:
	var count: int = 0
	for enemy: Node in get_tree().get_nodes_in_group("enemy"):
		if enemy.process_mode != Node.PROCESS_MODE_DISABLED:
			count += 1
	return count
