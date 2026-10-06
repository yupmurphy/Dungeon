extends Node
## Automated checks for the floor generator and the floor scene.
## Run:  <godot.exe> --headless --path . -- --floor-test     (exit code 0 = all passed)
## Options: --seeds=<first>:<count> checks other seeds; --generator-only skips the scene checks.

const FLOOR_DATA: FloorData = preload("res://resources/floors/floor_1.tres")
const SEED_COUNT: int = 8
## Seeds that are generated twice to check that the same seed gives the same map.
const DETERMINISM_SEEDS: int = 2

var _failures: int = 0
var _first_seed: int = 1
var _seed_count: int = SEED_COUNT


func run(options: Dictionary) -> void:
	var seeds: String = options.get("--seeds", "")
	if seeds.contains(":"):
		_first_seed = int(seeds.get_slice(":", 0))
		_seed_count = maxi(int(seeds.get_slice(":", 1)), 1)
	_check_generator()
	if not options.has("--generator-only"):
		await _check_scene()
	print("--- result: %s" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)


const GENERATOR_CHECKS: Array[String] = [
	"map has the size from FloorData",
	"every tile belongs to a zone (no empty space)",
	"map edge is rock",
	"start is floor, in the middle of the closed zone",
	"every floor tile reachable from start",
	"each zone is one connected block",
	"2-3 gates per open zone, spaced apart, each leads into its zone",
	"closed zone is sealed except at its gates",
	"open zones blend into each other (walkable borders)",
	"portal is floor, inside the boss arena",
	"boss arena has exactly one entrance",
	"boss arena is at the outer edge of an open zone",
	"same seed gives the same map",
]


func _check_generator() -> void:
	print("--- generator (%d seeds)" % _seed_count)
	var problems: Dictionary = {}
	var arrangements: Dictionary = {}
	var total_ms: int = 0
	var smallest_share: float = 1.0
	var sample: FloorLayout = null
	var phase_ms: Dictionary = {}
	for seed_value in range(_first_seed, _first_seed + _seed_count):
		var started: int = Time.get_ticks_msec()
		var layout: FloorLayout = FloorGenerator.generate(FLOOR_DATA, seed_value)
		total_ms += Time.get_ticks_msec() - started
		for phase: String in FloorGenerator.timings:
			phase_ms[phase] = phase_ms.get(phase, 0.0) + FloorGenerator.timings[phase] / _seed_count
		if sample == null:
			sample = layout
		smallest_share = minf(smallest_share, float(layout.floor_cell_count()) / (layout.size.x * layout.size.y))
		for label in _generator_problems(layout):
			if not problems.has(label):
				problems[label] = seed_value
		if seed_value < _first_seed + DETERMINISM_SEEDS and FloorGenerator.generate(FLOOR_DATA, seed_value).fingerprint() != layout.fingerprint():
			problems["same seed gives the same map"] = seed_value
		arrangements[_arrangement(layout)] = true
	var phases: Array[String] = []
	for phase: String in phase_ms:
		phases.append("%s %.0f" % [phase, phase_ms[phase]])
	print("  generation phases (ms): ", ", ".join(phases))

	for label in GENERATOR_CHECKS:
		_check(not problems.has(label), label + ("" if not problems.has(label) else " (seed %d)" % problems[label]))
	_check(arrangements.size() >= _seed_count * 0.6,
		"zone order, rotation and boss zone change with the seed (%d different of %d)" % [arrangements.size(), _seed_count])
	_check(smallest_share > 0.4, "most of the map is walkable (smallest: %.0f%% floor)" % (smallest_share * 100.0))
	var average: float = float(total_ms) / _seed_count
	# Generous on purpose: a loading screen will hide generation time later.
	_check(average < 6000.0, "generation is fast enough (%.0f ms average for %dx%d)" % [
		average, FLOOR_DATA.map_size.x, FLOOR_DATA.map_size.y])
	var monsters: int = sample.count_spawns(FloorLayout.SpawnKind.MONSTER)
	var props: int = sample.count_spawns(FloorLayout.SpawnKind.PROP)
	var torches: int = sample.count_spawns(FloorLayout.SpawnKind.TORCH)
	_check(monsters >= 150, "floor holds many monsters (%d planned)" % monsters)
	_check(props >= 300 and torches > 0, "floor holds lots of decoration (%d props, %d torches)" % [props, torches])


## Labels (from GENERATOR_CHECKS) of every structural rule this layout breaks.
func _generator_problems(layout: FloorLayout) -> Array[String]:
	var problems: Array[String] = []
	var w: int = layout.size.x
	var h: int = layout.size.y
	if layout.size != FLOOR_DATA.map_size:
		problems.append("map has the size from FloorData")
	var counts: PackedInt32Array = layout.slot_cell_counts()
	var assigned: int = 0
	for count in counts:
		assigned += count
	if assigned != w * h or counts.has(0):
		problems.append("every tile belongs to a zone (no empty space)")
	var edge_floor: bool = false
	for y in h:
		for x in w:
			if mini(mini(x, y), mini(w - 1 - x, h - 1 - y)) < FLOOR_DATA.border_min and layout.is_floor(x, y):
				edge_floor = true
	if edge_floor:
		problems.append("map edge is rock")
	var start: Vector2i = layout.start_cell
	if not layout.is_floor(start.x, start.y) or layout.slot_at(start.x, start.y) != layout.hub_slot \
			or Vector2(start).distance_to(Vector2(layout.center)) > 2.0:
		problems.append("start is floor, in the middle of the closed zone")
	if _unreachable_floor(layout) > 0:
		problems.append("every floor tile reachable from start")
	for slot in layout.slot_count:
		if not _zone_contiguous(layout, slot):
			problems.append("each zone is one connected block")

	var open_slots: Array[int] = []
	for slot in FLOOR_DATA.regions.size():
		if FLOOR_DATA.regions[slot].kind == RegionData.Kind.OPEN:
			open_slots.append(slot)
	var gates_by_slot: Dictionary = {}
	for gate in layout.gates:
		if not gates_by_slot.has(gate.slot):
			gates_by_slot[gate.slot] = []
		gates_by_slot[gate.slot].append(gate)
		if not layout.is_floor(gate.cell.x, gate.cell.y) or not layout.is_floor(gate.outside.x, gate.outside.y) \
				or layout.slot_at(gate.outside.x, gate.outside.y) != gate.slot:
			problems.append("2-3 gates per open zone, spaced apart, each leads into its zone")
	for slot in open_slots:
		var gates: Array = gates_by_slot.get(slot, [])
		if gates.size() < FLOOR_DATA.gates_per_zone.x or gates.size() > FLOOR_DATA.gates_per_zone.y:
			problems.append("2-3 gates per open zone, spaced apart, each leads into its zone")
		for i in gates.size():
			for j in range(i + 1, gates.size()):
				if Vector2(gates[i].cell).distance_to(Vector2(gates[j].cell)) < FLOOR_DATA.gate_spacing * 0.75:
					problems.append("2-3 gates per open zone, spaced apart, each leads into its zone")

	# Floor contacts between different zones.
	var leaks: int = 0
	var contacts: Dictionary = {}
	var boss_exits: Array[Vector2i] = []
	for y in h:
		for x in w - 1:
			for other: Vector2i in [Vector2i(x + 1, y), Vector2i(x, y + 1)]:
				if not layout.is_floor(x, y) or not layout.is_floor(other.x, other.y):
					continue
				var a: int = layout.slot_at(x, y)
				var b: int = layout.slot_at(other.x, other.y)
				if a == b:
					continue
				var key: Vector2i = Vector2i(mini(a, b), maxi(a, b))
				contacts[key] = contacts.get(key, 0) + 1
				var cell := Vector2i(x, y)
				if a == layout.hub_slot or b == layout.hub_slot:
					var near_gate: bool = layout.gates.any(func(g: FloorLayout.Gate) -> bool:
						return Vector2(g.cell).distance_to(Vector2(cell)) <= FLOOR_DATA.hub_ring + FLOOR_DATA.gate_width)
					if not near_gate:
						leaks += 1
				if a == layout.boss_slot or b == layout.boss_slot:
					boss_exits.append(cell)
	if leaks > 0:
		problems.append("closed zone is sealed except at its gates")
	for i in open_slots.size():
		for j in range(i + 1, open_slots.size()):
			if contacts.get(Vector2i(open_slots[i], open_slots[j]), 0) < 20:
				problems.append("open zones blend into each other (walkable borders)")

	var portal: Vector2i = layout.portal_cell
	if not layout.is_floor(portal.x, portal.y) or layout.slot_at(portal.x, portal.y) != layout.boss_slot:
		problems.append("portal is floor, inside the boss arena")
	var single_entrance: bool = not boss_exits.is_empty() and boss_exits.all(func(cell: Vector2i) -> bool:
		return Vector2(cell).distance_to(Vector2(layout.boss_entrance)) <= FLOOR_DATA.boss_arena_wall + 4)
	if not single_entrance:
		problems.append("boss arena has exactly one entrance")
	var half: float = minf(w, h) / 2.0
	if Vector2(layout.boss_center).distance_to(Vector2(layout.center)) < half * 0.6 \
			or not contacts.has(Vector2i(mini(layout.boss_zone, layout.boss_slot), maxi(layout.boss_zone, layout.boss_slot))):
		problems.append("boss arena is at the outer edge of an open zone")
	return problems


## Zone order around the hub (starting from the east), plus the boss zone: should change with the seed.
func _arrangement(layout: FloorLayout) -> String:
	var gates: Array[FloorLayout.Gate] = layout.gates.duplicate()
	gates.sort_custom(func(a: FloorLayout.Gate, b: FloorLayout.Gate) -> bool:
		return fposmod(Vector2(a.cell - layout.center).angle(), TAU) < fposmod(Vector2(b.cell - layout.center).angle(), TAU))
	var order: Array = gates.map(func(g: FloorLayout.Gate) -> int: return g.slot)
	var first_angle: int = roundi(fposmod(Vector2(gates[0].cell - layout.center).angle(), TAU) / (TAU / 8.0))
	return "%s/%d/%d" % [order, first_angle, layout.boss_zone]


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
	_check(floor_level.get_node("Tiles").get_child_count() == layout.slot_count,
		"one tinted tile layer per zone (%d zones + boss arena)" % layout.region_count)
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


## All cells (floor and rock) of a zone form one 4-connected block.
func _zone_contiguous(layout: FloorLayout, slot: int) -> bool:
	var slots: PackedByteArray = layout.slots_raw()
	var w: int = layout.size.x
	var first: int = slots.find(slot)
	if first < 0:
		return false
	var seen := PackedByteArray()
	seen.resize(slots.size())
	seen[first] = 1
	var stack := PackedInt32Array([first])
	var found: int = 1
	while not stack.is_empty():
		var i: int = stack[stack.size() - 1]
		stack.remove_at(stack.size() - 1)
		var x: int = i % w
		for j: int in [i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w, i + w]:
			if j >= 0 and j < slots.size() and seen[j] == 0 and slots[j] == slot:
				seen[j] = 1
				found += 1
				stack.append(j)
	if found != slots.count(slot):
		for i in slots.size():
			if slots[i] == slot and seen[i] == 0:
				print("    zone %d: %d of %d cells connected, first stray cell %s" % [
					slot, found, slots.count(slot), Vector2i(i % w, i / w)])
				break
	return found == slots.count(slot)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  ", label)
	else:
		_failures += 1
		print("  FAIL  ", label)
