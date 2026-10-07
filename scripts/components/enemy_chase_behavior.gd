class_name EnemyChaseBehavior
extends Node
## Reusable detection/chase component. Signals up; the owning enemy decides its state.

signal target_found(target: Player)
signal target_lost
signal attack_requested(direction: Vector2)

var _body: Node2D
var _data: MonsterData


func setup(body: Node2D, monster: MonsterData) -> void:
	_body = body
	_data = monster


func scan() -> void:
	var target := get_tree().get_first_node_in_group("player") as Player
	if target != null and not target.is_dead \
			and _body.global_position.distance_to(target.global_position) <= GameScale.world(_data.detect_range):
		target_found.emit(target)


func movement(target: Player) -> Vector2:
	if not is_instance_valid(target) or target.is_dead:
		target_lost.emit()
		return Vector2.ZERO
	var to_target: Vector2 = target.global_position - _body.global_position
	var distance: float = to_target.length()
	if distance > GameScale.world(_data.lose_range):
		target_lost.emit()
		return Vector2.ZERO
	if distance <= GameScale.world(_data.attack_range):
		attack_requested.emit(to_target.normalized())
		return Vector2.ZERO
	return to_target.normalized() * GameScale.world(_data.move_speed) * _data.stats.get_move_speed_multiplier() \
		* FloorLayout.speed_factor_at(_body.global_position)
