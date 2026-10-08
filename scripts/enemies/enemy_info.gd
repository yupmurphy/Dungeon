class_name EnemyInfo
extends Node2D
## Health bar and name above a monster, shown by the player's Perception (Stats thresholds). Lives on GameFeel's
## effect layer (not dimmed by the darkness) and follows its monster; fades with it at the edge of sight.
## The name is colored by the monster's power compared with the player's (Combat.power_rating).

## Reference pixels (see GameScale).
const BAR_SIZE: Vector2 = Vector2(16, 2)
## Gap between the top of the monster's sprite and the bar.
const BAR_GAP: float = 3.0
const NAME_FONT_SIZE: int = 8
const BAR_BACK_COLOR: Color = Color(0.05, 0.05, 0.05, 0.85)
const BAR_FILL_COLOR: Color = Color(0.85, 0.15, 0.15)
## Monster power / player power: below WEAK_RATIO = much weaker (white), above STRONG_RATIO = stronger (red),
## in between = about equal (yellow).
const WEAK_RATIO: float = 0.5
const STRONG_RATIO: float = 1.1
const WEAK_COLOR: Color = Color(1.0, 1.0, 1.0)
const EQUAL_COLOR: Color = Color(1.0, 0.85, 0.2)
const STRONG_COLOR: Color = Color(1.0, 0.25, 0.2)

var enemy: Enemy
var player: Player

var _name_label: Label


func _ready() -> void:
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_name_label.add_theme_constant_override("outline_size", 3)
	add_child(_name_label)


func _process(_delta: float) -> void:
	if not is_instance_valid(enemy) or enemy.state == Enemy.State.DEAD:
		queue_free()
		return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
		if player == null:
			return
	var bar: bool = player.stats.shows_monster_health_bars()
	var named: bool = player.stats.shows_monster_names()
	visible = (bar or named) and enemy.modulate.a > 0.0 and enemy.is_visible_in_tree()
	if not visible:
		return
	modulate.a = enemy.modulate.a
	global_position = enemy.global_position + Vector2(0, -enemy.head_height() - GameScale.world(BAR_GAP))
	_name_label.visible = named
	if named:
		_name_label.text = enemy.data.display_name
		_name_label.modulate = power_color()
		_name_label.size = _name_label.get_minimum_size()
		_name_label.position = Vector2(-_name_label.size.x / 2.0, -GameScale.world(BAR_SIZE.y + 1.0) - _name_label.size.y)
	queue_redraw()


## White = much weaker than the player, yellow = about equal, red = stronger.
func power_color() -> Color:
	var monster: MonsterData = enemy.data
	var ratio: float = Combat.power_rating(monster.stats, monster.attack_damage, monster.get_max_health()) \
		/ Combat.power_rating(player.stats, player.base_attack_damage)
	if ratio < WEAK_RATIO:
		return WEAK_COLOR
	if ratio > STRONG_RATIO:
		return STRONG_COLOR
	return EQUAL_COLOR


func _draw() -> void:
	if not is_instance_valid(player) or not is_instance_valid(enemy) or not player.stats.shows_monster_health_bars():
		return
	var size: Vector2 = GameScale.world_vector(BAR_SIZE)
	var rect := Rect2(-size.x / 2.0, -size.y, size.x, size.y)
	draw_rect(rect.grow(1.0), BAR_BACK_COLOR)
	var ratio: float = clampf(enemy.health.current_health / enemy.health.max_health, 0.0, 1.0)
	draw_rect(Rect2(rect.position, Vector2(size.x * ratio, size.y)), BAR_FILL_COLOR)
