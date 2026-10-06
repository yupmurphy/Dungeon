class_name RegionData
extends Resource
## One region of a floor (e.g. the swamp): look, monsters, mini-boss.

@export var id: StringName = &"region"
@export var display_name: String = "Region"
## Multiplied over the region's tiles until it has a dedicated tileset.
@export var tile_tint: Color = Color.WHITE
## Color of explored floor on the minimap and the big map.
@export var map_color: Color = Color.WHITE
## Monsters that can spawn in this region's rooms (picked at random).
@export var monsters: Array[MonsterData] = []
## Spawned in the region's farthest room (stage 3).
@export var mini_boss: MonsterData
@export var min_monsters_per_room: int = 2
@export var max_monsters_per_room: int = 4
