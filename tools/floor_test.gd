extends Node
## Automated checks for the floor generator and the floor scene.
## Run:  <godot.exe> --headless --path . -- --floor-test     (exit code 0 = all passed)

const FLOOR_DATA: FloorData = preload("res://resources/floors/floor_1.tres")
const SEED_COUNT: int = 40

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

		if layout.size != Vector2i(160, 160):
			problems["map is 160x160"] = seed_value
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

	for label in ["map is 160x160", "start cell is floor", "portal cell is floor",
			"portal is inside the boss arena", "every floor tile reachable from start",
			"boss arena has exactly one entrance", "boss arena far from start",
			"each region is one connected block", "same seed gives the same map"]:
		_check(not problems.has(label), label + ("" if not problems.has(label) else " (seed %d)" % problems[label]))
	_check(arrangements.size() >= SEED_COUNT * 0.8,
		"regions land in different places (%d different layouts of %d)" % [arrangements.size(), SEED_COUNT])
	_check(smallest_floor > 6000, "floors are big (smallest: %d floor tiles)" % smallest_floor)
	var average: float = float(total_ms) / SEED_COUNT
	_check(average < 500.0, "generation is fast (%.0f ms average)" % average)


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

	_check(player.global_position.distance_to((Vector2(layout.start_cell) + Vector2(0.5, 0.5)) * 16.0) < 1.0,
		"player starts in the start room")
	_check(floor_level.get_node("Tiles").get_child_count() == 5, "one tinted tile layer per zone (start, 3 regions, boss)")
	var enemies: int = get_tree().get_nodes_in_group("enemy").size()
	_check(enemies >= 20, "monsters spawned (%d)" % enemies)
	activator.refresh()
	var active: int = activator.active_count()
	_check(active < enemies / 2, "far monsters are paused (%d of %d active)" % [active, enemies])
	_check(floor_level.portal != null and not floor_level.portal.active, "portal exists and is dormant")

	_check(exploration.is_explored(layout.start_cell), "start area is revealed")
	_check(not exploration.is_explored(layout.portal_cell), "portal area starts hidden (fog)")
	_check(exploration.explored_ratio() < 0.1, "most of the map starts hidden (%.0f%% seen)" % (exploration.explored_ratio() * 100.0))

	for action in ["map", "debug_new_seed", "debug_reveal_map", "debug_invincible", "debug_show_seed"]:
		_check(InputMap.has_action(action) and InputMap.action_get_events(action).size() > 0,
			"input action '%s' mapped" % action)

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
