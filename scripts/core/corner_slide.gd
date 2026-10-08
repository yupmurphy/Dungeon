class_name CornerSlide
## Slipping around obstacles: a body walking straight into a wall, tree or rock is not stuck there, it slides
## sideways toward the nearer free edge (if one is close enough) and goes on around it. Other characters are not
## slipped around.
## move_and_slide already slides along a wall met at an angle; this handles the head-on case.
## Call apply() right after move_and_slide(), with the movement the body wanted (without knockback).
## Distances are reference pixels (GameScale).

## Only when the wall faces the movement this much (1 = exactly head-on; dot of movement and -normal).
const HEAD_ON: float = 0.6
## Looks this far to each side for a free way around (more than half a tree tile + a body radius).
const SEARCH_DISTANCE: float = 14.0
const SEARCH_STEP: float = 2.0
## Sideways speed, compared with the wanted speed.
const SLIDE_SPEED_RATIO: float = 0.8
## How far ahead the free way must be open.
const PROBE_AHEAD: float = 2.0


static func apply(body: CharacterBody2D, wanted: Vector2, delta: float) -> void:
	if wanted.length_squared() < 0.01 or body.get_slide_collision_count() == 0:
		return
	var forward: Vector2 = wanted.normalized()
	var blocked: bool = false
	for i in body.get_slide_collision_count():
		var collision: KinematicCollision2D = body.get_slide_collision(i)
		# Only the world (walls, trees, props): walking into a monster or the player is not slipped around.
		if collision.get_collider() is CharacterBody2D:
			continue
		if forward.dot(-collision.get_normal()) >= HEAD_ON:
			blocked = true
			break
	if not blocked:
		return
	var ahead: Vector2 = forward * GameScale.world(PROBE_AHEAD)
	var step: float = SEARCH_STEP
	while step <= SEARCH_DISTANCE:
		for side in [1.0, -1.0]:
			var sideways: Vector2 = forward.orthogonal() * side * GameScale.world(step)
			# The side must be open, and from there the way forward too.
			if body.test_move(body.global_transform, sideways):
				continue
			if body.test_move(body.global_transform.translated(sideways), ahead):
				continue
			var move: float = minf(wanted.length() * SLIDE_SPEED_RATIO * delta, sideways.length())
			body.move_and_collide(sideways.normalized() * move)
			return
		step += SEARCH_STEP
