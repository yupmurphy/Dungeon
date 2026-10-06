extends Node
## Automated checks for the floor generator and the floor scene.
## Run:  <godot.exe> --headless --path . -- --floor-test     (exit code 0 = all passed)

const FLOOR_DATA: FloorData = preload("res://resources/floors/floor_1.tres")
const SEED_COUNT: int = 12

var _failures: int = 0


func run(_options: Dictionary) -> void:
	_check_generator()
	await _check_scene()
	print("--- result: %s" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)


func _check_generator() -> void:
	print("--- generator (%d seeds)" % SEED_COUNT)
	var problems: Dictionary = {}
	var arrangements: Dictionary = {}
	var total_ms: int = 0
	var smallest_floor: int = 1 << 30
	for seed_value in range(1, SEED_COUNT + 1):
		var started: int = Time.get_ticks_msec()
		var layout: FloorLayout = FloorGenerator.generate(FLOOR_DATA, seed_value)
		total_ms += Time.get_ticks_msec() - started
		smallest_floor = mini(smallest_floor, layout.floor_cell_count())

		if layout.size != FLOOR_DATA.map_size:
			problems["map has the size from FloorData"] = seed_value
		if not layout.is_floor(layout.start_cell.x, layout.start_cell.y):
			problems["start cell is floor"] = seed_value
		if not layout.is_floor(layout.portal_cell.x, layout.portal_cell.y):
			problems["portal cell is floor"] = seed_value
		if not layout.boss_room.rect.has_point(layout.portal_cell):
			problems["portal is inside the boss arena"] = seed_value
		if _unreachable_floor(layout) > 0:
			problems["every floor tile reachable from start"] = seed_value
		var boss_links: int = 0
		for link in layout.connections:
			if link.has(layout.boss_sector):
				boss_links += 1
		if boss_links != 1:
			problems["boss arena has exactly one entrance"] = seed_value
		var start_sector: Vector2i = layout.sector_of(layout.start_cell)
		var sector_distance: int = absi(start_sector.x - layout.boss_sector.x) + absi(start_sector.y - layout.boss_sector.y)
		if sector_distance < 3:
			problems["boss arena far from start"] = seed_value
		for slot in range(1, layout.region_count + 1):
			if not _region_contiguous(layout, slot):
				problems["each region is one connected block"] = seed_value
		if FloorGenerator.generate(FLOOR_DATA, seed_value).fingerprint() != layout.fingerprint():
			problems["same seed gives the same map"] = seed_value

		var arrangement: Array = []
		for sector in layout.all_sectors():
			arrangement.append(layout.sector_slot(sector))
		arrangements[str(arrangement)] = true

	for label in ["map has the size from FloorData", "start cell is floor", "portal cell is floor",
			"portal is inside the boss arena", "every floor tile reachable from start",
			"boss arena has exactly one entrance", "boss arena far from start",
			"each region is one connected block", "same seed gives the same map"]:
		_check(not problems.has(label), label + ("" if not problems.has(label) else " (seed %d)" % problems[label]))
	_check(arrangements.size() >= SEED_COUNT * 0.8,
		"regions land in different places (%d different layouts of %d)" % [arrangements.size(), SEED_COUNT])
	_check(smallest_floor > 30000, "floors are big (smallest: %d floor tiles)" % smallest_floor)
	var average: float = float(total_ms) / SEED_COUNT
	_check(average < 3000.0, "generation is fast enough (%.0f ms average for %dx%d)" % [
		average, FLOOR_DATA.map_size.x, FLOOR_DATA.map_size.y])
	var sample: FloorLayout = FloorGenerator.generate(FLOOR_DATA, 1)
	var monsters: int = sample.count_spawns(FloorLayout.SpawnKind.MONSTER)
	var props: int = sample.count_spawns(FloorLayout.SpawnKind.PROP)
	_check(monsters >= 150, "floor holds many monsters (%d planned)" % monsters)
	_check(props >= 300, "floor holds lots of decoration (%d props, %d torches)" % [
		props, sample.count_spawns(FloorLayout.SpawnKind.TORCH)])
	var hall_areas: Array = []
	for room in sample.rooms:
		if room.kind == FloorLayout.RoomKind.NORMAL:
			hall_areas.append(room.area())
	hall_areas.sort()
	_check(hall_areas[hall_areas.size() >> 1] >= 900, "halls are big (median %d floor tiles)" % hall_areas[hall_areas.size() >> 1])
	_check(sample.connections.size() <= sample.all_sectors().size() + 6,
		"few corridors (%d for %d halls)" % [sample.connections.size(), sample.rooms.size()])


func _check_scene() -> void:
	print("--- floor scene")
	for i in 5:
		await get_tree().process_frame
	var floor_level := get_tree().current_scene as FloorLevel
	_check(floor_level != null, "main scene is a dungeon floor")
	if floor_level == null:
		return
	var layout: FloorLayout = floor_level.layout
	var player := get_tree().get_first_node_in_group("player") as Player
	var exploration := get_tree().get_first_node_in_group("exploration") as ExplorationMap
	var activator := floor_level.get_node("EnemyActivator") as EnemyActivator

	_check(player.global_position.distance_to((Vector2(layout.start_cell) + Vector2(0.5, 0.5)) * GameScale.TILE_SIZE) < 1.0,
		"player starts in the start room")
	_check(floor_level.get_node("Tiles").get_child_count() == 5, "one tinted tile layer per zone (start, 3 regions, boss)")
	var chunks: ChunkManager = floor_level.chunks
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemy")
	var stream_reach: float = (chunks.unload_radius + 1) * layout.chunk_size * GameScale.TILE_SIZE
	var all_near: bool = enemies.all(func(e: Node2D) -> bool:
		return e.global_position.distance_to(player.global_position) <= stream_reach)
	_check(enemies.size() < layout.count_spawns(FloorLayout.SpawnKind.MONSTER) and all_near,
		"only monsters near the player exist as nodes (%d of %d)" % [enemies.size(), layout.count_spawns(FloorLayout.SpawnKind.MONSTER)])
	_check(chunks.loaded_count() <= (chunks.load_radius * 2 + 1) * (chunks.load_radius * 2 + 1),
		"only chunks around the player are loaded (%d)" % chunks.loaded_count())
	activator.refresh()
	var active_radius: float = GameScale.tiles_to_pixels(activator.active_radius_tiles)
	var far_active: bool = enemies.any(func(e: Node2D) -> bool:
		return e.process_mode != Node.PROCESS_MODE_DISABLED and e.global_position.distance_to(player.global_position) > active_radius)
	_check(not far_active, "monsters outside the activation radius are paused (%d active of %d)" % [activator.active_count(), enemies.size()])
	_check(floor_level.portal != null and not floor_level.portal.active, "portal exists and is dormant")

	_check(exploration.is_explored(layout.start_cell), "start area is revealed")
	_check(not exploration.is_explored(layout.portal_cell), "portal area starts hidden (fog)")
	_check(exploration.explored_ratio() < 0.02, "most of the map starts hidden (%.0f%% seen)" % (exploration.explored_ratio() * 100.0))

	for action in ["map", "debug_new_seed", "debug_reveal_map", "debug_invincible", "debug_show_seed"]:
		_check(InputMap.has_action(action) and InputMap.action_get_events(action).size() > 0,
			"input action '%s' mapped" % action)

	await _check_streaming(floor_level, player)

	_press(KEY_F2)
	await get_tree().process_frame
	_check(exploration.explored_ratio() > 0.99, "F2 reveals the whole map")

	_press(KEY_F3)
	await get_tree().process_frame
	_check(player.hurtbox.god_mode and not player.hurtbox.receive_hit(50.0, Vector2.RIGHT, 0.0),
		"F3 makes the player invincible")
	_press(KEY_F3)
	await get_tree().process_frame
	_check(not player.hurtbox.god_mode, "F3 again turns invincibility off")

	_press(KEY_M)
	await get_tree().process_frame
	var map_overlay := floor_level.get_node("HUD/Root/MapOverlay") as Control
	_check(map_overlay.visible, "M opens the big map")
	_press(KEY_M)
	await get_tree().process_frame
	_check(not map_overlay.visible, "M again closes it")

	var seed_before: int = floor_level.current_seed
	var fingerprint_before: int = layout.fingerprint()
	_press(KEY_R)
	var reloaded: FloorLevel = await _wait_for_new_floor(floor_level)
	_check(reloaded != null and reloaded.current_seed == seed_before
		and reloaded.layout.fingerprint() == fingerprint_before, "R restarts the same layout (same seed)")

	if reloaded != null:
		_press(KEY_F1)
		var regenerated: FloorLevel = await _wait_for_new_floor(reloaded)
		_check(regenerated != null and regenerated.current_seed != seed_before
			and regenerated.layout.fingerprint() != fingerprint_before, "F1 generates a new layout with a new seed")


## Walk (teleport) to the far end of the map and back: chunks load/unload, killed monsters stay dead.
func _check_streaming(floor_level: FloorLevel, player: Player) -> void:
	print("--- chunk streaming")
	var layout: FloorLayout = floor_level.layout
	var chunks: ChunkManager = floor_level.chunks
	var start_position: Vector2 = player.global_position
	var start_chunk: Vector2i = layout.chunk_of(layout.start_cell)
	var portal_chunk: Vector2i = layout.chunk_of(layout.portal_cell)

	# Two monsters near the start: one gets killed, one is left alive.
	var nearby: Array[Node] = get_tree().get_nodes_in_group("enemy")
	var killed_id: int = -1
	var spared_id: int = -1
	if nearby.size() >= 2:
		killed_id = nearby[0].get_meta("spawn_id")
		spared_id = nearby[1].get_meta("spawn_id")
		(nearby[0] as Enemy).health.take_damage(99999.0)
	await get_tree().create_timer(0.6).timeout

	await _teleport(player, (Vector2(layout.portal_cell) + Vector2(0.5, 0.5)) * GameScale.TILE_SIZE)
	var boss_layer := floor_level.get_node("Tiles/Region%d" % layout.boss_slot) as TileMapLayer
	_check(chunks.is_loaded(portal_chunk) and boss_layer.get_cell_source_id(layout.portal_cell) != -1,
		"chunks load around the player after moving far away")
	_check(not chunks.is_loaded(start_chunk), "chunks left behind are unloaded")
	var start_layer := floor_level.get_node("Tiles/Region0") as TileMapLayer
	_check(start_layer.get_cell_source_id(layout.start_cell) == -1, "unloaded chunks have no tiles")
	var stray: bool = get_tree().get_nodes_in_group("enemy").any(func(e: Node2D) -> bool:
		return e.global_position.distance_to(start_position) < 64.0 * GameScale.TILE_SIZE)
	_check(not stray, "monsters left behind are removed")

	await _teleport(player, start_position)
	_check(killed_id >= 0, "there were monsters near the start to test with")
	if killed_id >= 0:
		var respawned: bool = get_tree().get_nodes_in_group("enemy").any(func(e: Node) -> bool:
			return e.get_meta("spawn_id", -1) == killed_id)
		_check(chunks.is_spawn_dead(killed_id) and not respawned, "a killed monster stays dead after coming back")
		_check(chunks.is_spawn_alive(spared_id), "a living monster is back after coming back")
	var average_ms: float = chunks.load_time_total_usec / 1000.0 / maxf(chunks.loads_done, 1.0)
	_check(average_ms < 10.0, "chunk loading is fast (%.1f ms per chunk, %d loads)" % [average_ms, chunks.loads_done])


func _teleport(player: Player, target: Vector2) -> void:
	player.global_position = target
	for i in 90:
		await get_tree().physics_frame
	await get_tree().process_frame


func _wait_for_new_floor(old: Node) -> FloorLevel:
	for i in 120:
		await get_tree().process_frame
		var current := get_tree().current_scene as FloorLevel
		if current != null and current != old and current.layout != null:
			return current
	return null


func _press(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)


func _unreachable_floor(layout: FloorLayout) -> int:
	var seen: Dictionary = {layout.start_cell: true}
	var queue: Array[Vector2i] = [layout.start_cell]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for offset: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var next: Vector2i = cell + offset
			if not seen.has(next) and layout.is_floor(next.x, next.y):
				seen[next] = true
				queue.append(next)
	return layout.floor_cell_count() - seen.size()


func _region_contiguous(layout: FloorLayout, slot: int) -> bool:
	var sectors: Array[Vector2i] = []
	for sector in layout.all_sectors():
		if layout.sector_slot(sector) == slot:
			sectors.append(sector)
	if sectors.is_empty():
		return false
	var seen: Dictionary = {sectors[0]: true}
	var queue: Array[Vector2i] = [sectors[0]]
	while not queue.is_empty():
		var sector: Vector2i = queue.pop_back()
		for neighbor in layout.sector_neighbors(sector):
			if not seen.has(neighbor) and layout.sector_slot(neighbor) == slot:
				seen[neighbor] = true
				queue.append(neighbor)
	return seen.size() == sectors.size()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  ", label)
	else:
		_failures += 1
		print("  FAIL  ", label)
