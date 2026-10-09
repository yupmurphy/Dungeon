extends Node
## Town checks: the scene is built the way the guide describes and still works after hand edits.
## Run:  <godot.exe> --headless --path . -- --town-test     (exit code 0 = all passed)

const TOWN: String = "res://scenes/town/town.tscn"
const LANDMARKS: Array[String] = ["Alchemist", "HuntersGuild", "TownHall", "GeneralStore", "Smithy", "Inn", "Temple"]
const LAYERS: Array[String] = ["Grass", "Water", "Roads", "Paving"]
const T: int = 32
const SETTLE_FRAMES: int = 10

var _failures: int = 0


func run(_options: Dictionary) -> void:
	get_tree().change_scene_to_file.call_deferred(TOWN)
	for i in SETTLE_FRAMES:
		await get_tree().physics_frame
	var town: Node = get_tree().current_scene
	var player := town.get_node("World/Player") as Player

	print("--- scene layout (editable layers and nodes)")
	for layer_name in LAYERS:
		_check(town.get_node_or_null(layer_name) is TileMapLayer, "TileMapLayer %s exists" % layer_name)
	for group_name in ["World/Walls", "World/Buildings", "World/Props", "World/Trees", "SideWalls", "GroundProps"]:
		_check(town.get_node_or_null(group_name) != null, "node %s exists" % group_name)
	_check((town.get_node("World") as Node2D).y_sort_enabled, "World is y-sorted (walk behind roofs and trees)")
	_check(town.get_node_or_null("Lighting") is TownLighting, "day / night lighting exists")
	_check(town.get_node_or_null("DungeonExit") is Area2D, "exit to the dungeon exists")

	print("--- buildings")
	var buildings: Array[TownBuilding] = []
	for node in town.get_node("World/Buildings").get_children():
		if node is TownBuilding:
			buildings.append(node)
	_check(buildings.size() >= 40, "the town has at least 40 buildings (%d)" % buildings.size())
	for landmark in LANDMARKS:
		var building := town.get_node_or_null("World/Buildings/" + landmark) as TownBuilding
		_check(building != null and building.scene_file_path.begins_with("res://scenes/town/buildings/"),
			"%s is its own reusable scene" % landmark)
	var guild := town.get_node("World/Buildings/HuntersGuild") as TownBuilding
	var biggest: bool = true
	for building in buildings:
		if building != guild and building.width * building.wall_height > guild.width * guild.wall_height:
			biggest = false
	_check(biggest, "the Hunters Guild is the biggest building")
	var roads := town.get_node("Roads") as TileMapLayer
	var paving := town.get_node("Paving") as TileMapLayer
	var blocked_doors: PackedStringArray = []
	for building in buildings:
		if building.door_x < 0:
			continue
		var cell := Vector2i(int(building.position.x / T) + building.door_x, int(building.position.y / T))
		var street: bool = paving.get_cell_source_id(cell) != -1 \
			or roads.get_cell_source_id(cell) == TownTiles.Source.DIRT
		if not street:
			blocked_doors.append(String(building.name))
	_check(blocked_doors.is_empty(), "every door opens on a street or the square %s" % blocked_doors)
	var overlaps: PackedStringArray = []
	for i in buildings.size():
		for j in range(i + 1, buildings.size()):
			if _footprint(buildings[i]).intersects(_footprint(buildings[j])):
				overlaps.append("%s/%s" % [buildings[i].name, buildings[j].name])
	_check(overlaps.is_empty(), "no two buildings overlap %s" % overlaps)
	var looks: Dictionary = {}
	for building in buildings:
		looks["%s|%s|%d" % [building.wall_style, building.roof_color, building.wall_height]] = true
	_check(looks.size() >= 12, "houses vary (%d different wall / roof / height looks)" % looks.size())

	print("--- movement")
	_check(_free(player.global_position), "the player starts on free ground")
	_check(_blocked(player, Vector2(43.6, 51.5), Vector2(0, 6)), "the south wall blocks")
	_check(not _blocked(player, Vector2(41.5, 52.5), Vector2(0, 6)), "the south gate lets you through")
	_check(not _blocked(player, Vector2(41.5, 9.5), Vector2(0, -7)), "the north gate lets you through")
	_check(_blocked(player, Vector2(70.5, 9.5), Vector2(0, -6)), "the north wall blocks")
	_check(not _free(Vector2(9.5, 25.5) * T), "the stream blocks")
	_check(_free(Vector2(9.5, 38.5) * T), "the bridge crosses the stream")
	_check(not _free(Vector2(9.5, 40.5) * T), "beside the bridge the stream still blocks (no walking on water)")
	var water := town.get_node("Water") as TileMapLayer
	_check(water.get_cell_source_id(Vector2i(9, 38)) == TownTiles.Source.WATER,
		"the stream flows under the bridge (water, not a dirt gap)")
	_check(_blocked(player, Vector2(31.5, 26), Vector2(0, -3)), "a building blocks")

	print("--- map (minimap and M)")
	var town_map := get_tree().get_first_node_in_group(&"map_source") as TownMap
	_check(town_map != null and town_map.map_size() == Vector2i(84, 62), "the town has a map the size of the town")
	_check(town_map != null and town_map.legend.size() == LANDMARKS.size() + 2, "the map legend lists the landmarks, the dungeon road and the gates")
	var map_overlay := town.get_node("HUD/Root/MapOverlay") as MapOverlay
	_check(map_overlay.exploration == town_map and map_overlay.title == "Town - Map", "the big map (M) shows the town map")

	print("--- details and night")
	var smoke: int = 0
	var chimneys: int = 0
	for building in buildings:
		if building.chimney_x >= 0:
			chimneys += 1
		for child in building.get_children():
			if child is TownSmoke:
				smoke += 1
	_check(chimneys > 0 and smoke == chimneys, "every chimney smokes (%d / %d)" % [smoke, chimneys])
	var lighting := town.get_node("Lighting") as TownLighting
	lighting.night = true
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	var lamps_lit: bool = true
	var lamps: int = 0
	for node in town.get_node("World/Props").get_children():
		if node is TownProp and node.prop == "lantern":
			lamps += 1
			lamps_lit = lamps_lit and node.lit
	_check(lamps >= 20 and lamps_lit, "at night the %d lamps are lit" % lamps)
	_check(guild.lit and guild.get_children().any(func(c: Node) -> bool: return c is PointLight2D and c.visible),
		"at night windows give light")
	lighting.night = false
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	_check(not guild.lit, "by day the lights are off")

	print("town test: %s" % ("all passed" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)


func _footprint(building: TownBuilding) -> Rect2:
	return Rect2(building.position.x, building.position.y - building.roof_height * T, building.width * T,
		building.roof_height * T).grow(-1.0)


## True if nothing solid (wall, building, prop, water) is at this point.
func _free(point: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collision_mask = 1
	return get_viewport().world_2d.direct_space_state.intersect_point(query).is_empty()


## True if the player, standing at `from` (tiles), would hit something moving by `motion` (tiles).
func _blocked(player: Player, from: Vector2, motion: Vector2) -> bool:
	var start := Transform2D(0.0, from * T)
	return player.test_move(start, motion * T)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  ", label)
	else:
		_failures += 1
		print("  FAIL  ", label)
