class_name TownBuildingData
extends Resource
## Persistent building identity and an exterior footprint. Interiors are separate scenes, not projects.
@export var id: StringName
@export var kind: StringName = &"house"
@export var name_key: StringName = &"TOWN_HOUSE"
@export var footprint: Rect2i
@export var style: int = 0
## Exterior floors including ground floor; future interiors may define their own upstairs scene.
@export_range(1, 2) var floors: int = 1
## Empty in exterior stage: no fake transition or loss of player state.
@export var interior_scene: PackedScene

func door_cell() -> Vector2i:
	return Vector2i(footprint.position.x + floori(footprint.size.x / 2.0), footprint.end.y)
