extends Node
## Automated combat checks on the real test room.
## Run:  <godot.exe> --headless --path . -- --smoke-test     (exit code 0 = all passed)

const GOBLIN_HEALTH: float = 35.0
const GOBLIN_BASE_DAMAGE: float = 12.0
const GOBLIN_DEFENSE: float = 0.0
const GOBLIN_XP: int = 1
const GOBLIN_NORMAL_DAMAGE: float = 12.72
const GOBLIN_STRENGTH_TEST: int = 2
const GOBLIN_STRENGTH_HEALTH: float = 55.0
const GOBLIN_STRENGTH_DEFENSE: float = 1.0
const GOBLIN_TEST_DELTA: float = 0.01
const CAMP_TEST_MAP_SIZE: Vector2i = Vector2i(11, 11)
const CAMP_TEST_ORIGIN: Vector2i = Vector2i(5, 5)
const CAMP_TEST_OPEN_MIN: int = 3
const CAMP_TEST_OPEN_MAX: int = 7
const CAMP_TEST_ISLAND: Vector2i = Vector2i(9, 5)
const GOBLIN_HEAD_ID: String = "head_goblin"
const GOBLIN_PREVIEW_NAMES: Array[String] = ["Goblin1", "Goblin2", "Goblin3"]

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
	# Preview group is for manual play; keep it out of deterministic legacy combat checks.
	for goblin_name in GOBLIN_PREVIEW_NAMES:
		room.get_node("World/" + goblin_name).process_mode = Node.PROCESS_MODE_DISABLED

	print("--- setup")
	_check(WallAtmosphereChecks._projecting_mounts_ok(room),
		"wall torches: full front handle clears the floor; other three mounts remain correct")
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
	_check(is_equal_approx(tired.current, 2.85), "an attack adds 3, x 0.95 from Vitality 5 (%.2f)" % tired.current)
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

	await _check_goblin(room, player)

	print("--- hurt and death animations")
	player.hurtbox.receive_hit(Combat.Hit.new(5.0), Vector2.RIGHT, 0.0)
	_check(player.character.action == "flinch", "a hit makes the player flinch (%s)" % player.character.action)
	player.health.take_damage(1000.0)
	_check(player.character.action == "death", "dying plays the fall (%s)" % player.character.action)

	await _check_town_exterior()

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


func _check_goblin(room: Node, player: Player) -> void:
	_check_camp_territory()
	print("--- goblin and reusable behaviors")
	for node in get_tree().get_nodes_in_group("enemy"):
		(node as Enemy).process_mode = Node.PROCESS_MODE_DISABLED
	var source := load("res://resources/monsters/goblin.tres") as MonsterData
	var enemy_scene := load("res://scenes/enemies/enemy.tscn") as PackedScene
	var goblin := enemy_scene.instantiate() as Enemy
	goblin.data = source
	goblin.position = player.global_position + GameScale.world_vector(Vector2(50, 0))
	room.get_node("World").add_child(goblin)
	goblin.set_physics_process(false)  # Exercise phases explicitly, not random/frame-rate-dependent AI.
	_check(goblin.health.max_health == GOBLIN_HEALTH and goblin.data.stats.get_max_health() == GOBLIN_HEALTH,
		"goblin health and Stats agree: 35 HP")
	_check(goblin.data.stats.get_defense() == GOBLIN_DEFENSE and goblin.hitbox.damage == GOBLIN_BASE_DAMAGE
		and goblin.data.xp_reward == GOBLIN_XP, "goblin: base damage 12 / defense 0 / first-kill reward data 1")
	_check(goblin.data != source and goblin.data.stats != source.stats and source.stats.get_max_health() == Stats.HEALTH_BASE,
		"runtime species bases do not mutate shared stats/resources")
	var stronger: Stats = source.runtime_copy().stats
	stronger.strength = GOBLIN_STRENGTH_TEST
	_check(stronger.get_max_health() == GOBLIN_STRENGTH_HEALTH and stronger.get_defense() == GOBLIN_STRENGTH_DEFENSE,
		"species bases still use the existing Strength health/defense bonuses")
	_check(goblin.chase_behavior != null and goblin.melee_behavior != null
		and goblin.chase_behavior.get_parent() == goblin and goblin.melee_behavior.get_parent() == goblin,
		"chase and melee are reusable child components")
	_check(LpcCatalog.has_item(GOBLIN_HEAD_ID) and not LpcCatalog.item(GOBLIN_HEAD_ID).get("layers", []).is_empty(),
		"goblin head imported into the LPC catalog")
	_check(goblin.character != null and GOBLIN_HEAD_ID in goblin.character.items and not goblin.sprite.visible,
		"goblin uses LPC paper doll, not a placeholder sprite")
	for action in ["idle", "walk", "slash", "flinch", "death"]:
		_check(goblin.character.has_action(action), "goblin has LPC '%s' action" % action)
	_check(goblin.data.localized_name() == "Goblin", "goblin name comes from English localization")
	Combat.forced_rolls.assign([0.99, 0.99])
	var normal: Combat.Hit = Combat.resolve(goblin.data.stats, null, goblin.data.attack_damage)
	_check(not normal.missed and not normal.critical and is_equal_approx(normal.damage, GOBLIN_NORMAL_DAMAGE),
		"Combat applies stat bonus to base damage 12 (normal 12.72 before target defense)")

	goblin._on_target_found(player)
	var _movement: Vector2 = goblin.chase_behavior.movement(player)
	_check(goblin.state == Enemy.State.CHASE, "outside attack range, goblin stays in chase")
	goblin.global_position = player.global_position + GameScale.world_vector(Vector2(20, 0))
	_movement = goblin.chase_behavior.movement(player)
	_check(goblin.state == Enemy.State.WINDUP and not goblin.hitbox.monitoring, "in range: telegraph starts before any active hitbox")
	var locked: Vector2 = goblin.melee_behavior.direction
	player.global_position += GameScale.world_vector(Vector2(0, 50))
	goblin.melee_behavior.tick(source.windup_time - GOBLIN_TEST_DELTA)
	_check(goblin.state == Enemy.State.WINDUP and goblin.melee_behavior.direction == locked,
		"telegraph keeps its locked aim when player moves")
	goblin.melee_behavior.interrupt(Enemy.STAGGER_TIME)
	_check(goblin.state == Enemy.State.RECOVER and not goblin.hitbox.monitoring,
		"interrupting windup cancels the attack")
	goblin.melee_behavior.tick(Enemy.STAGGER_TIME + GOBLIN_TEST_DELTA)
	_check(goblin.state == Enemy.State.CHASE, "stagger recovery ends in chase")
	goblin.melee_behavior.begin_windup(Vector2.RIGHT)
	goblin.melee_behavior.tick(source.windup_time + GOBLIN_TEST_DELTA)
	_check(goblin.state == Enemy.State.ATTACK and goblin.character.action == "slash",
		"complete telegraph starts melee and LPC slash")
	goblin.hitbox.deactivate()
	goblin.melee_behavior.tick(source.attack_active_time + GOBLIN_TEST_DELTA)
	_check(goblin.state == Enemy.State.RECOVER, "attack is followed by recovery")
	goblin.melee_behavior.stop()
	goblin._set_state(Enemy.State.IDLE, 0.0)
	Combat.forced_rolls.clear()

	await _hit_with_player(player, goblin)
	var taken: float = Combat.damage_taken(Combat.damage_dealt(player.stats, player.base_attack_damage, false), goblin.data.stats)
	_check(is_equal_approx(goblin.health.current_health, GOBLIN_HEALTH - taken), "player damages goblin through shared Combat/Hurtbox")
	goblin.health.take_damage(GOBLIN_HEALTH)
	_check(goblin.state == Enemy.State.DEAD and goblin.character.action == "death"
		and not goblin.is_in_group("enemy") and goblin.melee_behavior.phase == EnemyMeleeBehavior.Phase.NONE,
		"goblin death stops behaviors and plays LPC fall")
	goblin.queue_free()
	await get_tree().process_frame


func _check_camp_territory() -> void:
	var layout := FloorLayout.new()
	layout.setup(CAMP_TEST_MAP_SIZE, 1, 1)
	for y in range(CAMP_TEST_OPEN_MIN, CAMP_TEST_OPEN_MAX + 1):
		for x in range(CAMP_TEST_OPEN_MIN, CAMP_TEST_OPEN_MAX + 1):
			layout.set_slot(x, y, 0)
			layout.paint(x, y, Terrain.Type.CAVE)
	layout.set_floor(CAMP_TEST_ORIGIN.x, CAMP_TEST_ORIGIN.y, false)
	layout.set_slot(CAMP_TEST_ISLAND.x, CAMP_TEST_ISLAND.y, 0)
	layout.paint(CAMP_TEST_ISLAND.x, CAMP_TEST_ISLAND.y, Terrain.Type.CAVE)
	var monster: MonsterData = load("res://resources/monsters/goblin.tres") as MonsterData
	var territory: Dictionary = FloorPopulator._feature_territory(layout, 0, CAMP_TEST_ORIGIN, monster, {})
	var expected: int = (CAMP_TEST_OPEN_MAX - CAMP_TEST_OPEN_MIN + 1) ** 2 - 1
	_check(territory.size() == expected and not territory.has(CAMP_TEST_ORIGIN)
		and not territory.has(CAMP_TEST_ISLAND), "camp territory survives a solid center, stays connected and excludes isolated floor")


func _check_town_exterior() -> void:
	print("--- town exterior")
	var unit: Dictionary = TownChecks.unit_results()
	for title: String in unit:
		_check(unit[title], title)
	get_tree().change_scene_to_file.call_deferred("res://scenes/town/town.tscn")
	for frame in TownChecks.SETTLE_FRAMES:
		await get_tree().physics_frame
	var town := get_tree().current_scene as TownLevel
	_check(town != null, "town scene loads independently from dungeon")
	if town != null:
		var results: Dictionary = TownChecks.scene_results(town)
		for title: String in results:
			_check(results[title], title)
