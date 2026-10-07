extends Node2D
## A static, hand-built town (scenes/town/town.tscn). Everything is placed in the editor: ground on the
## TileMapLayers, buildings / walls / props as nodes in the y-sorted World. This script only wires runtime
## things: camera limits, the map edge, the exit to the dungeon, chimney smoke, R to restart.

const DUNGEON_SCENE: String = "res://scenes/floors/floor.tscn"
const TILE: int = 32

@onready var _grass: TileMapLayer = $Grass
@onready var _world: Node2D = $World


func _ready() -> void:
	var used: Rect2i = _grass.get_used_rect()
	var bounds := Rect2i(used.position * TILE, used.size * TILE)
	get_tree().call_group("game_camera", "set_room_limits", bounds)
	_add_bounds(Rect2(bounds))
	var exit := get_node_or_null("DungeonExit") as Area2D
	if exit != null:
		exit.body_entered.connect(_on_dungeon_exit)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


## Invisible walls around the map, so nobody walks off the edge.
func _add_bounds(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.name = "MapEdge"
	add_child(body)
	var thickness: float = TILE
	for box in [Rect2(rect.position.x, rect.position.y - thickness, rect.size.x, thickness),
			Rect2(rect.position.x, rect.end.y, rect.size.x, thickness),
			Rect2(rect.position.x - thickness, rect.position.y, thickness, rect.size.y),
			Rect2(rect.end.x, rect.position.y, thickness, rect.size.y)]:
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = box.size
		shape.shape = rectangle
		shape.position = box.get_center()
		body.add_child(shape)


func _on_dungeon_exit(body: Node2D) -> void:
	if body is Player:
		get_tree().change_scene_to_file.call_deferred(DUNGEON_SCENE)
