class_name RegionData
extends Resource
## One zone of a floor (e.g. the swamp): kind, look, monsters, decoration, mini-boss.

## CLOSED = caves and tunnels inside rock, always dark. OPEN = wide natural area (stage 5: day/night).
enum Kind { CLOSED, OPEN }

@export var id: StringName = &"region"
@export var display_name: String = "Region"
@export var kind: Kind = Kind.OPEN
## Multiplied over the zone's tiles and props until it has a dedicated tileset.
@export var tile_tint: Color = Color.WHITE
## Color of explored floor on the minimap and the big map (rock uses a darker shade).
@export var map_color: Color = Color.WHITE
## Monsters that can spawn in this zone (picked at random).
@export var monsters: Array[MonsterData] = []
## Spawned in the zone's main lair (stage 3).
@export var mini_boss: MonsterData
## Density: how many monsters per 100 floor tiles.
@export var monsters_per_100_tiles: float = 0.15
## Density: how many props (barrels, rocks...) per 100 floor tiles.
@export var decor_per_100_tiles: float = 0.4
