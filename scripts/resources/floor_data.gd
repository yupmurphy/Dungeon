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
## Map size in tiles: THE setting for how big the floor is. Zones scale with it (the hub radius is a share
## of it); monster and decoration amounts follow the floor area (densities in RegionData).
@export var map_size: Vector2i = Vector2i(900, 900)
## Radius of the closed hub zone, as a share of half the map size.
@export_range(0.2, 0.6) var hub_radius: float = 0.36
## The hub's edge wobbles in and out by up to this share of its radius.
@export_range(0.0, 0.3) var hub_radius_variation: float = 0.09
## Thickness of the rock ring that closes the hub (crossed only by the gates).
@export var hub_ring: int = 6
## Width of the gate passages through the ring.
@export var gate_width: int = 5
## How many gates lead from the hub into each open zone (random between x and y).
@export var gates_per_zone: Vector2i = Vector2i(2, 3)
## Minimum distance in tiles between two gates into the same zone (fewer gates if the zone's edge is short).
@export var gate_spacing: int = 45
## Open zones get between these shares of the circle before normalizing (bigger gap = more uneven zones).
@export var open_zone_share_min: float = 1.0
@export var open_zone_share_max: float = 1.4
## How far (radians) the borders between open zones meander.
@export var open_zone_wobble: float = 0.45
## Rock along the map's edge: thickness varies between these.
@export var border_min: int = 5
@export var border_max: int = 13
## Boss arena: inner half-size (ellipse radii) and wall thickness.
@export var boss_arena_radii: Vector2i = Vector2i(26, 20)
@export var boss_arena_wall: int = 3

@export_group("Shape")
## The playable land is a long organic capsule from one corner of the map to the opposite one (FloorShape); the rest
## is impassable border (rock, chasms, dense forest). Share of the map it covers: random between x and y.
@export var shape_coverage: Vector2 = Vector2(0.7, 0.95)
## The capsule's ends stop this share of the diagonal before the corners (rounded tips, no square corner).
@export_range(0.0, 0.3) var shape_tip_inset: float = 0.1
## Big bends and bulges (tiles the shape is pushed around by slow noise), and small bumps along its edge.
@export var shape_warp: float = 70.0
@export var shape_roughness: float = 10.0
## Border along the map's edge, so the land never touches it in a straight line: depth between x and y tiles.
@export var shape_edge_depth: Vector2i = Vector2i(4, 65)
## Share of the border drawn as chasms and as dense forest (the rest is rock).
@export_range(0.0, 1.0) var border_chasm_share: float = 0.3
@export_range(0.0, 1.0) var border_thicket_share: float = 0.35

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
