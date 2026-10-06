class_name RegionData
extends Resource
## One region of a floor (e.g. the swamp): look, monsters, decoration, mini-boss.

@export var id: StringName = &"region"
@export var display_name: String = "Region"
## Multiplied over the region's tiles and props until it has a dedicated tileset.
@export var tile_tint: Color = Color.WHITE
## Color of explored floor on the minimap and the big map.
@export var map_color: Color = Color.WHITE
## Monsters that can spawn in this region's halls (picked at random).
@export var monsters: Array[MonsterData] = []
## Spawned in the region's farthest hall (stage 3).
@export var mini_boss: MonsterData
## Density: how many monsters per 100 floor tiles of a hall.
@export var monsters_per_100_tiles: float = 0.4
## Density: how many props (barrels, tombstones...) per 100 floor tiles of a hall.
@export var decor_per_100_tiles: float = 1.0
