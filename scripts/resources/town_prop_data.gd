class_name TownPropData
extends Resource
## Stable town decoration data. The same footprint drives appearance, path checks and collision.
@export var id: StringName
@export var kind: StringName
@export var footprint: Rect2i
@export var solid: bool = true
@export var style: int = 0
