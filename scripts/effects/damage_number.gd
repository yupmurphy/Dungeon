class_name DamageNumber
extends Label
## Number that pops above a target, floats up and fades out.

const RISE: float = 14.0
const LIFETIME: float = 0.6


func setup(world_position: Vector2, amount: float, color: Color) -> void:
	text = str(roundi(amount))
	modulate = color
	pivot_offset = size / 2.0
	position = world_position + Vector2(-size.x / 2.0 + randf_range(-4.0, 4.0), -24.0)
	scale = Vector2(1.6, 1.6)

	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(self, "scale", Vector2.ONE, 0.15)
	tween.tween_property(self, "position:y", position.y - RISE, LIFETIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, LIFETIME * 0.5).set_delay(LIFETIME * 0.5)
	tween.chain().tween_callback(queue_free)
