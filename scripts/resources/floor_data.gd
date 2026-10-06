class_name FloorData
extends Resource
## One dungeon floor: size, layout settings, zones and boss. The layout itself is generated from a seed.
## The first CLOSED region is the hub in the middle (start); the OPEN regions surround it as sectors.

@export var floor_number: int = 1
@export var display_name: String = "Floor 1"
@export var regions: Array[RegionData] = []
## Floor boss, guards the portal (stage 3).
@export var boss: MonsterData

@export_group("Layout")
## Map size in tiles.
@export var map_size: Vector2i = Vector2i(480, 480)
## Radius of the closed hub zone, as a share of half the map size.
@export_range(0.2, 0.6) var hub_radius: float = 0.4
## The hub's edge wobbles in and out by up to this many tiles.
@export var hub_radius_variation: int = 14
## Thickness of the rock ring that closes the hub (crossed only by the gates).
@export var hub_ring: int = 6
## Width of the gate passages through the ring.
@export var gate_width: int = 5
## Open zones get between these shares of the circle before normalizing (bigger gap = more uneven zones).
@export var open_zone_share_min: float = 1.0
@export var open_zone_share_max: float = 1.4
## How far (radians) the borders between open zones meander.
@export var open_zone_wobble: float = 0.45
## Rock along the map's edge: thickness varies between these.
@export var border_min: int = 5
@export var border_max: int = 13
## Boss arena: inner half-size (ellipse radii) and wall thickness.
@export var boss_arena_radii: Vector2i = Vector2i(22, 17)
@export var boss_arena_wall: int = 3

@export_group("Content")
## One wall torch every this many tiles along the closed zone's walls.
@export var torch_spacing: int = 7
## Streaming: the map is loaded around the player in square chunks of this many tiles.
@export var chunk_size: int = 32
## No monsters closer than this to the start.
@export var safe_start_radius: int = 14

@export_group("Boss arena")
@export var boss_area_name: String = "Boss Arena"
@export var boss_tile_tint: Color = Color(0.85, 0.75, 1.0)
@export var boss_map_color: Color = Color(0.85, 0.3, 0.35)
