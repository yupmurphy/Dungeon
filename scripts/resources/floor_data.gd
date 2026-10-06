class_name FloorData
extends Resource
## One dungeon floor: size, regions and boss. The layout itself is generated from a seed.

@export var floor_number: int = 1
@export var display_name: String = "Floor 1"
## Map size in tiles. Must divide evenly by sector_grid.
@export var map_size: Vector2i = Vector2i(160, 160)
## The map is cut into this many sectors; each sector holds one room.
@export var sector_grid: Vector2i = Vector2i(4, 4)
## Placed at random positions on every generation.
@export var regions: Array[RegionData] = []
## Floor boss, guards the portal (stage 3).
@export var boss: MonsterData

@export_group("Start zone")
@export var start_name: String = "Start Zone"
@export var start_tile_tint: Color = Color.WHITE
@export var start_map_color: Color = Color(0.9, 0.9, 0.85)

@export_group("Boss arena")
@export var boss_area_name: String = "Boss Arena"
@export var boss_tile_tint: Color = Color(0.85, 0.75, 1.0)
@export var boss_map_color: Color = Color(0.85, 0.3, 0.35)
