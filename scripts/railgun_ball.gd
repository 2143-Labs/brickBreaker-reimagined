extends CharacterBody2D

signal ball_returned
signal ball_landed(x_pos: float)
var direction: Vector2 = Vector2.ZERO
var speed: float = 1500.0
var is_active: bool = true
var launched: bool = false

# Trail beam
var trail_start: Vector2 = Vector2.ZERO
var beam_points: Array = []

func _ready():
	add_to_group("balls")
	$CollisionShape2D.disabled = true
	queue_redraw()
func _draw():
	# Bright core
	draw_circle(Vector2.ZERO, 4, Color(1, 1, 1, 0.9))
	# Cyan glow
	draw_circle(Vector2.ZERO, 7, Color(0.3, 0.9, 1.0, 0.5))
	# Outer glow
	draw_circle(Vector2.ZERO, 11, Color(0.2, 0.7, 1.0, 0.15))

func _physics_process(delta):
	if not launched or not is_active:
		return

	var move_amount = direction * speed * delta
	position += move_amount
	# Record beam path
	beam_points.append(position)

	# Check all bricks for hit
	var manager = get_tree().get_first_node_in_group("game_manager")
	if not manager:
		return

	for brick in manager.brick_container.get_children():
		if not is_instance_valid(brick):
			continue
		if brick.has_meta("railgun_hit"):
			continue
		var dist = position.distance_to(brick.position)
		var hit_radius = 30.0
		if brick.has_method("update_size"):
			hit_radius = max(brick.grid_width, brick.grid_height) * 26.0
		if dist < hit_radius:
			brick.set_meta("railgun_hit", true)

			# Calculate actual hit point on the brick (closest point on our line to brick center)
			var to_brick = brick.position - position
			var proj = to_brick.dot(direction)
			var hit_point = position + direction * proj

			if brick.has_method("update_size"):
				var dmg = max(1, int(brick.health / 2.0))
				brick.take_damage(dmg)
				spawn_tunnel_hole(manager, hit_point)
				spawn_purple_spray(manager, hit_point)
			else:
				# Normal brick: mark for delayed railgun death if supported
				if "railgun_death" in brick:
					brick.railgun_death = true
					brick.railgun_direction = direction
					brick.railgun_hit_offset = hit_point - brick.position
					manager.railgun_deaths_pending += 1
				brick.take_damage(brick.health)
				spawn_purple_spray(manager, hit_point)

			spawn_tunnel_hole(manager, hit_point)

	# Despawn off screen
	if position.y > 600 or position.y < 40 or position.x < -20 or position.x > 410:
		is_active = false
		# Spawn the full beam trail VFX
		spawn_beam_trail(manager)
		ball_landed.emit(position.x)
		ball_returned.emit()
		queue_free()

func launch(dir: Vector2):
	direction = dir
	launched = true
	trail_start = position

func spawn_tunnel_hole(manager, pos: Vector2):
	# Molten-edged tunnel hole at each brick
	var hole = Node2D.new()
	hole.position = pos
	manager.particle_container.add_child(hole)

	# Draw a persistent glowing hole that fades
	hole.draw.connect(func():
		# Molten edges
		hole.draw_circle(Vector2.ZERO, 6, Color(1.0, 0.5, 0.1, hole.modulate.a * 0.6))
		hole.draw_circle(Vector2.ZERO, 4, Color(1.0, 0.8, 0.3, hole.modulate.a * 0.8))
		# Dark center (the hole)
		hole.draw_circle(Vector2.ZERO, 2.5, Color(0.1, 0.05, 0.0, hole.modulate.a))
	)
	hole.queue_redraw()

	var tween = hole.create_tween()
	tween.tween_property(hole, "modulate:a", 0.0, 1.5).set_ease(Tween.EASE_IN)
	tween.tween_callback(hole.queue_free)

func spawn_purple_spray(manager, pos: Vector2):
	# Purple particle spray
	for i in range(8):
		var p = ColorRect.new()
		var s = randf_range(2, 5)
		p.size = Vector2(s, s)
		p.position = pos + Vector2(-s/2, -s/2)
		# Purple/violet colors
		p.color = [
			Color(0.6, 0.2, 0.9),
			Color(0.7, 0.3, 1.0),
			Color(0.5, 0.15, 0.8),
			Color(0.8, 0.4, 1.0),
		][randi() % 4]
		manager.particle_container.add_child(p)

		var angle = randf_range(0, TAU)
		var dist = randf_range(15, 40)
		var target_pos = p.position + Vector2(cos(angle) * dist, sin(angle) * dist)

		var tween = p.create_tween()
		tween.set_parallel(true)
		tween.tween_property(p, "position", target_pos, 0.3).set_ease(Tween.EASE_OUT)
		tween.tween_property(p, "modulate:a", 0.0, 0.3)
		tween.chain().tween_callback(p.queue_free)

	manager.add_shake(2.0)
func spawn_beam_trail(manager):
	if beam_points.size() < 2 or not manager:
		return

	# Draw a fading beam line along the path
	var beam = Line2D.new()
	beam.width = 4.0
	beam.default_color = Color(0.3, 0.9, 1.0, 0.7)
	for pt in beam_points:
		beam.add_point(pt)
	manager.particle_container.add_child(beam)

	# Also draw a wider glow beam
	var glow = Line2D.new()
	glow.width = 12.0
	glow.default_color = Color(0.2, 0.7, 1.0, 0.2)
	for pt in beam_points:
		glow.add_point(pt)
	manager.particle_container.add_child(glow)

	# Fade both out
	var tween = beam.create_tween()
	tween.set_parallel(true)
	tween.tween_property(beam, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN)
	tween.tween_property(glow, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(beam.queue_free)
	tween.chain().tween_callback(glow.queue_free)
