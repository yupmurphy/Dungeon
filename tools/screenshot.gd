extends Node
## Debug tool: saves one rendered frame of the main scene, optionally with a staged fight.
## Run (NOT headless, it needs a GPU):
##   <godot.exe> --path . -- --screenshot=<file.png> --mode=idle|fight|dodge|overview

const SETTLE_FRAMES: int = 40


func run(options: Dictionary) -> void:
	var output: String = options.get("--screenshot", "")
	if output.is_empty():
		output = "user://screenshot.png"
	var mode: String = options.get("--mode", "idle")

	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	var room: Node = get_tree().current_scene
	var player := room.get_node("World/Player") as Player

	match mode:
		"fight":
			# Spider freshly hit by the player, bat in the middle of its red wind-up.
			var spider := room.get_node("World/Spider") as Enemy
			var bat := room.get_node("World/Bat") as Enemy
			spider.global_position = player.global_position + Vector2(22, 0)
			bat.global_position = player.global_position + Vector2(-26, -8)
			for i in 10:
				await get_tree().physics_frame
			bat._attack_dir = Vector2.RIGHT
			bat._set_state(Enemy.State.WINDUP, 0.15)
			player.attack_pivot.rotation = 0.0
			player._swing_left = Player.ATTACK_ACTIVE_TIME
			player.hitbox.damage = 20.0
			player.hitbox.activate(0.12)
			# Wait until the hit actually lands, then a few frames for the effects to appear.
			for i in 60:
				if spider.health.current_health < spider.health.max_health:
					break
				await get_tree().physics_frame
			for i in 4:
				await get_tree().process_frame
		"dodge":
			player._try_dodge(Vector2.RIGHT)
			for i in 6:
				await get_tree().physics_frame
		"overview":
			# Whole room, without darkness, to check the tile layout.
			var camera := player.get_node("Camera2D") as Camera2D
			camera.zoom = Vector2(0.75, 0.75)
			camera.position_smoothing_enabled = false
			(room.get_node("Darkness") as CanvasModulate).visible = false
			for i in 5:
				await get_tree().process_frame

	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(output)
	print("Saved ", output, " ", image.get_size())
	get_tree().quit()
