extends CharacterBody2D

signal ball_returned
signal ball_landed(x_pos: float)
var direction: Vector2 = Vector2.ZERO
var speed: float = 800.0
var damage: int = 1
var damage_multiplier: float = 1.0
var is_active: bool = true
var launched: bool = false
var is_powered: bool = false
var applies_burn: bool = false

# Stuck detection
var wall_bounce_count: int = 0
var last_brick_hit_time: float = 0.0
var time_alive: float = 0.0
var stuck_threshold: float = 1.5
var last_wall_bounce_time: float = 0.0
var max_alive_time: float = 15.0  # force return after 15 seconds alive

# Trail
var trail_points: Array = []
var max_trail_points: int = 8
var trail_timer: float = 0.0
var trail_interval: float = 0.015  # spawn trail dot every 15ms

func _ready():
	add_to_group("balls")
	queue_redraw()

func get_ball_color() -> Color:
	if applies_burn:
		return Color(0.95, 0.55, 0.15)
	elif is_powered:
		return Color(0.85, 0.3, 0.25)
	else:
		return Color(0.3, 0.55, 0.95)

func _draw():
	# Draw trail
	for i in range(trail_points.size()):
		var point = trail_points[i]
		var age_ratio = float(i) / max(trail_points.size(), 1)  # 0 = oldest, 1 = newest
		var alpha = age_ratio * 0.4
		var size = 3.0 + age_ratio * 4.0
		var col = get_ball_color()
		col.a = alpha
		draw_circle(point - position, size, col)
	# Draw ball
	if applies_burn:
		draw_circle(Vector2.ZERO, 10, Color(0.95, 0.5, 0.1, 0.2))
		draw_circle(Vector2.ZERO, 8, Color(0.95, 0.55, 0.15))
	elif is_powered:
		draw_circle(Vector2.ZERO, 10, Color(0.9, 0.2, 0.15, 0.25))
		draw_circle(Vector2.ZERO, 8, Color(0.85, 0.3, 0.25))
	else:
		draw_circle(Vector2.ZERO, 8, Color(0.3, 0.55, 0.95))

func _physics_process(delta):
	if not launched or not is_active:
		return
	time_alive += delta

	# Trail recording
	trail_timer += delta
	if trail_timer >= trail_interval:
		trail_timer = 0.0
		trail_points.append(position)
		if trail_points.size() > max_trail_points:
			trail_points.pop_front()

	velocity = direction * speed
	var collision = move_and_collide(velocity * delta)

	if collision:
		direction = direction.bounce(collision.get_normal())
		var collider = collision.get_collider()
		if collider.has_method("take_damage"):
			collider.take_damage(int(damage * damage_multiplier), direction)
			if applies_burn and collider.has_method("add_burn_stack"):
				collider.add_burn_stack()
			last_brick_hit_time = time_alive
			wall_bounce_count = 0
			var manager = get_tree().get_first_node_in_group("game_manager")
			if manager and manager.sound_manager:
				manager.sound_manager.play_hit()
				manager.on_brick_hit()
		else:
			wall_bounce_count += 1
			last_wall_bounce_time = time_alive
			var manager = get_tree().get_first_node_in_group("game_manager")
			if manager and manager.sound_manager:
				manager.sound_manager.play_bounce()

	# Stuck detection
	if time_alive - last_brick_hit_time > stuck_threshold and wall_bounce_count > 4:
		unstick()

	# Hard timeout 	6 force return if ball has been alive too long
	if time_alive > max_alive_time:
		is_active = false
		ball_landed.emit(position.x)
		ball_returned.emit()
		queue_free()
		return

	queue_redraw()

	if position.y > 540:
		is_active = false
		ball_landed.emit(position.x)
		ball_returned.emit()
		queue_free()

func unstick():
	if abs(direction.y) < 0.3:
		direction.y = -0.5 if direction.y < 0 else 0.5
		direction = direction.normalized()
	else:
		direction = direction.rotated(randf_range(-0.3, 0.3))
		direction = direction.normalized()
	wall_bounce_count = 0
	last_brick_hit_time = time_alive

func launch(dir: Vector2):
	direction = dir
	launched = true
