extends Node
## Debug tool: saves one rendered frame, optionally with a staged situation.
## Run (NOT headless, it needs a GPU):
##   <godot.exe> --path . -- --screenshot=<file.png> --mode=<mode> [--seed=<n>]
## Modes on the dungeon floor: idle, map (whole map revealed, big map open), sheet (character page, --hover=stat:2), overview,
## gate / arena / start (zoomed out view of a hub gate, the boss arena entrance, the start cave), cave (walls up
## close near the start, --zoom=1 --dark for the real look).
## Modes in the combat test room: fight, room, goblins (--frames=<n> to wait). Town: town (--at=<x>,<y> in tiles, --zoom, --night, --map).
## Any mode: --collisions shows the collision shapes.

const SETTLE_FRAMES: int = 40
const TEST_ROOM: String = "res://scenes/levels/test_room.tscn"
const TOWN: String = "res://scenes/town/town.tscn"
## Tiles searched around the start for the "cave" mode.
const CAVE_PREVIEW_SEARCH: int = 55


func run(options: Dictionary) -> void:
	var output: String = options.get("--screenshot", "")
	if output.is_empty():
		output = "user://screenshot.png"
	var mode: String = options.get("--mode", "idle")
	# --collisions draws every collision shape (to find invisible obstacles).
	if options.has("--collisions"):
		get_tree().debug_collisions_hint = true
	if mode in ["fight", "room", "goblins"]:
		get_tree().change_scene_to_file.call_deferred(TEST_ROOM)
	elif mode == "town":
		get_tree().change_scene_to_file.call_deferred(TOWN)

	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	var room: Node = get_tree().current_scene
	var player := room.get_node("World/Player") as Player
	# --equip=<id>,<id> wears these pieces, --body=male|female (see resources/items/ and resources/equipment/).
	if options.has("--body"):
		player.equipment.set_body_type(options["--body"])
	for id in String(options.get("--equip", "")).split(",", false):
		player.equipment.equip(Equipment.find(StringName(id)))
	if options.has("--perception"):
		player.stats.perception = int(options["--perception"])

	match mode:
		"fight":
			# Spider freshly hit by the player, bat in the middle of its red wind-up.
			var spider := room.get_node("World/Spider") as Enemy
			var bat := room.get_node("World/Bat") as Enemy
			spider.global_position = player.global_position + GameScale.world_vector(Vector2(22, 0))
			bat.global_position = player.global_position + GameScale.world_vector(Vector2(-26, -8))
			for i in 10:
				await get_tree().physics_frame
			bat._attack_dir = Vector2.RIGHT
			bat._set_state(Enemy.State.WINDUP, 0.15)
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
		"goblins":
			# The goblins side by side: knife goblin, grown goblin, and an archer aiming (line), then shooting.
			for name in ["Spider", "Bat"]:
				room.get_node("World/" + name).queue_free()
			var spots: Array[Vector2] = [Vector2(-40, -20), Vector2(-10, -30), Vector2(50, -25), Vector2(60, 10)]
			var kinds: Array[String] = ["goblin", "goblin_grown", "goblin_archer", "goblin_archer"]
			for i in kinds.size():
				var monster := (load("res://scenes/enemies/enemy.tscn") as PackedScene).instantiate() as Enemy
				monster.data = load("res://resources/monsters/%s.tres" % kinds[i])
				room.get_node("World").add_child(monster)
				monster.global_position = player.global_position + GameScale.world_vector(spots[i])
			player.hurtbox.god_mode = true
			for i in int(options.get("--frames", "75")):
				await get_tree().physics_frame
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
		"gate", "arena", "start", "place", "cave":
			# Zoomed out, without darkness: a gate of the closed zone, the boss arena entrance, the start,
			# or a notable place (--place=<kind>, e.g. goblin_camp, mine, oasis, spider_nest, bridge).
			var floor_layout: FloorLayout = (room as FloorLevel).layout
			var target: Vector2i = floor_layout.start_cell
			if mode == "gate":
				target = floor_layout.gates[0].cell
			elif mode == "arena":
				target = floor_layout.boss_entrance
			elif mode == "cave":
				target = _cave_preview_cell(floor_layout)
			elif mode == "place":
				var kind := StringName(options.get("--place", "goblin_camp"))
				for feature in floor_layout.features:
					if feature.kind == kind:
						target = feature.cell
						break
			player.global_position = (Vector2(target) + Vector2(0.5, 0.5)) * GameScale.TILE_SIZE
			var camera := player.get_node("Camera2D") as Camera2D
			camera.zoom = Vector2.ONE * float(options.get("--zoom", "0.5"))
			camera.position_smoothing_enabled = false
			(room.get_node("Darkness") as CanvasModulate).visible = options.has("--dark")
			(room.get_node("Exploration/Fog") as CanvasItem).visible = false
			for i in 60:
				await get_tree().physics_frame
		"town":
			# --at=<x>,<y> (tiles) moves the player there, --zoom=<z>, --night turns the lights on.
			var at: PackedStringArray = String(options.get("--at", "41,30")).split(",")
			player.global_position = Vector2(float(at[0]), float(at[1])) * GameScale.TILE_SIZE
			var town_camera := player.get_node("Camera2D") as Camera2D
			town_camera.zoom = Vector2.ONE * float(options.get("--zoom", "1"))
			town_camera.position_smoothing_enabled = false
			if options.has("--no-limits"):
				town_camera.limit_left = -100000
				town_camera.limit_top = -100000
				town_camera.limit_right = 100000
				town_camera.limit_bottom = 100000
			if options.has("--night"):
				(room.get_node("Lighting") as TownLighting).night = true
			if options.has("--map"):
				(room.get_node("HUD/Root/MapOverlay") as Control).visible = true
			for i in 150:
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


## A floor cell next to a narrow bit of rock near the start (more wall shapes in view than in a round room).
func _cave_preview_cell(layout: FloorLayout) -> Vector2i:
	var best: Vector2i = layout.start_cell
	var best_score: int = 0
	for dy in range(-CAVE_PREVIEW_SEARCH, CAVE_PREVIEW_SEARCH + 1):
		for dx in range(-CAVE_PREVIEW_SEARCH, CAVE_PREVIEW_SEARCH + 1):
			var wall: Vector2i = layout.start_cell + Vector2i(dx, dy)
			if not layout.is_rock(wall.x, wall.y) or layout.slot_at(wall.x, wall.y) != layout.hub_slot:
				continue
			var score: int = 0
			var beside: Vector2i = wall
			for offset in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
				var cell: Vector2i = wall + offset
				if layout.is_floor(cell.x, cell.y):
					score += 1
					beside = cell
			if score > best_score:
				best_score = score
				best = beside
	return best
