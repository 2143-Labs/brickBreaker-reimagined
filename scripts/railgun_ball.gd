extends CharacterBody2D

signal ball_returned(p_id: int)
signal ball_landed(x_pos: float, p_id: int)

var direction: Vector2 = Vector2.ZERO
var speed: float = 1500.0
var is_active: bool = true
var launched: bool = false
var player_id: int = 1

var beam_points: Array = []
var bounces_remaining: int = 0

# Wall bounds (match arena)
var wall_left: float = 13.0
var wall_right: float = 377.0
var wall_top: float = 80.0

func _ready():
	add_to_group("balls")
	$CollisionShape2D.disabled = true
	bounces_remaining = Progression.get_railgun_bounces()
	
	if MultiplayerManager.is_multiplayer:
		var sync = MultiplayerSynchronizer.new()
		sync.name = "BallSync"
		var config = SceneReplicationConfig.new()
		config.add_property(".:position")
		config.property_set_replication_mode(".:position", SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
		config.add_property(".:player_id")
		config.property_set_replication_mode(".:player_id", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
		sync.replication_config = config
		add_child(sync)
		if not is_multiplayer_authority():
			set_physics_process(false)
			
	queue_redraw()

func _draw():
	draw_circle(Vector2.ZERO, 4, Color(1, 1, 1, 0.9))
	var glow = Color(0.3, 0.9, 1.0, 0.5) if player_id == 1 else Color(0.9, 0.3, 1.0, 0.5)
	draw_circle(Vector2.ZERO, 7, glow)
	draw_circle(Vector2.ZERO, 11, Color(0.2, 0.7, 1.0, 0.15))

func _process(delta):
	if MultiplayerManager.is_multiplayer and not is_multiplayer_authority():
		beam_points.append(position)
		queue_redraw()

func _physics_process(delta):
	if not launched or not is_active:
		return
	var move_amount = direction * speed * delta
	var new_pos = position + move_amount

	# Check wall bounces before moving
	var bounced = false
	if bounces_remaining > 0:
		# Left wall
		if new_pos.x <= wall_left and direction.x < 0:
			direction.x = -direction.x
			new_pos.x = wall_left + 2
			bounces_remaining -= 1
			bounced = true
			spawn_wall_spark(Vector2(wall_left, new_pos.y))
		# Right wall
		elif new_pos.x >= wall_right and direction.x > 0:
			direction.x = -direction.x
			new_pos.x = wall_right - 2
			bounces_remaining -= 1
			bounced = true
			spawn_wall_spark(Vector2(wall_right, new_pos.y))
		# Top wall
		if new_pos.y <= wall_top and direction.y < 0:
			direction.y = -direction.y
			new_pos.y = wall_top + 2
			bounces_remaining -= 1
			bounced = true
			spawn_wall_spark(Vector2(new_pos.x, wall_top))

	position = new_pos
	beam_points.append(position)

	# Check brick hits
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

			# Strip armor if talent
			if Progression.has_railgun_armor_break() and brick.has_method("strip_armor"):
				brick.strip_armor()

			var hit_point = position
			var to_brick = brick.position - position
			var proj = to_brick.dot(direction)
			if proj > 0:
				hit_point = position + direction * proj

			if brick.has_method("update_size"):
				var dmg = max(1, int(brick.health / 2.0))
				brick.take_damage(dmg, direction, true)
				manager.spawn_tunnel_hole(hit_point)
				manager.spawn_purple_spray(hit_point)
			else:
				if "railgun_death" in brick:
					brick.railgun_death = true
					brick.railgun_direction = direction
					brick.railgun_hit_offset = hit_point - brick.position
					manager.railgun_deaths_pending += 1
				brick.take_damage(brick.health)
				manager.spawn_purple_spray(hit_point)

			manager.spawn_tunnel_hole(hit_point)

	# Despawn off screen (only if no bounces left or past bounds)
	if position.y > 600 or position.y < 40 or position.x < -20 or position.x > 410:
		is_active = false
		if manager:
			spawn_beam_trail(manager)
		ball_landed.emit(position.x, player_id)
		ball_returned.emit(player_id)
		queue_free()

func launch(dir: Vector2):
	direction = dir
	launched = true
	beam_points.append(position)

func spawn_wall_spark(pos: Vector2):
	var manager = get_tree().get_first_node_in_group("game_manager")
	if not manager: return
	# Electric spark at bounce point
	for i in range(6):
		var p = ColorRect.new()
		p.size = Vector2(3, 3)
		p.position = pos + Vector2(-1.5, -1.5)
		p.color = [Color(0.3, 0.9, 1.0), Color(0.5, 0.95, 1.0), Color(1, 1, 1)][randi() % 3]
		manager.particle_container.add_child(p)
		var angle = randf_range(0, TAU)
		var dist = randf_range(10, 25)
		var target = p.position + Vector2(cos(angle) * dist, sin(angle) * dist)
		var tween = p.create_tween()
		tween.set_parallel(true)
		tween.tween_property(p, "position", target, 0.2)
		tween.tween_property(p, "modulate:a", 0.0, 0.2)
		tween.chain().tween_callback(p.queue_free)
	manager.add_shake(1.5)

func spawn_beam_trail(manager):
	if beam_points.size() < 2 or not manager:
		return
	var beam = Line2D.new()
	beam.width = 4.0
	beam.default_color = Color(0.3, 0.9, 1.0, 0.7)
	for pt in beam_points:
		beam.add_point(pt)
	manager.particle_container.add_child(beam)
	var glow = Line2D.new()
	glow.width = 12.0
	glow.default_color = Color(0.2, 0.7, 1.0, 0.2)
	for pt in beam_points:
		glow.add_point(pt)
	manager.particle_container.add_child(glow)
	var tween = beam.create_tween()
	tween.set_parallel(true)
	tween.tween_property(beam, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_IN)
	tween.tween_property(glow, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(beam.queue_free)
	tween.chain().tween_callback(glow.queue_free)
