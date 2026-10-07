extends Node
## Debug tool: saves one rendered frame, optionally with a staged situation.
## Run (NOT headless, it needs a GPU):
##   <godot.exe> --path . -- --screenshot=<file.png> --mode=<mode> [--seed=<n>]
## Modes on the dungeon floor: idle, map (whole map revealed, big map open), sheet (character page, --hover=stat:2), overview,
## gate / arena / start (zoomed out view of a hub gate, the boss arena entrance, the start cave).
## Modes in the combat test room: fight, dodge, room.

const SETTLE_FRAMES: int = 40
const TEST_ROOM: String = "res://scenes/levels/test_room.tscn"


func run(options: Dictionary) -> void:
	var output: String = options.get("--screenshot", "")
	if output.is_empty():
		output = "user://screenshot.png"
	var mode: String = options.get("--mode", "idle")
	if mode in ["fight", "dodge", "room"]:
		get_tree().change_scene_to_file.call_deferred(TEST_ROOM)

	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	var room: Node = get_tree().current_scene
	var player := room.get_node("World/Player") as Player
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
		"dodge":
			player._try_dodge(Vector2.RIGHT)
			for i in 6:
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
		"gate", "arena", "start", "place":
			# Zoomed out, without darkness: a gate of the closed zone, the boss arena entrance, the start,
			# or a notable place (--place=<kind>, e.g. goblin_camp, mine, oasis, spider_nest, bridge).
			var floor_layout: FloorLayout = (room as FloorLevel).layout
			var target: Vector2i = floor_layout.start_cell
			if mode == "gate":
				target = floor_layout.gates[0].cell
			elif mode == "arena":
				target = floor_layout.boss_entrance
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
		"sheet":
			# Character sheet open; --hover=stat:<0-5> or derived:<n> shows that line's tooltip.
			var sheet := room.get_node("HUD/Root/CharacterSheet") as CharacterSheet
			sheet.open()
			var hover: PackedStringArray = String(options.get("--hover", "stat:2")).split(":")
			var index: int = int(hover[1])
			var rows: Array[Rect2] = sheet._stat_rows if hover[0] == "stat" else sheet._derived_rows
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
