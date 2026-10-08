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
	for action in ["move_up", "move_down", "move_left", "move_right", "attack", "sprint", "restart"]:
		_check(InputMap.has_action(action) and InputMap.action_get_events(action).size() > 0,
			"input action '%s' mapped" % action)
	_check(player.health.current_health == 100.0, "player starts with 100 HP")
	_check(player.exhaustion.current == 0.0, "player starts with 0 exhaustion")
	var frames: Array = [slime.sprite.sprite_frames, bat.sprite.sprite_frames, spider.sprite.sprite_frames]
	_check(frames[0] != frames[1] and frames[1] != frames[2] and frames[0] != frames[2],
		"each enemy uses different sprites")
	var layers: Array[AnimatedSprite2D] = player.character.layers()
	_check(layers.size() >= 7, "player is drawn from %d LPC layers (body, head, hair, clothes, weapon)" % layers.size())
	var walking: Array[AnimatedSprite2D] = layers.filter(func(l: AnimatedSprite2D) -> bool:
		return l.sprite_frames.has_animation(&"walk_down"))
	var frame_size: Vector2 = walking[0].sprite_frames.get_frame_texture(&"walk_down", 0).get_size()
	_check(frame_size == Vector2(64, 64), "LPC frames are 64 x 64 (%s)" % frame_size)
	for action in ["idle", "walk", "slash", "thrust", "flinch", "death"]:
		_check(player.character.has_action(action), "player has the '%s' animation" % action)
	_check(GameScale.TILE_SIZE == 32 and (room.get_node("Dungeon") as TileMapLayer).tile_set.tile_size == Vector2i(32, 32),
		"tiles are 32 x 32")
	var camera := player.get_node("Camera2D") as Camera2D
	_check(camera.limit_right == 48 * GameScale.TILE_SIZE and camera.limit_bottom == 30 * GameScale.TILE_SIZE, "camera limited to the room (48x30 tiles)")
	var dungeon := room.get_node("Dungeon") as TileMapLayer
	_check(dungeon.get_cell_tile_data(Vector2i(0, 0)).get_collision_polygons_count(0) > 0, "wall tiles have collision")
	_check(dungeon.get_cell_tile_data(Vector2i(10, 10)).get_collision_polygons_count(0) == 0, "floor tiles have no collision")

	print("--- character sheet (C)")
	var sheet := room.get_node("HUD/Root/CharacterSheet") as CharacterSheet
	_check(InputMap.has_action("character_sheet"), "input action 'character_sheet' mapped")
	_send_key(KEY_C, true)
	await get_tree().process_frame
	_send_key(KEY_C, false)
	_check(sheet.visible and get_tree().paused, "C opens the character sheet and pauses the game")
	var health_row: Label = sheet._derived_values[0]
	_check(health_row.text == "100", "sheet shows health 100 (%s)" % health_row.text)
	sheet._stat_buttons[Vector2i(Stats.Stat.STRENGTH, 1)].pressed.emit()
	_check(player.stats.strength == 6 and player.health.max_health == 110.0 and player.health.current_health == 110.0,
		"Strength + -> 6, health 110 at once (%s / %s)" % [player.health.current_health, player.health.max_health])
	_check(health_row.text == "110", "sheet updates right away (%s)" % health_row.text)
	sheet._stat_buttons[Vector2i(Stats.Stat.STRENGTH, 10)].pressed.emit()
	_check(player.stats.strength == 16 and player.health.max_health == 210.0, "Strength +10 -> 16, health 210")
	sheet._stat_buttons[Vector2i(Stats.Stat.STRENGTH, 10)].pressed.emit()
	sheet._stat_buttons[Vector2i(Stats.Stat.STRENGTH, -1)].pressed.emit()
	_check(player.stats.strength == 25, "Strength - -> 25")
	player.stats.strength = 5
	_check(player.health.max_health == 100.0 and player.health.current_health == 100.0, "back to Strength 5: health 100")
	sheet._stat_buttons[Vector2i(Stats.Stat.AGILITY, 10)].pressed.emit()
	_check(sheet._derived_values[7].text == "15%", "Agility 15 -> enemies miss 15%% (%s)" % sheet._derived_values[7].text)
	var magic_plus: Button = sheet._stat_buttons[Vector2i(Stats.Stat.MAGIC, 1)]
	_check(sheet._stat_values[Stats.Stat.MAGIC].text == "Locked" and not magic_plus.visible and sheet._unlock_button.visible,
		"Magic shows Locked, no + buttons, an Unlock button")
	sheet.player_add_stat(Stats.Stat.MAGIC, 10)
	_check(player.stats.magic == 0, "locked Magic cannot be raised")
	sheet._unlock_button.pressed.emit()
	_check(player.stats.magic_unlocked and magic_plus.visible and not sheet._unlock_button.visible
		and sheet._stat_values[Stats.Stat.MAGIC].text == "0", "Unlock: Magic 0 with + buttons")
	magic_plus.pressed.emit()
	_check(player.stats.magic == 1 and sheet._derived_values[1].text == "25", "Magic +1 -> mana 25 (%s)"
		% sheet._derived_values[1].text)
	player.stats.magic = 0
	player.stats.magic_unlocked = false
	player.stats.agility = 5
	var torch := player.get_node("Torch") as PointLight2D
	var torch_before: float = torch.texture_scale
	sheet._stat_buttons[Vector2i(Stats.Stat.PERCEPTION, 10)].pressed.emit()
	_check(torch.texture_scale > torch_before * 1.5, "Perception +10 -> the light around the player grows (x%.2f)"
		% (torch.texture_scale / torch_before))
	player.stats.perception = 5
	_check(is_equal_approx(torch.texture_scale, torch_before), "back to Perception 5 -> light back to normal")
	sheet._xp_button.pressed.emit()
	sheet._xp_button.pressed.emit()
	_check(player.progression.level == 2 and player.progression.xp == 0, "2 x +50 XP -> level 2")
	_check(sheet._level_label.text == "Level 2", "sheet shows %s" % sheet._level_label.text)
	sheet.forced_mouse = sheet._stat_rows[Stats.Stat.STRENGTH].get_center()
	await get_tree().process_frame
	_check(sheet._tooltip.visible and sheet._tooltip_label.text.contains("Strength 5:")
		and sheet._tooltip_label.text.contains("+50 health") and sheet._tooltip_label.text.contains("+5% damage"),
		"hovering Strength explains it: +50 health, +5% damage")
	sheet.forced_mouse = sheet._derived_rows[2].get_center()
	await get_tree().process_frame
	_check(sheet._tooltip_label.text.contains("From Strength"), "hovering Defense: comes from Strength")
	sheet.forced_mouse = Vector2(-1, -1)
	_send_key(KEY_C, true)
	await get_tree().process_frame
	_send_key(KEY_C, false)
	_check(not sheet.visible and not get_tree().paused, "C again closes it and the game runs")

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
		var walk_direction: String = LpcCatalog.DIRECTION_NAMES[LpcCharacter.direction_of(key[1])]
		_check(player.character.action == "walk" and LpcCatalog.DIRECTION_NAMES[player.character.direction] == walk_direction,
			"walking %s plays walk_%s (%s)" % [OS.get_keycode_string(key[0]), walk_direction, player.character.action])
		_send_key(key[0], false)
		var moved: Vector2 = player.global_position - start
		_check(moved.dot(key[1]) > 10.0, "key %s moves the player %s (moved %s)" % [OS.get_keycode_string(key[0]), key[1], moved.round()])
	await get_tree().physics_frame
	player.global_position = Vector2(300, 250)
	for i in 3:
		await get_tree().physics_frame
	_check(player.character.action == "idle", "standing still plays idle (%s)" % player.character.action)
	# LPC art has 4 directions: diagonals use the side view, up/down only when moving almost vertically.
	for case in [[Vector2(1, -1), "right"], [Vector2(-1, -1), "left"], [Vector2(1, 1), "right"], [Vector2(-1, 1), "left"],
			[Vector2(0.3, -1), "up"], [Vector2(-0.3, 1), "down"]]:
		var facing: String = LpcCatalog.DIRECTION_NAMES[LpcCharacter.direction_of(case[0])]
		_check(facing == case[1], "moving %s faces %s (%s)" % [case[0], case[1], facing])

	print("--- perception thresholds: monster health bars and names")
	var slime_info: EnemyInfo = null
	for child in effects.get_children():
		if child is EnemyInfo and child.enemy == slime:
			slime_info = child
	_check(slime_info != null, "every monster gets a health bar / name overlay")
	await get_tree().process_frame
	# Next to the slime, so it is inside the sight radius.
	var before_info: Vector2 = player.global_position
	player.global_position = slime.global_position + GameScale.world_vector(Vector2(0, 30))
	slime._update_visibility()
	_check(not slime_info.visible, "Perception 5: no health bar, no name")
	player.stats.perception = 10
	await get_tree().process_frame
	_check(slime_info.visible and not slime_info._name_label.visible, "Perception 10: health bar, no name")
	player.stats.perception = 20
	await get_tree().process_frame
	_check(slime_info._name_label.visible and slime_info._name_label.text == "Slime", "Perception 20: name shown")
	_check(slime_info.power_color() == EnemyInfo.EQUAL_COLOR, "slime vs new player (Perception 20): about equal (yellow)")
	var bat_info: EnemyInfo = null
	for child in effects.get_children():
		if child is EnemyInfo and child.enemy == bat:
			bat_info = child
	_check(bat_info.power_color() == EnemyInfo.WEAK_COLOR, "bat: much weaker (white)")
	player.stats.strength = 0
	_check(slime_info.power_color() == EnemyInfo.STRONG_COLOR, "slime vs Strength 0 player: stronger (red)")
	player.stats.strength = 5
	player.stats.perception = 5
	player.global_position = before_info

	print("--- exhaustion")
	var tired: ExhaustionComponent = player.exhaustion
	var start_position: Vector2 = player.global_position
	Input.action_press("move_right")
	Input.action_press("sprint")
	for i in 10:
		await get_tree().physics_frame
	var sprint_speed: float = player.velocity.length()
	Input.action_release("sprint")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var walk_speed: float = player.velocity.length()
	Input.action_release("move_right")
	await get_tree().physics_frame
	player.global_position = start_position
	_check(tired.current > 0.5 and tired.current < 2.0, "sprinting raises exhaustion (%.2f)" % tired.current)
	_check(sprint_speed > walk_speed * 1.5, "sprint is faster than walking (%d vs %d)" % [sprint_speed, walk_speed])
	tired.current = 0.0
	tired.add(ExhaustionComponent.ATTACK_COST)
	_check(is_equal_approx(tired.current, 2.85), "an attack adds 3, x 0.95 from Strength 5 (%.2f)" % tired.current)
	tired.add(200.0)
	_check(tired.current == 100.0 and tired.exhausted and not tired.can_sprint(), "at 100: exhausted, no sprint")
	_check(tired.damage_factor() == 0.6 and tired.speed_factor() == 0.8, "exhausted: -40% damage, 20% slower")
	tired._process(1.4)
	tired._process(0.1)
	_check(tired.current == 100.0, "no recovery during the 1.5 s pause")
	tired._process(0.2)
	tired._process(0.2)
	_check(is_equal_approx(tired.current, 97.0), "then it drops 15 per second (%.2f)" % tired.current)
	tired.current = 71.0
	tired._process(0.1)
	_check(not tired.exhausted and tired.can_sprint() and tired.damage_factor() == 1.0 and tired.speed_factor() == 1.0,
		"below 70: no longer exhausted or slowed")
	tired.current = 0.0
	tired.add(0.0)
	tired._delay_left = 0.0

	print("--- player hits spider")
	spider.process_mode = Node.PROCESS_MODE_INHERIT
	await _hit_with_player(player, spider)
	# 20 weapon damage x 1.15 (bonus: Str, Agi, Per at 5) x 100 / (100 + spider defense 0.5)
	var expected: float = Combat.damage_taken(Combat.damage_dealt(player.stats, 20.0, false), spider.data.stats)
	_check(is_equal_approx(expected, 23.0 * 100.0 / 100.5), "formula: 20 x 1.15 x 100 / 100.5 = %.2f" % expected)
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
	_check(popup != null and popup.text == "Miss", "a miss shows 'Miss' (%s)" % (popup.text if popup else "nothing"))
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
	# Hit until it dies (an AI attack in between can change the rolls), then wait for the fade-out.
	var hits: int = 0
	while is_instance_valid(spider) and not spider.health.is_dead and hits < 4:
		await _hit_with_player(player, spider)
		hits += 1
	var removal_deadline: int = Time.get_ticks_msec() + 2000
	while is_instance_valid(spider) and Time.get_ticks_msec() < removal_deadline:
		await get_tree().process_frame
	_check(not is_instance_valid(spider), "spider removed after death (%d more hits)" % hits)

	print("--- bat attacks player")
	bat.process_mode = Node.PROCESS_MODE_INHERIT
	player.global_position = Vector2(300, 250)
	bat.global_position = Vector2(300, 250) + GameScale.world_vector(Vector2(0, -22))
	Combat.forced_rolls.assign([0.99, 0.99, 0.99, 0.99, 0.99, 0.99])  # the bat's hits don't miss
	var saw_windup: bool = false
	for i in 90:
		await get_tree().physics_frame
		if is_instance_valid(bat) and bat.state == Enemy.State.WINDUP:
			saw_windup = true
	_check(saw_windup, "bat telegraphs its attack (wind-up)")
	_check(player.health.current_health < 100.0, "bat damaged the player (HP %s)" % player.health.current_health)
	Combat.forced_rolls.clear()

	print("--- equipment (paper doll)")
	var ids: Dictionary = {}
	var unique: bool = true
	for slot in EquipmentData.Slot.values():
		for piece in Equipment.all_pieces(slot):
			unique = unique and not ids.has(piece.id) and not String(piece.id).is_empty() \
				and LpcCatalog.has_item(piece.lpc_item) and Equipment.find(piece.id) == piece
			ids[piece.id] = true
	_check(unique and ids.size() >= 20, "%d pieces, each with a unique id and its LPC art" % ids.size())
	_check(player.equipment.get_piece(EquipmentData.Slot.WEAPON).id == &"weapon_sword"
		and player.character.attack_action() == "slash", "starts with a sword: attacks are slashes")
	sheet.open()
	var torso_list: OptionButton = sheet._equip_lists[EquipmentData.Slot.TORSO]
	var leather: int = sheet._equip_choices[EquipmentData.Slot.TORSO].find(Equipment.find(&"torso_leather"))
	torso_list.select(leather)
	torso_list.item_selected.emit(leather)
	_check(player.equipment.get_piece(EquipmentData.Slot.TORSO).id == &"torso_leather"
		and "torso_leather" in player.character.items, "picking Leather armor in the list puts it on at once")
	var weapon_list: OptionButton = sheet._equip_lists[EquipmentData.Slot.WEAPON]
	var spear: int = sheet._equip_choices[EquipmentData.Slot.WEAPON].find(Equipment.find(&"weapon_spear"))
	weapon_list.item_selected.emit(spear)
	_check(player.character.attack_action() == "thrust", "with a spear, attacks are thrusts")
	weapon_list.item_selected.emit(0)
	_check(player.equipment.get_piece(EquipmentData.Slot.WEAPON) == null
		and not "weapon_spear" in player.character.items, "'None' takes the weapon off")
	sheet._equip_lists["body"].item_selected.emit(1)
	_check(player.equipment.body_type == "female" and player.character.body_type == "female"
		and sheet._preview.body_type == "female", "body type Female changes the player and the preview")
	sheet._equip_lists["body"].item_selected.emit(0)
	player.equipment.equip(Equipment.find(&"weapon_sword"))
	player.equipment.equip(Equipment.find(&"torso_longsleeve"))
	sheet.close()

	print("--- young goblin")
	var goblin_data: MonsterData = load("res://resources/monsters/goblin.tres")
	var goblin := (load("res://scenes/enemies/enemy.tscn") as PackedScene).instantiate() as Enemy
	# No random dash attacks here: this part checks the normal swing.
	var plain_goblin: MonsterData = goblin_data.duplicate()
	plain_goblin.dash_attack_chance = 0.0
	plain_goblin.dash_attack_chance_hurt = 0.0
	goblin.data = plain_goblin
	goblin.process_mode = Node.PROCESS_MODE_INHERIT
	room.get_node("World").add_child(goblin)
	player.global_position = Vector2(300, 400)
	goblin.global_position = Vector2(300, 400) + GameScale.world_vector(Vector2(-60, 0))
	await get_tree().physics_frame
	_check(goblin.health.max_health == 35.0, "goblin has 35 health (%s)" % goblin.health.max_health)
	_check(goblin.animator.directional and goblin.sprite.sprite_frames.has_animation(&"attack_up"),
		"goblin has its own frames for 4 facings")
	var goblin_frame: Vector2 = goblin.sprite.sprite_frames.get_frame_texture(&"idle_down", 0).get_size()
	_check(goblin_frame == Vector2(64, 64) and is_equal_approx(absf(goblin.sprite.scale.x), 1.0),
		"goblin is drawn at its real LPC size, not scaled (%s, x%s)" % [goblin_frame, goblin.sprite.scale.x])
	var saw_right: bool = false
	var saw_swing: bool = false
	for i in 120:
		await get_tree().physics_frame
		if not is_instance_valid(goblin):
			break
		var animation: String = goblin.sprite.animation
		saw_right = saw_right or animation.ends_with("_right")
		saw_swing = saw_swing or (goblin.state == Enemy.State.WINDUP and animation.begins_with("attack_"))
	_check(saw_right, "a goblin left of the player faces right")
	_check(saw_swing, "the goblin's swing starts during its wind-up (visible warning)")
	goblin.health.take_damage(1000.0)
	await get_tree().physics_frame
	_check(is_instance_valid(goblin) and goblin.sprite.animation == &"death", "a dying goblin plays its fall")
	# The [LPC] goblin sheet goes down, right, up, left: row 1 is the right-facing one.
	var grown_frames: SpriteFrames = MonsterSheet.frames(load("res://resources/monsters/goblin_grown.tres"))
	var grown_right: AtlasTexture = grown_frames.get_frame_texture(&"attack_right", 0)
	_check(grown_right.region.position.y == 64.0, "the grown goblin attacks to the right with its right-facing row")

	print("--- goblin dash attack")
	_check(goblin_data.dash_attack_chance > 0.24 and goblin_data.dash_attack_chance < 0.34,
		"about 1 goblin attack in 3-4 is a dash attack (%.2f)" % goblin_data.dash_attack_chance)
	_check(goblin_data.dash_attack_chance_hurt > 0.32 and goblin_data.dash_attack_chance_hurt < 0.51,
		"hurt goblins: 1 in 2-3 (%.2f)" % goblin_data.dash_attack_chance_hurt)
	var dasher_data: MonsterData = goblin_data.duplicate()
	dasher_data.dash_attack_chance = 1.0
	dasher_data.dash_attack_chance_hurt = 1.0
	# The room's own monsters (a wandering bat) would hit the player too: paused for the dash tests.
	var bystanders: Array[Node] = get_tree().get_nodes_in_group("enemy")
	for bystander in bystanders:
		bystander.process_mode = Node.PROCESS_MODE_DISABLED
	for dodge in [false, true]:
		var dasher := (load("res://scenes/enemies/enemy.tscn") as PackedScene).instantiate() as Enemy
		dasher.data = dasher_data
		dasher.process_mode = Node.PROCESS_MODE_INHERIT
		room.get_node("World").add_child(dasher)
		var stand: Vector2 = Vector2(300, 400)
		player.global_position = stand
		player._knockback = Vector2.ZERO
		dasher.global_position = stand + GameScale.world_vector(Vector2(-50, 0))
		player.health.heal(1000.0)
		var health_before: float = player.health.current_health
		Combat.forced_rolls.assign([0.99, 0.99])
		var leaned: bool = false
		var lean_moved: bool = false
		var lean_air: bool = false
		var dashed: bool = false
		var dash_air: bool = false
		var hit_while_dashing: bool = false
		var struck: bool = false
		var landed_at: Vector2 = Vector2.ZERO
		for i in 90:
			await get_tree().physics_frame
			if dasher.dash.is_winding_up():
				leaned = leaned or dasher.visual.rotation != 0.0
				lean_moved = lean_moved or dasher.velocity.length() > 1.0
				lean_air = lean_air or (dasher.dash.air() != null and dasher.dash.air().mode == AirFlow.Mode.GATHER)
				# The warning is the moment to react: step aside, out of the dash line.
				if dodge:
					stand = Vector2(300, 400) + GameScale.world_vector(Vector2(0, 40))
			if dasher.dash.is_dashing():
				dashed = true
				dash_air = dash_air or (dasher.dash.air() != null and dasher.dash.air().mode == AirFlow.Mode.TRAIL)
				hit_while_dashing = hit_while_dashing or dasher.hitbox.monitoring
			if dashed and not struck and dasher.hitbox.monitoring:
				struck = true
				landed_at = dasher.global_position
			player.global_position = stand
			if struck and dasher.state == Enemy.State.RECOVER:
				break
		if not dodge:
			_check(dasher.state == Enemy.State.RECOVER, "the goblin chose a dash attack and recovers after it")
			_check(leaned and not lean_moved, "it leans back first, standing still (the warning)")
			_check(lean_air and dash_air, "air gathers during the lean, then rushes past during the dash")
			_check(dashed and not hit_while_dashing and struck, "a short dash first, then the strike (not during the dash)")
			var gap: float = (stand.x - landed_at.x) / GameScale.world(1.0)
			_check(gap > 5.0 and gap < 25.0, "the dash stops just before the player, not through them (%.1f px left)" % gap)
			var expected_hit: float = Combat.damage_taken(Combat.damage_dealt(dasher_data.stats, dasher_data.attack_damage * 1.3,
				false), player.stats)
			_check(is_equal_approx(health_before - player.health.current_health, expected_hit),
				"the strike after the dash hits the player with +30%% (%.1f, expected %.1f)" % [health_before -
				player.health.current_health, expected_hit])
		else:
			_check(dashed and struck and player.health.current_health == health_before,
				"stepping aside during the lean dodges the dash attack (%.1f -> %.1f)" % [health_before,
				player.health.current_health])
		dasher.queue_free()
		Combat.forced_rolls.clear()

	print("--- grown goblin: heavy dash attack")
	var grown_data: MonsterData = load("res://resources/monsters/goblin_grown.tres")
	_check(grown_data.can_dash_attack() and grown_data.dash_windup_time == 0.4, "the grown goblin also dash attacks, 0.4 s warning")
	_check(grown_data.dash_speed < goblin_data.dash_speed and grown_data.dash_knockback_multiplier >= 1.5,
		"its dash is slower, its knockback bigger (x%.1f)" % grown_data.dash_knockback_multiplier)
	var heavy_data: MonsterData = grown_data.duplicate()
	heavy_data.dash_attack_chance = 1.0
	heavy_data.dash_attack_chance_hurt = 1.0
	var heavy := (load("res://scenes/enemies/enemy.tscn") as PackedScene).instantiate() as Enemy
	heavy.data = heavy_data
	heavy.process_mode = Node.PROCESS_MODE_INHERIT
	room.get_node("World").add_child(heavy)
	player.global_position = Vector2(300, 400)
	player._knockback = Vector2.ZERO
	heavy.global_position = Vector2(300, 400) + GameScale.world_vector(Vector2(-50, 0))
	player.health.heal(1000.0)
	var heavy_health: float = player.health.current_health
	Combat.forced_rolls.assign([0.99, 0.99])
	var thrown: float = 0.0
	for i in 120:
		await get_tree().physics_frame
		thrown = maxf(thrown, player._knockback.length())
		if heavy.state == Enemy.State.RECOVER:
			break
	Combat.forced_rolls.clear()
	var normal_push: float = GameScale.world(heavy_data.attack_knockback) * heavy_data.stats.get_knockback_multiplier()
	_check(player.health.current_health < heavy_health and thrown > normal_push * 1.5,
		"the heavy dash attack throws the player far (%.0f, a normal hit %.0f)" % [thrown, normal_push])
	heavy.queue_free()
	player._knockback = Vector2.ZERO
	player.health.heal(1000.0)
	await get_tree().physics_frame

	print("--- goblin archer: dashes only to flee")
	var fleer := (load("res://scenes/enemies/enemy.tscn") as PackedScene).instantiate() as Enemy
	fleer.data = load("res://resources/monsters/goblin_archer.tres")
	fleer.process_mode = Node.PROCESS_MODE_INHERIT
	room.get_node("World").add_child(fleer)
	player.global_position = Vector2(300, 400)
	fleer.global_position = Vector2(300, 400) + GameScale.world_vector(Vector2(20, 0))
	_check(not fleer.data.can_dash_attack() and fleer.dash != null, "the archer has a dash but never dash attacks")
	var fled: bool = false
	var fled_warned: bool = false
	var fled_struck: bool = false
	var fled_dir: Vector2 = Vector2.ZERO
	for i in 40:
		await get_tree().physics_frame
		player.global_position = Vector2(300, 400)
		fled_warned = fled_warned or fleer.dash.is_winding_up()
		fled_struck = fled_struck or fleer.hitbox.monitoring
		if fleer.dash.is_dashing():
			fled = true
			fled_dir = fleer.dash.direction()
		elif fled:
			break
	var fled_to: float = fleer.global_position.distance_to(player.global_position) / GameScale.world(1.0)
	_check(fled and fled_dir.dot(Vector2.RIGHT) > 0.7 and not fled_warned and not fled_struck,
		"a player too close: the archer dashes away at once, no warning, no strike (%s)" % fled_dir)
	_check(fled_to > 50.0, "and ends up far from the player (%.0f px)" % fled_to)
	fleer.global_position = Vector2(300, 400) + GameScale.world_vector(Vector2(20, 0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(not fleer.dash.is_dashing() and fleer.dash.cooldown_left() > 0.0, "it can't flee again right away (cooldown)")
	fleer.queue_free()

	print("--- walking around walls (monsters) and slipping around corners")
	# A small walled place far from the room: open cells 100..120, a wall at x = 110 from y = 104 down to 116.
	var tile: float = GameScale.TILE_SIZE
	var maze := FloorLayout.new()
	maze.setup(Vector2i(128, 128), 1, 1)
	for y in range(100, 121):
		for x in range(100, 121):
			maze.paint(x, y, Terrain.Type.ROCK if x == 110 and y >= 104 and y <= 116 else Terrain.Type.CAVE)
	var walls := Node2D.new()
	room.get_node("World").add_child(walls)
	for y in range(99, 122):
		for x in range(99, 122):
			if not maze.is_floor(x, y):
				_add_box(walls, (Vector2(x, y) + Vector2(0.5, 0.5)) * tile, Vector2(tile, tile))
	var old_active: FloorLayout = FloorLayout.active
	FloorLayout.active = maze
	FloorPaths.reset()
	var around: PackedVector2Array = FloorPaths.find(Vector2(106.5, 114.5) * tile, Vector2(114.5, 114.5) * tile,
		Vector2(114.5, 114.5) * tile)
	var below_wall: bool = false
	for point in around:
		below_wall = below_wall or point.y > 117.0 * tile
	_check(around.size() >= 6 and below_wall, "a path goes around the end of the wall (%d steps)" % around.size())
	var walker_data: MonsterData = goblin_data.duplicate()
	walker_data.dash_attack_chance = 0.0
	walker_data.dash_attack_chance_hurt = 0.0
	var watcher := (load("res://scenes/enemies/enemy.tscn") as PackedScene).instantiate() as Enemy
	watcher.data = walker_data
	watcher.process_mode = Node.PROCESS_MODE_INHERIT
	room.get_node("World").add_child(watcher)
	watcher.global_position = Vector2(106.5, 108.5) * tile
	player.global_position = Vector2(114.5, 108.5) * tile
	for i in 30:
		await get_tree().physics_frame
	_check(watcher.state == Enemy.State.IDLE, "a player behind a wall, close enough: the goblin does not notice them")
	player.global_position = Vector2(108.5, 108.5) * tile
	for i in 3:
		await get_tree().physics_frame
	_check(watcher.state != Enemy.State.IDLE, "in plain view: noticed")
	watcher.queue_free()
	maze.paint(108, 104, Terrain.Type.TREE)
	_check(not FloorLayout.sight_clear(Vector2(108.5, 102.5) * tile, Vector2(108.5, 106.5) * tile)
		and FloorLayout.sight_clear(Vector2(106.5, 102.5) * tile, Vector2(106.5, 106.5) * tile),
		"a tree hides what is behind it, open floor does not")
	maze.paint(108, 104, Terrain.Type.CAVE)
	var walker := (load("res://scenes/enemies/enemy.tscn") as PackedScene).instantiate() as Enemy
	walker.data = walker_data
	walker.process_mode = Node.PROCESS_MODE_INHERIT
	room.get_node("World").add_child(walker)
	walker.global_position = Vector2(106.5, 114.5) * tile
	var hide_at: Vector2 = Vector2(114.5, 114.5) * tile
	# First seen in the open, then the player hides behind the wall.
	player.global_position = Vector2(108.5, 114.5) * tile
	for i in 3:
		await get_tree().physics_frame
	player.global_position = hide_at
	player.hurtbox.god_mode = true
	var walked_around: bool = false
	var went_below: bool = false
	for i in 600:
		await get_tree().physics_frame
		player.global_position = hide_at
		player._knockback = Vector2.ZERO
		went_below = went_below or walker.global_position.y > 116.5 * tile
		if walker.global_position.x > 110.5 * tile and walker.state == Enemy.State.WINDUP:
			walked_around = true
			break
	_check(walked_around and went_below, "a goblin walks around the wall to the player hiding behind it, then attacks")
	walker.queue_free()
	player.hurtbox.god_mode = false
	FloorLayout.active = old_active
	FloorPaths.reset()
	walls.queue_free()

	# Slipping: walking up into a tree-sized block a little off center goes around it; a wide wall still stops you.
	var open_at: Vector2 = Vector2(4000, 4000)
	for wide in [false, true]:
		var block := Node2D.new()
		room.get_node("World").add_child(block)
		var width: float = tile * 8.0 if wide else tile
		_add_box(block, open_at + Vector2(GameScale.world(5.0), -tile * 1.5), Vector2(width, tile))
		player.global_position = open_at
		await get_tree().physics_frame
		Input.action_press("move_up")
		for i in 90:
			await get_tree().physics_frame
		Input.action_release("move_up")
		await get_tree().physics_frame
		var passed: bool = player.global_position.y < open_at.y - tile * 2.0
		if wide:
			_check(not passed and absf(player.global_position.x - open_at.x) < 4.0,
				"walking into a wide wall: you stop there, no sliding (%s)" % (player.global_position - open_at))
		else:
			_check(passed and player.global_position.x < open_at.x,
				"walking into a tree head-on, a bit off center: you slip past its nearer edge (%s)" %
				(player.global_position - open_at))
		block.queue_free()
		await get_tree().physics_frame
	for bystander in bystanders:
		if is_instance_valid(bystander):
			bystander.process_mode = Node.PROCESS_MODE_INHERIT
	var hurt_goblin := (load("res://scenes/enemies/enemy.tscn") as PackedScene).instantiate() as Enemy
	hurt_goblin.data = goblin_data
	room.get_node("World").add_child(hurt_goblin)
	var healthy_chance: float = hurt_goblin._dash_attack_chance()
	hurt_goblin.health.take_damage(hurt_goblin.health.max_health * 0.7)
	_check(healthy_chance == goblin_data.dash_attack_chance and
		hurt_goblin._dash_attack_chance() == goblin_data.dash_attack_chance_hurt, "low health = dash attacks more often")
	hurt_goblin.queue_free()
	player.health.heal(1000.0)

	print("--- goblin archer")
	var archer := (load("res://scenes/enemies/enemy.tscn") as PackedScene).instantiate() as Enemy
	archer.data = load("res://resources/monsters/goblin_archer.tres")
	archer.process_mode = Node.PROCESS_MODE_INHERIT
	room.get_node("World").add_child(archer)
	player.global_position = Vector2(300, 400)
	archer.global_position = Vector2(300, 400) + GameScale.world_vector(Vector2(90, 0))
	var reached: Array[int] = [0]
	var count_hit := func(_damage: float, _knockback: Vector2, _critical: bool) -> void: reached[0] += 1
	var count_miss := func() -> void: reached[0] += 1
	player.hurtbox.hit_received.connect(count_hit)
	player.hurtbox.hit_missed.connect(count_miss)
	var saw_draw: bool = false
	var saw_arrow: bool = false
	for i in 150:
		await get_tree().physics_frame
		player.global_position = Vector2(300, 400)
		saw_draw = saw_draw or (archer.state == Enemy.State.WINDUP and String(archer.sprite.animation).begins_with("attack_"))
		saw_arrow = saw_arrow or room.get_node("World").get_children().any(func(n: Node) -> bool: return n is Projectile)
	_check(archer.health.max_health == 30.0 and archer.data.is_ranged(), "the goblin archer has 30 health and shoots")
	_check(saw_draw, "the archer draws its bow during the wind-up (visible warning)")
	_check(saw_arrow, "the archer shoots an arrow")
	_check(reached[0] > 0, "the arrow reaches the player")
	player.hurtbox.hit_received.disconnect(count_hit)
	player.hurtbox.hit_missed.disconnect(count_miss)
	archer.queue_free()
	player.health.heal(1000.0)

	print("--- dash (tap Space = short dash where you face, attack during it = normal attack)")
	await _clear(effects)
	var dash: DashAttack = player.dash
	_check(InputMap.has_action("dash") and InputMap.action_get_events("dash").size() > 0, "input action 'dash' mapped")
	player.exhaustion.current = 0.0
	player._attack_cooldown_left = 0.0
	player.global_position = Vector2(300, 400)
	_send_key(KEY_SPACE, true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(not dash.is_busy(), "nothing happens while Space is still held")
	await _release_space()
	var toward_mouse: Vector2 = player.get_global_mouse_position() - player.global_position
	_check(dash.is_dashing() and dash.direction().dot(toward_mouse.normalized()) > 0.99,
		"a tap on Space, standing: dashes toward the mouse (where the character looks)")
	_check(is_equal_approx(player.exhaustion.current, Player.DASH_EXHAUSTION_COST * 0.95),
		"a dash adds 8 exhaustion, x 0.95 from Strength 5 (%.2f)" % player.exhaustion.current)
	_check(not dash.try_dash(Vector2.RIGHT), "no second dash while dashing / on cooldown")
	while dash.is_dashing():
		await get_tree().physics_frame
	await get_tree().physics_frame
	_check(player.collision_mask == 5, "after the dash the player is blocked by monsters again")
	_check(not dash.try_dash(Vector2.RIGHT) and dash.cooldown_left() > 0.3 and dash.cooldown_left() <= Player.DASH_COOLDOWN,
		"short cooldown after the dash (%.2f s left)" % dash.cooldown_left())
	dash._cooldown_left = 0.0
	_send_key(KEY_D, true)
	_send_key(KEY_SPACE, true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _release_space()
	_send_key(KEY_D, false)
	_check(dash.is_dashing() and dash.direction().dot(Vector2.RIGHT) > 0.99, "walking right + tap: dashes right")
	while dash.is_dashing():
		await get_tree().physics_frame
	dash._cooldown_left = 0.0
	_check(is_equal_approx(player.stats.get_dash_power_multiplier(), 1.25), "Agility 5: dashes 25% farther / stronger")

	print("--- charged dash (hold Space) and dash attack (attack while holding)")
	player.exhaustion.current = 0.0
	player.global_position = Vector2(300, 400)
	_send_key(KEY_SPACE, true)
	await get_tree().create_timer(0.6, true, false, true).timeout
	var still_at: Vector2 = player.global_position
	await get_tree().physics_frame
	_check(not dash.is_busy() and player._charge_bar.visible and player.global_position == still_at,
		"holding Space: nothing launches, the player stands still, the charge bar shows")
	_check(dash.air() != null and dash.air().mode == AirFlow.Mode.GATHER and dash.air().particle_count() > 0,
		"charging: air gathers around the player (%d particles)" % (dash.air().particle_count() if dash.air() else 0))
	_check(player.exhaustion.current > Player.DASH_CHARGE_EXHAUSTION_PER_SECOND * 0.95 * 0.3,
		"charging tires (%.1f exhaustion)" % player.exhaustion.current)
	var charge: float = player._dash_charge()
	_check(charge > 0.4 and charge < 0.7, "about half charged after 0.6 s (%.2f)" % charge)
	await _release_space()
	var scale_now: float = dash._speed_scale * dash._speed_scale
	var expected_scale: float = 1.25 * Player.DASH_DISTANCE_FACTOR * lerpf(Player.DASH_CHARGED_DISTANCE_MIN, Player.DASH_CHARGED_DISTANCE_MAX, charge)
	_check(dash.is_dashing() and absf(scale_now - expected_scale) < 0.15 and not player.hitbox.monitoring,
		"released: a long dash without damage (%.2fx the default dash, expected about %.2fx)" % [scale_now, expected_scale])
	_check(not player._charge_bar.visible, "the charge bar hides after the launch")
	while dash.is_dashing():
		await get_tree().physics_frame
	dash._cooldown_left = 0.0

	player.exhaustion.current = 0.0
	_send_key(KEY_SPACE, true)
	await get_tree().create_timer(Player.DASH_FULL_CHARGE_TIME + 0.1, true, false, true).timeout
	var at_full: float = player.exhaustion.current
	await get_tree().create_timer(0.4, true, false, true).timeout
	_check(is_equal_approx(player._dash_charge(), 1.0) and not dash.is_busy(), "full charge: still nothing launches")
	_check(player.exhaustion.current <= at_full + 0.01,
		"full charge: exhaustion stops growing (%.1f -> %.1f)" % [at_full, player.exhaustion.current])
	Combat.forced_rolls.assign([0.99, 0.99, 0.99, 0.99])
	_send_click(true)
	while not Input.is_action_pressed("attack"):
		await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	_send_click(false)
	_check(dash.is_dashing() and is_equal_approx(dash._speed_scale * dash._speed_scale,
		1.25 * Player.DASH_DISTANCE_FACTOR * Player.DASH_CHARGED_DISTANCE_MAX),
		"attack while holding Space: launches at once, as far as a full long dash")
	_check(is_equal_approx(player.hitbox.damage, player.base_attack_damage * Player.DASH_ATTACK_DAMAGE_MAX * 1.25),
		"full dash attack: x2 damage, x1.25 from Agility (%.1f)" % player.hitbox.damage)
	_check(player.character.action == "thrust" and player.character.is_holding(),
		"the dash attack flies with the thrust held out (%s)" % player.character.action)
	await get_tree().create_timer(0.1, true, false, true).timeout
	_check(dash.air() != null and dash.air().mode == AirFlow.Mode.TRAIL and dash.air().particle_count() > 0
		and is_equal_approx(dash.air().intensity, 1.0), "a full dash attack: the most air rushing past")
	_check(player.visual.modulate == Color.WHITE and not effects.get_children().any(func(n: Node) -> bool: return n is Sprite2D),
		"no blue tint or ghost copies, the player keeps its colors")
	_send_key(KEY_SPACE, false)
	while Input.is_action_pressed("dash"):
		await get_tree().process_frame
	while dash.is_dashing():
		await get_tree().physics_frame
	await get_tree().physics_frame
	_check(not dash.is_busy(), "releasing Space after the dash attack launches nothing more")
	_check(not player.character.is_holding(), "the held thrust ends with the dash")
	dash._cooldown_left = 0.0
	player._attack_cooldown_left = 0.0

	player.exhaustion.current = 90.0
	_send_key(KEY_SPACE, true)
	await get_tree().create_timer(0.7, true, false, true).timeout
	_check(dash.is_busy() or dash.cooldown_left() > 0.0, "exhaustion reaching 100 while charging launches the long dash")
	await _release_space()
	while dash.is_dashing():
		await get_tree().physics_frame
	dash._cooldown_left = 0.0
	player.exhaustion.current = 0.0
	player.exhaustion.exhausted = false
	player.exhaustion.current = 0.0
	player.exhaustion.add(200.0)
	_check(not dash.try_dash(Vector2.RIGHT), "no dash at 100 exhaustion")
	player.exhaustion.current = 0.0
	player.exhaustion.exhausted = false
	_check(not player.hurtbox.invulnerable, "no invulnerability by default")

	# Through two goblins standing in a row (to the right: the headless mouse can't aim).
	await _clear(effects)
	player.global_position = Vector2(300, 400)
	var on_path: Array[Enemy] = []
	for offset in [24.0, 62.0]:
		var dummy := (load("res://scenes/enemies/enemy.tscn") as PackedScene).instantiate() as Enemy
		dummy.data = goblin_data
		dummy.process_mode = Node.PROCESS_MODE_INHERIT
		room.get_node("World").add_child(dummy)
		dummy.set_physics_process(false)
		dummy.global_position = player.global_position + GameScale.world_vector(Vector2(offset, 0))
		on_path.append(dummy)
	await get_tree().physics_frame
	dash._cooldown_left = 0.0
	var dash_start: Vector2 = player.global_position
	dash.try_dash(Vector2.RIGHT)
	Combat.forced_rolls.assign([0.99, 0.99, 0.99, 0.99])
	_send_click(true)
	while not Input.is_action_pressed("attack"):
		await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	_send_click(false)
	_check(player._attack_cooldown_left > 0.0, "a click during the dash attacks")
	_check(is_equal_approx(player.hitbox.damage, player.base_attack_damage),
		"an attack during the dash does normal damage (%.1f)" % player.hitbox.damage)
	_check(is_equal_approx(player.exhaustion.current, (Player.DASH_EXHAUSTION_COST + ExhaustionComponent.ATTACK_COST) * 0.95),
		"the attack adds its own exhaustion (%.2f)" % player.exhaustion.current)
	while dash.is_dashing():
		await get_tree().physics_frame
	var dashed: float = (player.global_position.x - dash_start.x) / GameScale.world(1.0)
	_check(dashed > 45.0 and dashed < 70.0, "the dash passes through the goblins, about 58 px (%.1f)" % dashed)
	var air_left: Array = effects.get_children().filter(func(n: Node) -> bool: return n is AirFlow)
	_check(air_left.size() > 0 and dash.air() == null, "after the dash the air fades out on its own")
	dash._cooldown_left = 0.0
	dash.windup_time = 0.4
	var rest_rotation: float = player.visual.rotation
	dash.try_dash(Vector2.RIGHT)
	_check(dash.is_winding_up() and dash.dash_velocity() == Vector2.ZERO and player.visual.rotation != rest_rotation,
		"with a wind-up (monsters) it leans back first, without moving")
	await get_tree().create_timer(0.45, true, false, true).timeout
	_check(not dash.is_winding_up() and player.visual.rotation == rest_rotation, "after the wind-up it stands up and dashes")
	while dash.is_dashing():
		await get_tree().physics_frame
	dash.windup_time = 0.0
	dash._cooldown_left = 0.0
	for dummy in on_path:
		dummy.queue_free()
	player.exhaustion.current = 0.0
	player.exhaustion.exhausted = false
	player._attack_cooldown_left = 0.0
	var sheet_lines: Array = StatTexts.derived(player.stats).filter(func(l: StatTexts.Derived) -> bool:
		return l.key == &"DASH")
	_check(sheet_lines.size() == 1 and sheet_lines[0].value == "+8 / 0.6 s",
		"the character sheet shows the dash cost and cooldown (%s)" % [sheet_lines.map(func(l) -> String: return l.value)])

	print("--- hurt and death animations")
	player.hurtbox.receive_hit(Combat.Hit.new(5.0), Vector2.RIGHT, 0.0)
	_check(player.character.action == "flinch", "a hit makes the player flinch (%s)" % player.character.action)
	player.health.take_damage(1000.0)
	_check(player.character.action == "death", "dying plays the fall (%s)" % player.character.action)

	print("--- result: %s" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)


## `rolls`: miss roll then critical roll (see Combat); the default is a normal hit.
func _hit_with_player(player: Player, enemy: Enemy, rolls: Array[float] = [0.99, 0.99]) -> void:
	# The headless mouse sits at (0, 0), so aim manually and freeze the auto-aim during the swing.
	player.global_position = Vector2(300, 250)
	# Offsets in reference pixels: at 32 px tiles the bodies are bigger and must not overlap.
	enemy.global_position = player.global_position + GameScale.world_vector(Vector2(20, 0))
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


func _send_click(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)


## Releases Space and waits until the game sees it released (input arrives on process frames), plus one physics frame.
func _release_space() -> void:
	_send_key(KEY_SPACE, false)
	while Input.is_action_pressed("dash"):
		await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame


## A solid box (like a wall cell or a tree) centered at `center`, `size` in world pixels.
func _add_box(parent: Node, center: Vector2, size: Vector2) -> void:
	var box := StaticBody2D.new()
	box.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	box.add_child(shape)
	box.position = center
	parent.add_child(box)
