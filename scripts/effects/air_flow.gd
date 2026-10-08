class_name AirFlow
extends Node2D
## Moving air around a character: wind streaks and fine dust, no tint on the character itself.
## GATHER: air drawn in toward the character (charging, a monster's wind-up).
## TRAIL: streaks rushing past and dust left behind (dashing).
## Lives on the GameFeel layer (above the darkness) and follows `target`; frees itself once OFF and empty.
## Sizes and speeds are reference pixels (GameScale). `intensity` 0..1 scales how much air there is.

enum Mode { OFF, GATHER, TRAIL }

const COLOR: Color = Color(0.92, 0.95, 1.0)
const MAX_ALPHA: float = 0.75
## Particles per second at intensity 0 and at intensity 1.
const GATHER_RATE_MIN: float = 25.0
const GATHER_RATE_MAX: float = 110.0
const TRAIL_RATE_MIN: float = 60.0
const TRAIL_RATE_MAX: float = 200.0
## Gather: particles start on a ring this far from the center and reach it in GATHER_LIFE seconds, swirling.
const GATHER_RADIUS_MIN: float = 12.0
const GATHER_RADIUS_MAX: float = 26.0
const GATHER_LIFE: float = 0.35
const GATHER_SWIRL: float = 0.6
## Trail: streaks around the body (up to TRAIL_SPREAD to the side), flying back at TRAIL_SPEED.
const TRAIL_SPREAD: float = 10.0
const TRAIL_SPEED: float = 140.0
const TRAIL_LIFE: float = 0.22
const DUST_LIFE: float = 0.4
## Streak length at intensity 0 and 1; dust dot size.
const STREAK_LENGTH_MIN: float = 4.0
const STREAK_LENGTH_MAX: float = 11.0
const STREAK_WIDTH: float = 1.0
const DUST_SIZE: float = 1.0
## The body's center is above its origin by this much (the feet are at the origin).
const CENTER_OFFSET: Vector2 = Vector2(0, -8)

var target: Node2D
var mode: Mode = Mode.OFF
var intensity: float = 0.0
## The dash direction (TRAIL).
var direction: Vector2 = Vector2.RIGHT

## Each particle: position, velocity, life left, full life, streak (true) or dust (false).
var _particles: Array[Dictionary] = []
var _spawn_debt: float = 0.0


func _ready() -> void:
	z_index = 3


func particle_count() -> int:
	return _particles.size()


func _process(delta: float) -> void:
	if not is_instance_valid(target):
		mode = Mode.OFF
	if mode != Mode.OFF:
		_spawn(delta)
	elif _particles.is_empty():
		queue_free()
		return
	for p in _particles:
		p["life"] -= delta
		p["position"] += p["velocity"] * delta
	_particles = _particles.filter(func(p: Dictionary) -> bool: return p["life"] > 0.0)
	queue_redraw()


func _spawn(delta: float) -> void:
	var rate: float = lerpf(GATHER_RATE_MIN, GATHER_RATE_MAX, intensity) if mode == Mode.GATHER \
		else lerpf(TRAIL_RATE_MIN, TRAIL_RATE_MAX, intensity)
	_spawn_debt += rate * delta
	var center: Vector2 = target.global_position + GameScale.world_vector(CENTER_OFFSET)
	while _spawn_debt >= 1.0:
		_spawn_debt -= 1.0
		if mode == Mode.GATHER:
			var angle: float = randf() * TAU
			var radius: float = GameScale.world(randf_range(GATHER_RADIUS_MIN, GATHER_RADIUS_MAX))
			var start: Vector2 = center + Vector2.from_angle(angle) * radius
			var inward: Vector2 = (center - start) / GATHER_LIFE
			_add(start, inward + inward.orthogonal() * GATHER_SWIRL, GATHER_LIFE, true)
		else:
			var side: Vector2 = direction.orthogonal() * GameScale.world(randf_range(-TRAIL_SPREAD, TRAIL_SPREAD))
			var along: Vector2 = direction * GameScale.world(randf_range(-6.0, 8.0))
			var back: Vector2 = -direction * GameScale.world(TRAIL_SPEED) * randf_range(0.6, 1.2)
			if randf() < 0.6:
				_add(center + side + along, back, TRAIL_LIFE, true)
			else:
				var drift := Vector2.from_angle(randf() * TAU) * GameScale.world(randf_range(5.0, 20.0))
				_add(center + side * 0.6 - direction * GameScale.world(4.0), drift + back * 0.15, DUST_LIFE, false)


func _add(start: Vector2, velocity: Vector2, life: float, streak: bool) -> void:
	_particles.append({"position": start, "velocity": velocity, "life": life, "max_life": life, "streak": streak})


func _draw() -> void:
	var length: float = GameScale.world(lerpf(STREAK_LENGTH_MIN, STREAK_LENGTH_MAX, intensity))
	var alpha_scale: float = MAX_ALPHA * lerpf(0.5, 1.0, intensity)
	for p in _particles:
		var t: float = p["life"] / p["max_life"]
		# Fades in quickly, then out.
		var alpha: float = alpha_scale * minf(t, 1.0 - t) * 2.0
		var color := Color(COLOR, clampf(alpha, 0.0, 1.0))
		var pos: Vector2 = p["position"]
		if p["streak"]:
			var tail: Vector2 = (p["velocity"] as Vector2).normalized() * length
			draw_line(pos - tail, pos, color, GameScale.world(STREAK_WIDTH))
		else:
			var size: float = GameScale.world(DUST_SIZE)
			draw_rect(Rect2(pos - Vector2(size, size) * 0.5, Vector2(size, size)), color)
