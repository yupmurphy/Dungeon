class_name ParticleBurst
extends CPUParticles2D
## One-shot burst of square particles that frees itself when done.


func setup(world_position: Vector2, burst_color: Color, burst_amount: int, speed: float) -> void:
	global_position = world_position
	color = burst_color
	amount = maxi(burst_amount, 1)
	initial_velocity_min = speed * 0.5
	initial_velocity_max = speed
	finished.connect(queue_free)
	emitting = true
