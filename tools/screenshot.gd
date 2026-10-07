extends Node
## Debug tool: saves one rendered frame, optionally with a staged situation.
## Run (NOT headless, it needs a GPU):
##   <godot.exe> --path . -- --screenshot=<file.png> --mode=<mode> [--seed=<n>]
## Modes on the dungeon floor: idle, map (whole map revealed, big map open), sheet (character page, --hover=stat:2), overview,
## gate / arena / start (zoomed out view of a hub gate, the boss arena entrance, the start cave).
## Modes in the combat test room: fight, room, goblin (stage 1 paper-doll/telegraph preview).

const WALL_SIDES: Dictionary = {"south": Vector2i.DOWN, "north": Vector2i.UP,
	"east": Vector2i.RIGHT, "west": Vector2i.LEFT}
const TORCH_PREVIEW_DISTANCE: int = 2
const CAVE_PREVIEW_SEARCH_TILES: int = 55
const CAVE_PREVIEW_ZOOM: float = 1.0
const SETTLE_FRAMES: int = 40
const TEST_ROOM: String = "res://scenes/levels/test_room.tscn"
const GOBLIN_NAMES: Array[String] = ["Goblin1", "Goblin2", "Goblin3"]
const GOBLIN_OFFSETS: Array[Vector2] = [Vector2(-52, -14), Vector2(36, -10), Vector2(60, 20)]
const GOBLIN_PREVIEW_PERCEPTION: int = 20
const GOBLIN_WINDUP_REMAINING: float = 0.2
const GOBLIN_PREVIEW_FRAMES: int = 5


func run(options: Dictionary) -> void:
	var output: String = options.get("--screenshot", "")
	if output.is_empty():
		output = "user://screenshot.png"
	var mode: String = options.get("--mode", "idle")
	if mode in ["town", "town_overview"]:
		get_tree().change_scene_to_file.call_deferred("res://scenes/town/town.tscn")
	elif mode in ["fight", "room", "goblin"]:
		get_tree().change_scene_to_file.call_deferred(TEST_ROOM)

	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	var room: Node = get_tree().current_scene
	var player := room.get_node("World/Player") as Player
	# --equip=<id>,<id> wears these pieces, --body=male|female (see resources/equipment/).
	if options.has("--body"):
		player.equipment.set_body_type(options["--body"])
	for id in String(options.get("--equip", "")).split(",", false):
		player.equipment.equip(Equipment.find(StringName(id)))
	if options.has("--perception"):
		player.stats.perception = int(options["--perception"])

	match mode:
		"town", "town_overview":
			player.set_physics_process(false)
			var town_camera := player.get_node("Camera2D") as Camera2D
			town_camera.position_smoothing_enabled = false
			town_camera.zoom = TownLevel.MAP_ZOOM if mode == "town_overview" else Vector2(0.7, 0.7)
			player.position = (Vector2(TownData.START_CELL) + Vector2(0.5, 0.5)) * GameScale.TILE_SIZE
			if mode == "town_overview":
				player.position = Vector2(TownData.MAP_SIZE) * GameScale.TILE_SIZE / 2.0
			player.character.loop("idle", LpcCatalog.Direction.DOWN)
		"goblin":
			# Stage real LPC enemies without random attacks while checking their composition.
			for enemy in get_tree().get_nodes_in_group("enemy"):
				(enemy as Enemy).set_physics_process(false)
			player.set_physics_process(false)
			player.stats.perception = GOBLIN_PREVIEW_PERCEPTION
			player.character.loop("idle", LpcCatalog.Direction.DOWN)
			(room.get_node("Darkness") as CanvasModulate).visible = false
			var camera := player.get_node("Camera2D") as Camera2D
			camera.position_smoothing_enabled = false
			for index in GOBLIN_NAMES.size():
				var goblin := room.get_node("World/" + GOBLIN_NAMES[index]) as Enemy
				goblin.global_position = player.global_position + GameScale.world_vector(GOBLIN_OFFSETS[index])
				var facing: Vector2 = player.global_position - goblin.global_position
				goblin.character.loop("idle", LpcCharacter.direction_of(facing))
				if index == 0:
					goblin.melee_behavior.begin_windup(facing.normalized())
					goblin.melee_behavior.time_left = GOBLIN_WINDUP_REMAINING
					goblin._state_left = GOBLIN_WINDUP_REMAINING
				goblin._update_tint()
			for frame in GOBLIN_PREVIEW_FRAMES:
				await get_tree().process_frame
		"fight":
			# Spider freshly hit by the player, bat in the middle of its red wind-up.
			var spider := room.get_node("World/Spider") as Enemy
			var bat := room.get_node("World/Bat") as Enemy
			spider.global_position = player.global_position + GameScale.world_vector(Vector2(22, 0))
			bat.global_position = player.global_position + GameScale.world_vector(Vector2(-26, -8))
			for i in 10:
				await get_tree().physics_frame
			bat.melee_behavior.begin_windup(Vector2.RIGHT)
			bat.melee_behavior.time_left = 0.15
			bat._state_left = 0.15
			player.attack_pivot.rotation = 0.0
			player._swing_left = Player.ATTACK_ACTIVE_TIME
			player.hitbox.damage = 20.0
			# --crit / --miss force the outcome (see Combat.forced_rolls).
			if options.has("--crit"):
				Combat.forced_rolls.assign([0.99, 0.0])
			elif options.has("--miss"):
				Combat.forced_rolls.assign([0.0, 0.99])
			player.hitbox.activate(0.12)
			player.character.play(player.character.attack_action(), LpcCatalog.Direction.RIGHT, Player.ATTACK_ANIMATION_TIME)
			# Wait until the hit actually lands, then a few frames for the effects to appear.
			for i in 60:
				if spider.health.current_health < spider.health.max_health or GameFeel._layer.get_child_count() > 0:
					break
				await get_tree().physics_frame
			for i in 4:
				await get_tree().process_frame
		"overview", "room":
			# Zoomed out, without darkness, to check the tile layout.
			var camera := player.get_node("Camera2D") as Camera2D
			camera.zoom = Vector2(0.75, 0.75) if mode == "room" else Vector2(0.4, 0.4)
			camera.position_smoothing_enabled = false
			(room.get_node("Darkness") as CanvasModulate).visible = false
			var fog := room.get_node_or_null("Exploration/Fog") as CanvasItem
			if fog != null:
				fog.visible = false
			for i in 5:
				await get_tree().process_frame
		"gate", "arena", "start", "place", "cave", "atmosphere":
			# Zoomed out, without darkness: a gate of the closed zone, the boss arena entrance, the start,
			# or a notable place (--place=<kind>, e.g. goblin_camp, mine, oasis, spider_nest, bridge).
			var floor_layout: FloorLayout = (room as FloorLevel).layout
			var target: Vector2i = floor_layout.start_cell
			if mode == "atmosphere":
				var side: Vector2i = WALL_SIDES.get(options.get("--wall-side", "south"), Vector2i.DOWN)
				var masonry: bool = options.get("--wall-material", "natural") == "masonry"
				var found_torch: bool = false
				for spawn in floor_layout.spawns:
					if spawn.kind == FloorLayout.SpawnKind.TORCH and spawn.slot == floor_layout.hub_slot \
							and spawn.wall_direction == side \
							and floor_layout.is_masonry(spawn.cell.x, spawn.cell.y) == masonry:
						target = _torch_preview_cell(floor_layout, spawn)
						found_torch = true
						break
				if not found_torch:
					push_error("No torch matches the requested material and direction for this seed.")
					get_tree().quit(1)
					return
			elif mode == "cave":
				target = _cave_preview_cell(floor_layout)
			elif mode == "gate":
				target = floor_layout.gates[0].cell
			elif mode == "arena":
				target = floor_layout.boss_entrance
			elif mode == "place":
				var kind := StringName(options.get("--place", "goblin_camp"))
				for feature in floor_layout.features:
					if feature.kind == kind:
						target = feature.cell
						break
			player.set_physics_process(false)
			for enemy in get_tree().get_nodes_in_group("enemy"):
				(enemy as Enemy).set_physics_process(false)
			player.hurtbox.god_mode = true
			player.global_position = (Vector2(target) + Vector2(0.5, 0.5)) * GameScale.TILE_SIZE
			var camera := player.get_node("Camera2D") as Camera2D
			camera.zoom = Vector2.ONE * float(options.get("--zoom", str(CAVE_PREVIEW_ZOOM) if mode in ["cave", "atmosphere"] else "0.5"))
			camera.position_smoothing_enabled = false
			(room.get_node("Darkness") as CanvasModulate).visible = options.has("--dark")
			(room.get_node("Exploration/Fog") as CanvasItem).visible = false
			for i in 60:
				await get_tree().physics_frame
		"sheet":
			# Character sheet open; --hover=stat:<0-5> or derived:<n> shows that line's tooltip.
			var sheet := room.get_node("HUD/Root/CharacterSheet") as CharacterSheet
			sheet.open()
			var hover: PackedStringArray = String(options.get("--hover", "stat:2")).split(":")
			var index: int = int(hover[1])
			var rows: Array[Rect2] = sheet._stat_rows if hover[0] == "stat" else sheet._derived_rows
			if index < rows.size():  # an index past the end = hover nothing
				sheet.forced_mouse = rows[index].get_center() + Vector2(20, 0)
			for i in 5:
				await get_tree().process_frame
		"map":
			var exploration := get_tree().get_first_node_in_group("exploration") as ExplorationMap
			exploration.reveal_all()
			(room.get_node("HUD/Root/MapOverlay") as Control).visible = true
			for i in 5:
				await get_tree().process_frame

	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(output)
	print("Saved ", output, " ", image.get_size())
	get_tree().quit()


## Find a nearby narrow rock shape, so screenshot QA does not only inspect an easy round room.
func _cave_preview_cell(layout: FloorLayout) -> Vector2i:
	var best: Vector2i = layout.start_cell
	var best_score: int = -1
	for dy in range(-CAVE_PREVIEW_SEARCH_TILES, CAVE_PREVIEW_SEARCH_TILES + 1):
		for dx in range(-CAVE_PREVIEW_SEARCH_TILES, CAVE_PREVIEW_SEARCH_TILES + 1):
			var wall: Vector2i = layout.start_cell + Vector2i(dx, dy)
			if not layout.is_rock(wall.x, wall.y) or layout.slot_at(wall.x, wall.y) != layout.hub_slot:
				continue
			var score: int = 0
			var beside: Vector2i = layout.start_cell
			for offset in CaveArt.OFFSETS.slice(0, 4):
				var cell: Vector2i = wall + offset
				if layout.is_floor(cell.x, cell.y) and layout.slot_at(cell.x, cell.y) == layout.hub_slot:
					score += 1
					beside = cell
			if score > best_score and score > 0:
				best_score = score
				best = beside
	return best


## Leave space beside the projecting torch so the player's tall sprite does not hide the mount.
func _torch_preview_cell(layout: FloorLayout, spawn: FloorLayout.Spawn) -> Vector2i:
	var perpendicular := Vector2i(-spawn.wall_direction.y, spawn.wall_direction.x)
	var base: Vector2i = spawn.cell + spawn.wall_direction * TORCH_PREVIEW_DISTANCE
	for offset in [perpendicular, -perpendicular, Vector2i.ZERO]:
		var cell: Vector2i = base + offset
		if layout.is_floor(cell.x, cell.y) and layout.slot_at(cell.x, cell.y) == spawn.slot:
			return cell
	return spawn.cell + spawn.wall_direction
