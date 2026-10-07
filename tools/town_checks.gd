class_name TownChecks
extends RefCounted
const HOUSE_COUNT: int = 20
const BUILDING_COUNT: int = 24
const PLOT_COUNT: int = 4
const STALL_COUNT: int = 6
const SETTLE_FRAMES: int = 12
const COLLISION_TEST_DISTANCE: float = 40.0
const LEDGE_TEST_CELL: Vector2 = Vector2(40.5, 59.5)
const STAIRS_TEST_CELL: Vector2 = Vector2(50.5, 60.5)
const RAMP_TEST_CELL: Vector2 = Vector2(70.5, 49.5)
const LEDGE_TEST_MOVE: Vector2 = Vector2(0, -4)
const RAMP_TEST_MOVE: Vector2 = Vector2(-6, 0)
const TWO_STOREY_COUNT: int = 4
const STAIR_CURB_TEST_CELL: Vector2 = Vector2(46.5, 60.5)

static func unit_results() -> Dictionary:
	var data := TownData.new()
	var layout := TownLayout.new(data)
	var reached: Dictionary = layout.reachable()
	var ids: Dictionary = {}
	var houses: int = 0
	var doors_reached: bool = true
	var footprints_clear: bool = true
	for building in data.buildings:
		houses += int(building.kind == &"house")
		ids[building.id] = true
		doors_reached = doors_reached and reached.has(building.door_cell())
		for other in data.buildings:
			if building != other and building.footprint.intersects(other.footprint):
				footprints_clear = false
	var plots_clear: bool = true
	for plot in TownData.RESERVED_PLOTS:
		for y in range(plot.position.y, plot.end.y):
			for x in range(plot.position.x, plot.end.x):
				plots_clear = plots_clear and reached.has(Vector2i(x, y)) \
					and layout.ground(Vector2i(x, y)) == TownLayout.Ground.RESERVED
	var all_floor: int = 0
	for y in TownData.MAP_SIZE.y:
		for x in TownData.MAP_SIZE.x:
			all_floor += int(layout.walkable(Vector2i(x, y)))
	var ledges_blocked: bool = not layout.ledges.is_empty()
	for cell: Vector2i in layout.ledges:
		ledges_blocked = ledges_blocked and not layout.walkable(cell)
	var transitions_clear: bool = true
	for rect in [TownData.STAIRS, TownData.RAMP]:
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				transitions_clear = transitions_clear and reached.has(Vector2i(x, y))
	var props_clear: bool = true
	for prop in layout.props:
		for plot in TownData.RESERVED_PLOTS:
			props_clear = props_clear and not prop.footprint.intersects(plot)
		for building in data.buildings:
			props_clear = props_clear and not prop.footprint.has_point(building.door_cell())
	var floors_ok: bool = true
	var upper_count: int = 0
	for building in data.buildings:
		upper_count += int(building.floors == 2)
		floors_ok = floors_ok and (building.floors == (2 if building.id in TownData.TWO_STOREY_IDS else 1))
		if building.floors == 2:
			var one := building.duplicate() as TownBuildingData
			one.floors = 1
			var high: Texture2D = TownArt.building_texture(building)
			var low: Texture2D = TownArt.building_texture(one)
			floors_ok = floors_ok and high != low and high.get_height() - low.get_height() == TownArt.UPPER_FLOOR_HEIGHT \
				and building.footprint == one.footprint and building.door_cell() == one.door_cell()
	var stair: Image = TownArt.stair_image()
	var tread: Color = stair.get_pixel(TownArt.STAIR_BORDER_REF_WIDTH + 5, 4)
	var riser: Color = stair.get_pixel(TownArt.STAIR_BORDER_REF_WIDTH + 5, TownArt.STAIR_TREAD_HEIGHT + 1)
	var merged_fence: bool = false
	for prop in layout.props:
		merged_fence = merged_fence or (prop.kind == &"fence_vertical" and prop.footprint.size.y > 1)
	return {
		"town buildings: hall, tavern and two homes have two floors; footprint/door stay unchanged": floors_ok and upper_count == TWO_STOREY_COUNT,
		"town detail: whole stone flight has distinct treads/risers and continuous fence runs": tread != riser and merged_fence,
		"town relief: ledges block, stairs and ramp connect both levels": ledges_blocked and transitions_clear and layout.elevation(TownData.SQUARE.get_center()) == TownData.TERRACE_HEIGHT and layout.elevation(TownData.GATE_CELL) == 0.0,
		"town decor: yards, services and square leave doors and reserved plots clear": props_clear and layout.props.size() > data.props.size(),
		"town: 20 homes, hall, smith, bookshop, tavern and unique persistent IDs": houses == HOUSE_COUNT and data.buildings.size() == BUILDING_COUNT and ids.size() == BUILDING_COUNT,
		"town: all doors and every walkable cell connected to start": doors_reached and reached.size() == all_floor,
		"town: four accessible central plots remain empty and reserved": plots_clear and TownData.RESERVED_PLOTS.size() == PLOT_COUNT,
		"town: six market places and non-overlapping buildings": TownData.STALL_CELLS.size() == STALL_COUNT and footprints_clear,
	}

static func scene_results(town: TownLevel) -> Dictionary:
	var buildings: Array[Node] = town.get_tree().get_nodes_in_group("town_building")
	var ready_doors: bool = true
	for node in buildings:
		var building := node as TownBuilding
		ready_doors = ready_doors and building.door != null and building.has_node("ExteriorReturn") \
			and building.has_node("Footprint") and building.data.interior_scene == null
	var player: Player = town.player
	var hall := town.world.get_node("town_hall") as TownBuilding
	var former: Vector2 = player.position
	player.position = hall.door.global_position
	player.velocity = Vector2.ZERO
	var collided: bool = player.test_move(player.global_transform, Vector2.UP * GameScale.world(COLLISION_TEST_DISTANCE))
	player.position = LEDGE_TEST_CELL * GameScale.TILE_SIZE
	var wall_blocks: bool = player.test_move(player.global_transform, LEDGE_TEST_MOVE * GameScale.TILE_SIZE)
	player.position = STAIRS_TEST_CELL * GameScale.TILE_SIZE
	var stairs_clear: bool = not player.test_move(player.global_transform, LEDGE_TEST_MOVE * GameScale.TILE_SIZE)
	player.position = RAMP_TEST_CELL * GameScale.TILE_SIZE
	var ramp_clear: bool = not player.test_move(player.global_transform, RAMP_TEST_MOVE * GameScale.TILE_SIZE)
	player.position = STAIR_CURB_TEST_CELL * GameScale.TILE_SIZE
	var curbs_block: bool = player.test_move(player.global_transform, LEDGE_TEST_MOVE * GameScale.TILE_SIZE)
	player.position = former
	return {
		"town stairs: side coping blocks, full passage stays traversable and composite art is mounted": curbs_block and stairs_clear and town.ground.has_node("StairFlight"),
		"town physics: retaining wall blocks; wide stairs and ramp are traversable": wall_blocks and stairs_clear and ramp_clear,
		"town decor scene: planned props match actual reusable nodes": town.get_tree().get_nodes_in_group("town_decoration").size() == town.layout.props.size(),
		"town scene: reusable building collision, doors and return markers": buildings.size() == BUILDING_COUNT and ready_doors and collided,
		"town scene: normal player, HUD, y-sort and no active dungeon terrain": player.stats != null and player.health.max_health > 0 and town.world.y_sort_enabled and FloorLayout.active == null and town.has_node("HUD"),
		"town scene: all exterior cells painted and six market stalls": town.ground.get_used_cells().size() == TownData.MAP_SIZE.x * TownData.MAP_SIZE.y and town.get_tree().get_nodes_in_group("town_stall").size() == STALL_COUNT,
		"town scene: setup below budget, interaction exists and no enemies": town.setup_ms < TownLevel.SETUP_BUDGET_MS and InputMap.has_action("interact") and town.get_tree().get_nodes_in_group("enemy").is_empty(),
	}
