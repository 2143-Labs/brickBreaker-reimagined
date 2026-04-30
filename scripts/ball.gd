extends CharacterBody2D

signal ball_returned(p_id: int, ball_type: int)
signal ball_landed(x_pos: float, p_id: int)
var direction: Vector2 = Vector2.ZERO
var speed: float = 800.0
var damage: int = 1
var damage_multiplier: float = 1.0
var is_active: bool = true
var launched: bool = false
var is_powered: bool = false
var applies_burn: bool = false
var player_id: int = 1
var ball_type: int = BallType.NORMAL
var radius: int = 8
# Fire-type: track remaining brick burns (5 per launch).
var fire_burns_remaining: int = 0
# Iron-type: damage 2 instead of 1 (set in launch()).

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
	
	if MP.is_multiplayer:
		var sync = MultiplayerSynchronizer.new()
		sync.name = "BallSync"
		var config = SceneReplicationConfig.new()
		config.add_property(".:position")
		config.property_set_replication_mode(".:position", SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
		config.add_property(".:is_powered")
		config.property_set_replication_mode(".:is_powered", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
		config.add_property(".:applies_burn")
		config.property_set_replication_mode(".:applies_burn", SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
		config.add_property(".:player_id")
		config.property_set_replication_mode(".:player_id", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
		sync.replication_config = config
		add_child(sync)
		
		# Ensure visual updates when burn flag arrives
		sync.synchronized.connect(func(): queue_redraw())
		
		if not is_multiplayer_authority():
			set_physics_process(false)
			
	queue_redraw()

func get_ball_color() -> Color:
	if applies_burn:
		return Color(0.95, 0.55, 0.15)
	elif is_powered:
		return Color(0.85, 0.3, 0.25)
	elif ball_type != BallType.NORMAL:
		return BallType.color(ball_type)
	elif player_id == 2:
		return Color(0.95, 0.35, 0.4)
	else:
		return Progression.get_equipped_color_value() if get_node_or_null("/root/Progression") else Color(0.3, 0.55, 0.95)

func _draw():
	var r := float(radius)
	# Draw trail
	for i in range(trail_points.size()):
		var point = trail_points[i]
		var age_ratio = float(i) / max(trail_points.size(), 1)
		var alpha = age_ratio * 0.4
		var size = (r * 0.4) + age_ratio * (r * 0.5)
		var col = get_ball_color()
		col.a = alpha
		draw_circle(point - position, size, col)

	var fill := get_ball_color()
	if applies_burn or is_powered or ball_type != BallType.NORMAL:
		var halo_col := Color(fill.r, fill.g, fill.b, 0.25)
		draw_circle(Vector2.ZERO, r + 2.0, halo_col)
	draw_circle(Vector2.ZERO, r, fill)
	# Type-specific marker on top of the body for at-a-glance ID.
	_draw_type_marker(r)

func _draw_type_marker(r: float) -> void:
	match ball_type:
		BallType.IRON:
			# Bolt/cross to suggest metal.
			var c := Color(0.15, 0.18, 0.22, 0.8)
			draw_line(Vector2(-r * 0.5, 0), Vector2(r * 0.5, 0), c, 1.5)
			draw_line(Vector2(0, -r * 0.5), Vector2(0, r * 0.5), c, 1.5)
		BallType.FIRE:
			draw_circle(Vector2.ZERO, r * 0.45, Color(1.0, 0.85, 0.30, 0.9))
		BallType.UNPRED:
			# Two dots offset to suggest chaos.
			draw_circle(Vector2(-r * 0.3, -r * 0.2), r * 0.18, Color(0.15, 0.15, 0.25, 0.9))
			draw_circle(Vector2(r * 0.3, r * 0.2), r * 0.18, Color(0.15, 0.15, 0.25, 0.9))
		BallType.PIERCING:
			# Up-arrow.
			var c := Color(0.1, 0.3, 0.15, 0.9)
			draw_line(Vector2(0, r * 0.5), Vector2(0, -r * 0.5), c, 1.6)
			draw_line(Vector2(0, -r * 0.5), Vector2(-r * 0.35, -r * 0.15), c, 1.6)
			draw_line(Vector2(0, -r * 0.5), Vector2(r * 0.35, -r * 0.15), c, 1.6)
		BallType.PHYS:
			# Solid ring.
			draw_arc(Vector2.ZERO, r + 1.5, 0, TAU, 24, Color(0.15, 0.25, 0.30, 0.8), 1.5)
		BallType.DENSE:
			# Inward arrows.
			var c := Color(0.95, 0.85, 1.0, 0.9)
			draw_circle(Vector2.ZERO, r * 0.35, c)
		BallType.NEGATIVE:
			# Small ring (repels).
			draw_arc(Vector2.ZERO, r * 0.55, 0, TAU, 16, Color(1.0, 0.85, 0.95, 0.9), 1.4)
		BallType.SHOTGUN:
			# Tiny dot (the sub-balls themselves are smaller; this marker rarely appears).
			draw_circle(Vector2.ZERO, r * 0.4, Color(1, 1, 1, 0.7))

func _process(delta):
	if not is_multiplayer_authority():
		queue_redraw()
		if is_active:
			trail_timer += delta
			if trail_timer >= trail_interval:
				trail_timer = 0.0
				trail_points.append(position)
				if trail_points.size() > max_trail_points:
					trail_points.pop_front()
	if has_node("PointLight2D"):
		$PointLight2D.color = get_ball_color()
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


	if direction.y > 0:
		collision_mask = 1 | 2 # Detect Layer 1 AND Layer 2 (3)
	else:
		collision_mask = 1     # Only detect Layer 1 (pass through paddle)

	velocity = direction * speed
	var collision = move_and_collide(velocity * delta)

	if collision:
		var collider = collision.get_collider()
		var pre_pierce_dir := direction
		var pierced := false

		if ball_type == BallType.PIERCING and direction.y < -0.3 \
				and collider.has_method("take_damage") \
				and not collider.is_in_group("paddle"):
			pierced = _try_pierce(collider)

		if not pierced:
			direction = direction.bounce(collision.get_normal())

			if collider.is_in_group("paddle"):
				var diff = position.x - collider.global_position.x
				direction.x += diff * 0.02
				direction = direction.normalized()

			if collider.has_method("take_damage"):
				_hit_brick(collider, pre_pierce_dir)
			else:
				wall_bounce_count += 1
				last_wall_bounce_time = time_alive
				var manager = get_tree().get_first_node_in_group("game_manager")
				if manager and manager.sound_manager:
					manager.sound_manager.play_bounce()

			# Unpred: scramble bounce angle on every collision.
			if ball_type == BallType.UNPRED:
				direction = direction.rotated(randf_range(-PI / 3.0, PI / 3.0)).normalized()

	# Peer interactions: react to nearby Phys/Dense/Negative balls. Gated on
	# self having bounced at least once so balls don't interfere at the launcher.
	_process_peer_interactions(delta)

	# Stuck detection
	if time_alive - last_brick_hit_time > stuck_threshold and wall_bounce_count > 4:
		unstick()

	# Hard timeout force return if ball has been alive too long
	if time_alive > max_alive_time:
		is_active = false
		ball_landed.emit(position.x, player_id)
		ball_returned.emit(player_id, ball_type)
		queue_free()
		return

	queue_redraw()

	# Killbox: paddle line + escape detection. The arena is a 390x844 rect with
	# walls at x=0..10, x=380..390, and y=120..130. A ball whose center leaves
	# this rect has clipped through wall geometry — return it immediately
	# instead of waiting on the max_alive_time backstop.
	if position.y > 540 \
			or position.x < -10 or position.x > 400 \
			or position.y < -10:
		is_active = false
		ball_landed.emit(position.x, player_id)
		ball_returned.emit(player_id, ball_type)
		queue_free()

const PEER_RANGE: float = 80.0
const PEER_NUDGE_PER_SEC: float = 0.6

func _process_peer_interactions(delta: float) -> void:
	# A ball only feels Phys/Dense/Negative peers AFTER it has bounced once.
	if wall_bounce_count == 0:
		return
	for peer in get_tree().get_nodes_in_group("balls"):
		if peer == self or not is_instance_valid(peer):
			continue
		var peer_type: int = peer.get("ball_type") if "ball_type" in peer else BallType.NORMAL
		if peer_type != BallType.PHYS and peer_type != BallType.DENSE and peer_type != BallType.NEGATIVE:
			continue
		var to_peer: Vector2 = peer.position - position
		var dist: float = to_peer.length()
		if dist < 0.001:
			continue
		var dir_to_peer: Vector2 = to_peer / dist
		match peer_type:
			BallType.PHYS:
				var peer_radius: float = float(peer.get("radius")) if "radius" in peer else 8.0
				var combined_r: float = float(radius) + peer_radius
				if dist < combined_r and direction.dot(dir_to_peer) > 0.0:
					# Reflect direction off the line connecting our centers, then
					# push out of overlap so we don't stick.
					var normal: Vector2 = -dir_to_peer
					direction = direction.bounce(normal).normalized()
					position = peer.position - dir_to_peer * combined_r
			BallType.DENSE:
				if dist < PEER_RANGE:
					var falloff: float = 1.0 - dist / PEER_RANGE
					direction = (direction + dir_to_peer * (PEER_NUDGE_PER_SEC * falloff * delta)).normalized()
			BallType.NEGATIVE:
				if dist < PEER_RANGE:
					var falloff_n: float = 1.0 - dist / PEER_RANGE
					direction = (direction - dir_to_peer * (PEER_NUDGE_PER_SEC * falloff_n * delta)).normalized()

func _hit_brick(brick, hit_dir: Vector2):
	brick.take_damage(int(damage * damage_multiplier), hit_dir)
	var burns_this_hit := applies_burn
	if ball_type == BallType.FIRE and fire_burns_remaining > 0:
		burns_this_hit = true
		fire_burns_remaining -= 1
	if burns_this_hit and brick.has_method("add_burn_stack"):
		brick.add_burn_stack()
	last_brick_hit_time = time_alive
	wall_bounce_count = 0
	var manager = get_tree().get_first_node_in_group("game_manager")
	if manager and manager.sound_manager:
		manager.sound_manager.play_hit()
		manager.on_brick_hit()

func _try_pierce(hit_brick) -> bool:
	# Pierce up to 2 bricks if a free cell exists behind them. Armored bricks
	# can be passed through but are not damaged.
	var manager = get_tree().get_first_node_in_group("game_manager")
	if not manager:
		return false
	var brick_col: int = int(round((hit_brick.position.x - manager.grid_start_x) / manager.cell_width))
	var brick_row: int = int(round((hit_brick.position.y - manager.grid_start_y) / manager.cell_height))
	var occupied: Array = manager.get_occupied_cells()

	# 1-brick pierce: cell directly above the hit brick is free.
	if Vector2(brick_col, brick_row - 1) not in occupied:
		_pierce_brick(hit_brick)
		position = Vector2(
			manager.grid_start_x + brick_col * manager.cell_width,
			manager.grid_start_y + (brick_row - 1) * manager.cell_height
		)
		return true

	# 2-brick pierce: cell two rows above is free.
	if Vector2(brick_col, brick_row - 2) not in occupied:
		var second_brick = _find_brick_at_cell(manager, brick_col, brick_row - 1)
		_pierce_brick(hit_brick)
		if second_brick:
			_pierce_brick(second_brick)
		position = Vector2(
			manager.grid_start_x + brick_col * manager.cell_width,
			manager.grid_start_y + (brick_row - 2) * manager.cell_height
		)
		return true

	return false

func _pierce_brick(brick):
	# Armored bricks are pierced but immune to the pierce damage.
	var is_armored: bool = brick.get("armored") == true
	if is_armored:
		return
	if brick.has_method("take_damage"):
		brick.take_damage(int(damage * damage_multiplier), direction)
		if applies_burn and brick.has_method("add_burn_stack"):
			brick.add_burn_stack()
		last_brick_hit_time = time_alive
		var manager = get_tree().get_first_node_in_group("game_manager")
		if manager and manager.sound_manager:
			manager.sound_manager.play_hit()
			manager.on_brick_hit()

func _find_brick_at_cell(manager, col: int, row: int):
	for b in manager.brick_container.get_children():
		if not b is Node2D:
			continue
		var bc: int = int(round((b.position.x - manager.grid_start_x) / manager.cell_width))
		var br: int = int(round((b.position.y - manager.grid_start_y) / manager.cell_height))
		if bc == col and br == row:
			return b
	return null

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
	if ball_type == BallType.IRON:
		damage = 2
	elif ball_type == BallType.FIRE:
		fire_burns_remaining = 5
	# Resize collision shape per ball; create a fresh CircleShape2D so we don't
	# mutate the shared resource on the ball.tscn.
	if has_node("CollisionShape2D"):
		var shape := CircleShape2D.new()
		shape.radius = float(radius)
		$CollisionShape2D.shape = shape
