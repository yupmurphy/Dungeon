extends Node
## Automated combat checks on the real test room.
## Run:  <godot.exe> --headless --path . -- --smoke-test     (exit code 0 = all passed)

var _failures: int = 0


func run(_options: Dictionary) -> void:
	for i in 10:
		await get_tree().process_frame
	var room: Node = get_tree().current_scene
	var player := room.get_node("World/Player") as Player
	var slime := room.get_node("World/Slime") as Enemy
	var bat := room.get_node("World/Bat") as Enemy
	var spider := room.get_node("World/Spider") as Enemy
	var effects: CanvasLayer = GameFeel.get_child(0)

	print("--- setup")
	for action in ["move_up", "move_down", "move_left", "move_right", "attack", "dodge", "restart"]:
		_check(InputMap.has_action(action) and InputMap.action_get_events(action).size() > 0,
			"input action '%s' mapped" % action)
	_check(player.health.current_health == 100.0, "player starts with 100 HP")
	_check(player.stamina.current_stamina == 100.0, "player starts with full stamina")
	var frames: Array = [slime.sprite.sprite_frames, bat.sprite.sprite_frames, spider.sprite.sprite_frames]
	_check(frames[0] != frames[1] and frames[1] != frames[2] and frames[0] != frames[2],
		"each enemy uses different sprites")
	for anim in [&"idle", &"run", &"attack"]:
		_check(player.sprite.sprite_frames.has_animation(anim), "player has animation '%s'" % anim)
	var camera := player.get_node("Camera2D") as Camera2D
	_check(camera.limit_right == 768 and camera.limit_bottom == 480, "camera limited to the room (768x480)")
	var dungeon := room.get_node("Dungeon") as TileMapLayer
	_check(dungeon.get_cell_tile_data(Vector2i(0, 0)).get_collision_polygons_count(0) > 0, "wall tiles have collision")
	_check(dungeon.get_cell_tile_data(Vector2i(10, 10)).get_collision_polygons_count(0) == 0, "floor tiles have no collision")

	# Only the enemy under test may act.
	for enemy in [slime, bat, spider]:
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = Vector2(300, 250)

	print("--- dodge")
	player._try_dodge(Vector2.RIGHT)
	_check(player.hurtbox.is_invulnerable(), "dodge gives invulnerability")
	_check(player.stamina.current_stamina == 75.0, "dodge costs 25 stamina")
	await get_tree().create_timer(0.1).timeout
	_check(effects.get_child_count() > 0, "dodge leaves a ghost trail")
	await get_tree().create_timer(0.3).timeout
	_check(not player.hurtbox.is_invulnerable(), "invulnerability ends after the dodge")

	print("--- player hits spider")
	spider.process_mode = Node.PROCESS_MODE_INHERIT
	await _hit_with_player(player, spider)
	_check(is_equal_approx(spider.health.current_health, 40.0), "spider took 20 damage (60 -> %s)" % spider.health.current_health)
	_check(_has_child_of(effects, DamageNumber), "damage number spawned")
	_check(_has_child_of(effects, ParticleBurst), "hit particles spawned")

	print("--- hit-stop")
	GameFeel.hit_stop(0.05)
	_check(Engine.time_scale < 1.0, "hit-stop slows time")
	await get_tree().create_timer(0.1, true, false, true).timeout
	_check(Engine.time_scale == 1.0, "hit-stop ends by itself")

	print("--- spider dies")
	await _hit_with_player(player, spider)
	await _hit_with_player(player, spider)
	await get_tree().create_timer(0.6).timeout
	_check(not is_instance_valid(spider), "spider removed after death")

	print("--- bat attacks player")
	bat.process_mode = Node.PROCESS_MODE_INHERIT
	player.global_position = Vector2(300, 250)
	bat.global_position = Vector2(300, 228)
	var saw_windup: bool = false
	for i in 90:
		await get_tree().physics_frame
		if is_instance_valid(bat) and bat.state == Enemy.State.WINDUP:
			saw_windup = true
	_check(saw_windup, "bat telegraphs its attack (wind-up)")
	_check(player.health.current_health < 100.0, "bat damaged the player (HP %s)" % player.health.current_health)

	print("--- result: %s" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)


func _hit_with_player(player: Player, enemy: Enemy) -> void:
	# The headless mouse sits at (0, 0), so aim manually and freeze the auto-aim during the swing.
	player.global_position = Vector2(300, 250)
	enemy.global_position = Vector2(320, 250)
	await get_tree().physics_frame
	player._swing_left = 1.0
	player.attack_pivot.rotation = 0.0
	player.hitbox.damage = player.base_attack_damage * player.stats.get_damage_multiplier()
	player.hitbox.knockback_force = player.attack_knockback
	player.hitbox.activate(Player.ATTACK_ACTIVE_TIME)
	await get_tree().create_timer(0.3, true, false, true).timeout


func _has_child_of(parent: Node, type: Variant) -> bool:
	for child in parent.get_children():
		if is_instance_of(child, type):
			return true
	return false


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  ", label)
	else:
		_failures += 1
		print("  FAIL  ", label)
