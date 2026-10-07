class_name EnemyMeleeBehavior
extends Node
## Reusable, direction-locked telegraph -> melee -> recovery cycle. Never activates a hitbox directly.

signal windup_started(direction: Vector2, duration: float)
signal attack_started(direction: Vector2, duration: float)
signal recovery_started(duration: float)
signal cycle_finished

enum Phase { NONE, WINDUP, ATTACK, RECOVER }

var phase: Phase = Phase.NONE
var time_left: float = 0.0
var direction: Vector2 = Vector2.RIGHT
var _data: MonsterData


func setup(monster: MonsterData) -> void:
	_data = monster


func begin_windup(aim: Vector2) -> void:
	direction = aim
	phase = Phase.WINDUP
	time_left = _data.windup_time
	windup_started.emit(direction, time_left)


func tick(delta: float) -> Vector2:
	var move: Vector2 = direction * GameScale.world(_data.lunge_speed) if phase == Phase.ATTACK else Vector2.ZERO
	time_left -= delta
	if time_left > 0.0:
		return move
	match phase:
		Phase.WINDUP:
			phase = Phase.ATTACK
			time_left = _data.attack_active_time
			attack_started.emit(direction, time_left)
		Phase.ATTACK:
			interrupt(_data.recovery_time / _data.stats.get_attack_speed_multiplier())
		Phase.RECOVER:
			stop()
			cycle_finished.emit()
	return move


## A stagger interrupts the telegraph without ever starting a hitbox.
func interrupt(duration: float) -> void:
	phase = Phase.RECOVER
	time_left = duration
	recovery_started.emit(duration)


func stop() -> void:
	phase = Phase.NONE
	time_left = 0.0
