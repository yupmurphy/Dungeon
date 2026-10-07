class_name DamageNumber
extends Label
## Number (or short word like "miss") that pops above a target, floats up and fades out.

## Reference pixels (see GameScale): start height above the target, then how far it floats up.
const RAISE: float = 24.0
const RISE: float = 14.0
const LIFETIME: float = 0.6
## Critical hits: bigger font and they live a bit longer.
const CRITICAL_FONT_SIZE: int = 14
const CRITICAL_LIFETIME: float = 0.8


func setup(world_position: Vector2, shown_text: String, color: Color, critical: bool = false) -> void:
	text = shown_text
	modulate = color
	var lifetime: float = LIFETIME
	if critical:
		add_theme_font_size_override("font_size", CRITICAL_FONT_SIZE)
		lifetime = CRITICAL_LIFETIME
	size = get_minimum_size()
	pivot_offset = size / 2.0
	position = world_position + Vector2(-size.x / 2.0 + randf_range(-4.0, 4.0), -GameScale.world(RAISE) - size.y / 2.0)
	scale = Vector2(1.6, 1.6)

	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(self, "scale", Vector2.ONE, 0.15)
	tween.tween_property(self, "position:y", position.y - GameScale.world(RISE), lifetime) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, lifetime * 0.5).set_delay(lifetime * 0.5)
	tween.chain().tween_callback(queue_free)
