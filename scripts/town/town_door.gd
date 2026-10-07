class_name TownDoor
extends Area2D
## Reusable doorway. Destination is data; the level will own transitions in the interior stage.
const REACH: Vector2 = Vector2(20, 16)
var data: TownBuildingData
var nearby_player: Player

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = GameScale.world_vector(REACH)
	shape.shape = rect
	add_child(shape)
	body_entered.connect(_entered)
	body_exited.connect(_exited)
	add_to_group("town_door")

func _entered(body: Node2D) -> void:
	if body is Player:
		nearby_player = body as Player

func _exited(body: Node2D) -> void:
	if body == nearby_player:
		nearby_player = null
