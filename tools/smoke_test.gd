extends Node
## Automated combat checks on the real test room.
## Run:  <godot.exe> --headless --path . -- --smoke-test     (exit code 0 = all passed)

var _failures: int = 0


func run(_options: Dictionary) -> void:
	# Deferred: tools start while the tree is still adding the main scene.
	get_tree().change_scene_to_file.call_deferred("res://scenes/levels/test_room.tscn")
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
	_check(player.stamina.current_stamina == player.stats.get_max_stamina() and player.stamina.max_stamina == 70.0,
		"player starts with full stamina (70 = 50 + 4 x Vitality 5)")
	var frames: Array = [slime.sprite.sprite_frames, bat.sprite.sprite_frames, spider.sprite.sprite_frames]
	_check(frames[0] != frames[1] and frames[1] != frames[2] and frames[0] != frames[2],
		"each enemy uses different sprites")
	for anim in [&"idle", &"run", &"attack"]:
		_check(player.sprite.sprite_frames.has_animation(anim), "player has animation '%s'" % anim)
	var camera := player.get_node("Camera2D") as Camera2D
	_check(camera.limit_right == 48 * GameScale.TILE_SIZE and camera.limit_bottom == 30 * GameScale.TILE_SIZE, "camera limited to the room (48x30 tiles)")
	var dungeon := room.get_node("Dungeon") as TileMapLayer
	_check(dungeon.get_cell_tile_data(Vector2i(0, 0)).get_collision_polygons_count(0) > 0, "wall tiles have collision")
	_check(dungeon.get_cell_tile_data(Vector2i(10, 10)).get_collision_polygons_count(0) == 0, "floor tiles have no collision")

	# Only the enemy under test may act.
	for enemy in [slime, bat, spider]:
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = Vector2(300, 250)

	print("--- movement (simulated physical keys)")
	for key in [[KEY_D, Vector2.RIGHT], [KEY_A, Vector2.LEFT], [KEY_S, Vector2.DOWN], [KEY_W, Vector2.UP]]:
		player.global_position = Vector2(300, 250)
		await get_tree().physics_frame
		var start: Vector2 = player.global_position
		_send_key(key[0], true)
		for i in 15:
			await get_tree().physics_frame
		_send_key(key[0], false)
		var moved: Vector2 = player.global_position - start
		_check(moved.dot(key[1]) > 10.0, "key %s moves the player %s (moved %s)" % [OS.get_keycode_string(key[0]), key[1], moved.round()])
	await get_tree().physics_frame
	player.global_position = Vector2(300, 250)

	print("--- dodge")
	player._try_dodge(Vector2.RIGHT)
	_check(player.hurtbox.is_invulnerable(), "dodge gives invulnerability")
	_check(player.stamina.current_stamina == player.stamina.max_stamina - 25.0, "dodge costs 25 stamina")
	await get_tree().create_timer(0.1).timeout
	_check(effects.get_child_count() > 0, "dodge leaves a ghost trail")
	await get_tree().create_timer(0.3).timeout
	_check(not player.hurtbox.is_invulnerable(), "invulnerability ends after the dodge")

	print("--- player hits spider")
	spider.process_mode = Node.PROCESS_MODE_INHERIT
	await _hit_with_player(player, spider)
	# 20 weapon damage x 1.2 (bonus: 4 stats at 5) x 100 / (100 + spider defense 1.5)
	var expected: float = Combat.damage_taken(Combat.damage_dealt(player.stats, 20.0, false), spider.data.stats)
	_check(is_equal_approx(expected, 24.0 * 100.0 / 101.5), "formula: 20 x 1.2 x 100 / 101.5 = %.2f" % expected)
	_check(is_equal_approx(spider.health.current_health, 60.0 - expected),
		"spider took %.1f damage (60 -> %.1f)" % [expected, spider.health.current_health])
	_check(_has_child_of(effects, DamageNumber), "damage number spawned")
	_check(_has_child_of(effects, ParticleBurst), "hit particles spawned")

	print("--- miss and critical")
	await _clear(effects)
	var before: float = spider.health.current_health
	await _hit_with_player(player, spider, [0.0, 0.99])
	_check(spider.health.current_health == before, "a missed hit does no damage")
	var popup: DamageNumber = _find_popup(effects)
	_check(popup != null and popup.text == "Ratat", "a miss shows 'Ratat' (%s)" % (popup.text if popup else "nothing"))
	await _clear(effects)
	await _hit_with_player(player, spider, [0.99, 0.0])
	var critical: float = Combat.damage_taken(Combat.damage_dealt(player.stats, 20.0, true), spider.data.stats)
	_check(is_equal_approx(before - spider.health.current_health, critical),
		"a critical hit does 150%% damage (%.1f)" % (before - spider.health.current_health))
	popup = _find_popup(effects)
	_check(popup != null and popup.modulate.r == GameFeel.CRITICAL_COLOR.r and popup.modulate.g == GameFeel.CRITICAL_COLOR.g
		and popup.get_theme_font_size("font_size") == DamageNumber.CRITICAL_FONT_SIZE, "a critical number is bigger and orange")

	print("--- hit-stop")
	GameFeel.hit_stop(0.05)
	_check(Engine.time_scale < 1.0, "hit-stop slows time")
	# Timers count from the start of the frame, so poll the real clock instead of trusting one short timer.
	var deadline: int = Time.get_ticks_msec() + 500
	while Engine.time_scale < 1.0 and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
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
	Combat.forced_rolls.assign([0.99, 0.99, 0.99, 0.99, 0.99, 0.99])  # the bat's hits don't miss
	var saw_windup: bool = false
	for i in 90:
		await get_tree().physics_frame
		if is_instance_valid(bat) and bat.state == Enemy.State.WINDUP:
			saw_windup = true
	_check(saw_windup, "bat telegraphs its attack (wind-up)")
	_check(player.health.current_health < 100.0, "bat damaged the player (HP %s)" % player.health.current_health)
	Combat.forced_rolls.clear()

	print("--- result: %s" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)


## `rolls`: miss roll then critical roll (see Combat); the default is a normal hit.
func _hit_with_player(player: Player, enemy: Enemy, rolls: Array[float] = [0.99, 0.99]) -> void:
	# The headless mouse sits at (0, 0), so aim manually and freeze the auto-aim during the swing.
	player.global_position = Vector2(300, 250)
	enemy.global_position = Vector2(320, 250)
	await get_tree().physics_frame
	player._swing_left = 1.0
	player.attack_pivot.rotation = 0.0
	player.hitbox.damage = player.base_attack_damage
	player.hitbox.knockback_force = player.attack_knockback
	Combat.forced_rolls.assign(rolls)
	player.hitbox.activate(Player.ATTACK_ACTIVE_TIME)
	await get_tree().create_timer(0.3, true, false, true).timeout


func _send_key(physical_key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = physical_key
	event.pressed = pressed
	Input.parse_input_event(event)


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


func _find_popup(parent: Node) -> DamageNumber:
	for child in parent.get_children():
		if child is DamageNumber and not child.is_queued_for_deletion():
			return child
	return null


func _clear(parent: Node) -> void:
	for child in parent.get_children():
		child.queue_free()
	await get_tree().process_frame
