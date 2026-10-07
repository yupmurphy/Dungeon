extends Node2D
## Closed test room: fits the camera to the tilemap and lets R restart the scene.
## The room was laid out in reference pixels (16 px tiles); node positions are converted with GameScale.

@onready var _dungeon: TileMapLayer = $Dungeon


func _ready() -> void:
	_dungeon.tile_set = FloorTiles.dungeon_tile_set()
	for child in $World.get_children():
		if child is Node2D:
			child.position = GameScale.world_vector(child.position)
	var tile_size: Vector2i = _dungeon.tile_set.tile_size
	var used: Rect2i = _dungeon.get_used_rect()
	var bounds := Rect2i(used.position * tile_size, used.size * tile_size)
	get_tree().call_group("game_camera", "set_room_limits", bounds)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
