class_name ExhaustionComponent
extends Node
## Exhaustion (replaces stamina): grows from 0 to MAX with sprinting and attacking, recovers after a pause.
## Above TIRED_THRESHOLD you are slower; reaching MAX makes you exhausted (no sprint, less damage) until it
## drops below TIRED_THRESHOLD again. Every number is a constant here (balanced often).

signal exhaustion_changed(current: float, maximum: float)

const MAX: float = 100.0
## Gained per second of sprinting.
const SPRINT_PER_SECOND: float = 10.0
## Gained per attack (abilities will add their own costs).
const ATTACK_COST: float = 3.0
## Seconds without sprinting or attacking before it starts to drop.
const RECOVERY_DELAY: float = 1.5
const RECOVERY_PER_SECOND: float = 15.0
## Above this: movement and attacks are slower.
const TIRED_THRESHOLD: float = 70.0
## Movement and attack speed above TIRED_THRESHOLD (0.8 = 20% slower).
const TIRED_SPEED_FACTOR: float = 0.8
## Damage while exhausted (0.6 = 40% less).
const EXHAUSTED_DAMAGE_FACTOR: float = 0.6

var current: float = 0.0
## Multiplier for every gain (Strength lowers it); set by the owner from its Stats.
var gain_multiplier: float = 1.0
## Reached MAX and has not dropped below TIRED_THRESHOLD yet.
var exhausted: bool = false
var _delay_left: float = 0.0


func _ready() -> void:
	exhaustion_changed.emit(current, MAX)


## Adds exhaustion (scaled by gain_multiplier) and restarts the recovery delay.
func add(amount: float) -> void:
	current = minf(current + amount * gain_multiplier, MAX)
	_delay_left = RECOVERY_DELAY
	if current >= MAX:
		exhausted = true
	exhaustion_changed.emit(current, MAX)


func is_tired() -> bool:
	return current > TIRED_THRESHOLD


func can_sprint() -> bool:
	return not exhausted


## Movement and attack speed factor (1.0 when not tired).
func speed_factor() -> float:
	return TIRED_SPEED_FACTOR if is_tired() else 1.0


## Damage factor (1.0 unless exhausted).
func damage_factor() -> float:
	return EXHAUSTED_DAMAGE_FACTOR if exhausted else 1.0


func _process(delta: float) -> void:
	if _delay_left > 0.0:
		_delay_left -= delta
		return
	if current > 0.0:
		current = maxf(current - RECOVERY_PER_SECOND * delta, 0.0)
		if current < TIRED_THRESHOLD:
			exhausted = false
		exhaustion_changed.emit(current, MAX)
