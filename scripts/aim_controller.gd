extends Node2D

func get_trajectory_points(origin: Vector2, direction: Vector2, max_bounces: int = 2, max_dist: float = 800.0) -> Array:
	var points = [origin]
	var space_state = get_world_2d().direct_space_state
	var current_pos = origin
	var current_dir = direction
	for i in range(max_bounces):
		var query = PhysicsRayQueryParameters2D.create(current_pos, current_pos + current_dir * max_dist)
		var result = space_state.intersect_ray(query)
		if result:
			points.append(result.position)
			current_dir = current_dir.bounce(result.normal)
			current_pos = result.position + current_dir * 2
		else:
			points.append(current_pos + current_dir * max_dist)
			break

	return points
