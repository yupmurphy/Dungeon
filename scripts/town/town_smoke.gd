class_name TownSmoke
extends CPUParticles2D
## Chimney smoke: soft grey puffs that rise, drift with the wind and fade. TownLevel puts one on every
## building with a chimney and on the forge.

const PUFFS: int = 10
const LIFETIME: float = 3.2
const RISE_SPEED: float = 14.0
const WIND: Vector2 = Vector2(5.0, -4.0)
## Puff size as a part of the light texture (128 px): 0.1 = 13 px, growing to GROW times that.
const START_SCALE: float = 0.1
const GROW: float = 2.5
const COLOR: Color = Color(0.82, 0.82, 0.85, 0.55)


static func create() -> TownSmoke:
	var smoke := TownSmoke.new()
	smoke.amount = PUFFS
	smoke.lifetime = LIFETIME
	smoke.preprocess = LIFETIME
	smoke.direction = Vector2.UP
	smoke.spread = 12.0
	smoke.gravity = WIND
	smoke.initial_velocity_min = RISE_SPEED * 0.7
	smoke.initial_velocity_max = RISE_SPEED
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.max_value = GROW
	curve.add_point(Vector2(1, GROW))
	smoke.scale_amount_curve = curve
	var fade := Gradient.new()
	fade.set_color(0, COLOR)
	fade.set_color(1, Color(COLOR, 0.0))
	smoke.color_ramp = fade
	smoke.texture = TownLighting.light_texture()
	smoke.scale_amount_min = START_SCALE
	smoke.scale_amount_max = START_SCALE
	smoke.z_index = 1
	return smoke


## Adds smoke on top of a building's chimney (no chimney = nothing).
static func attach(building: TownBuilding) -> void:
	if building.chimney_x < 0:
		return
	var smoke := create()
	smoke.position = building.chimney_top()
	building.add_child(smoke)
