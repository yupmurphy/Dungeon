class_name FloorData
extends Resource
## One dungeon floor: size, layout settings, regions and boss. The layout itself is generated from a seed.

@export var floor_number: int = 1
@export var display_name: String = "Floor 1"
## Placed at random positions on every generation.
@export var regions: Array[RegionData] = []
## Floor boss, guards the portal (stage 3).
@export var boss: MonsterData

@export_group("Layout")
## Map size in tiles. Must divide evenly by sector_grid.
@export var map_size: Vector2i = Vector2i(480, 480)
## The map is cut into this many sectors; each sector holds one hall.
@export var sector_grid: Vector2i = Vector2i(6, 6)
@export var room_min: Vector2i = Vector2i(26, 22)
@export var room_max: Vector2i = Vector2i(56, 48)
@export var start_room: Vector2i = Vector2i(20, 16)
@export var boss_room: Vector2i = Vector2i(44, 36)
## Chance that two neighboring halls get an extra corridor (a loop) besides the ones needed.
@export_range(0.0, 1.0) var extra_link_chance: float = 0.1
## Chance that a big hall gets a grid of stone pillars.
@export_range(0.0, 1.0) var pillar_hall_chance: float = 0.6

@export_group("Content")
## One wall torch every this many tiles of a hall's top wall.
@export var torch_spacing: int = 7
## Streaming: the map is loaded around the player in square chunks of this many tiles.
@export var chunk_size: int = 32

@export_group("Start zone")
@export var start_name: String = "Start Zone"
@export var start_tile_tint: Color = Color.WHITE
@export var start_map_color: Color = Color(0.9, 0.9, 0.85)

@export_group("Boss arena")
@export var boss_area_name: String = "Boss Arena"
@export var boss_tile_tint: Color = Color(0.85, 0.75, 1.0)
@export var boss_map_color: Color = Color(0.85, 0.3, 0.35)
