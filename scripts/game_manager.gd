extends Node2D

const BRICK_SCENE = preload("res://scenes/brick.tscn")
const BALL_SCENE = preload("res://scenes/ball.tscn")
const AMMO_ORB_SCENE = preload("res://scenes/ammo_orb.tscn")
const EXPLOSIVE_BALL_SCENE = preload("res://scenes/explosive_ball.tscn")
const SAVE_PATH = "user://highscore.save"

@onready var brick_container = $BrickContainer
@onready var ball_container = $BallContainer
@onready var aim_line = $AimLine
@onready var trajectory_preview = $TrajectoryPreview
@onready var ammo_label = $HUD/AmmoLabel
@onready var round_label = $HUD/RoundLabel
@onready var score_label = $HUD/ScoreLabel
@onready var high_score_label = $HUD/HighScoreLabel
@onready var orb_container = $OrbContainer
@onready var speed_button = $HUD/SpeedButton
@onready var restart_button = $HUD/RestartButton
@onready var game_over_label = $HUD/GameOverLabel
@onready var final_score_label = $HUD/FinalScoreLabel
@onready var particle_container = $ParticleContainer
@onready var magazine = $Magazine
@onready var sound_manager = $SoundManager
@onready var explosive_button = $HUD/PowerupBar/ExplosiveButton
@onready var explosive_cooldown_label = $HUD/PowerupBar/ExplosiveCooldown

var current_round: int = 1
var score: int = 0
var high_score: int = 0
var ammo: int = 1
var bonus_ammo: int = 0
var pending_ammo: int = 0
var is_aiming: bool = false
var is_firing: bool = false
var fire_direction: Vector2
var balls_in_play: int = 0
var preview_ball: Node2D = null
var game_active: bool = true
var first_ball_returned: bool = false
var next_launch_x: float = 195.0

var is_spawning: bool = false
var balls_to_spawn: int = 0
var spawn_distance_accumulator: float = 0.0
var ball_spacing: float = 20.0

var speed_levels = [1.0, 2.0, 4.0]
var current_speed_idx: int = 0

var arena_left: float = 13.0
var arena_right: float = 377.0
var arena_top: float = 80.0

var grid_cols: int = 7
var cell_width: float = 52.0
var cell_height: float = 38.0
var max_rows: int = 10

var grid_start_x: float
var grid_start_y: float
var arena_bottom: float
var launch_point: Vector2

var is_sliding: bool = false
var slide_progress: float = 0.0
var slide_duration: float = 0.2

var is_dropping: bool = false
var drop_progress: float = 0.0
var drop_duration: float = 0.25
var dropping_bricks: Array = []
var dropping_orbs: Array = []

var death_row: int = 9

var shake_amount: float = 0.0
var shake_decay: float = 8.0
var original_position: Vector2 = Vector2.ZERO

# Explosive powerup
var explosive_active: bool = false
var explosive_cooldown: int = 0
var explosive_cooldown_max: int = 4
func _ready():
	add_to_group("game_manager")
	grid_start_x = arena_left + cell_width / 2.0
	grid_start_y = arena_top + cell_height / 2.0
	arena_bottom = arena_top + max_rows * cell_height
	launch_point = Vector2(195, arena_bottom + 20)
	original_position = position

	speed_button.pressed.connect(_on_speed_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	explosive_button.pressed.connect(_on_explosive_pressed)

	load_high_score()

	magazine.position = Vector2(0, launch_point.y + 25)
	magazine.pipe_left = arena_left
	magazine.pipe_right = arena_right
	magazine.entrance_x = launch_point.x
	magazine.set_ammo(ammo + bonus_ammo)

	spawn_round_bricks()
	spawn_ammo_orbs()

	is_sliding = true
	slide_progress = 0.0
	for brick in brick_container.get_children():
		brick.set_meta("slide_from", brick.position.y)
		brick.set_meta("slide_to", brick.position.y + cell_height)
		brick.set_meta("first_round", true)
	for orb in orb_container.get_children():
		orb.set_meta("slide_from", orb.position.y)
		orb.set_meta("slide_to", orb.position.y + cell_height)
		orb.set_meta("first_round", true)

	update_hud()
	update_ammo_label_position()
	update_explosive_ui()
	create_preview_ball()
	queue_redraw()

func _draw():
	var border_color = Color(1, 1, 1, 0.9)
	var thickness = 2.0
	draw_line(Vector2(arena_left, arena_top), Vector2(arena_left, arena_bottom), border_color, thickness)
	draw_line(Vector2(arena_right, arena_top), Vector2(arena_right, arena_bottom), border_color, thickness)
	draw_line(Vector2(arena_left, arena_top), Vector2(arena_right, arena_top), border_color, thickness)
	draw_line(Vector2(arena_left, arena_bottom), Vector2(arena_right, arena_bottom), border_color, thickness)

func _physics_process(delta):
	if shake_amount > 0.1:
		shake_amount = lerp(shake_amount, 0.0, shake_decay * delta)
		position = original_position + Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)
	elif shake_amount > 0:
		shake_amount = 0.0
		position = original_position

	if is_spawning and balls_to_spawn > 0:
		spawn_distance_accumulator += 800.0 * delta
		while spawn_distance_accumulator >= ball_spacing and balls_to_spawn > 0:
			spawn_distance_accumulator -= ball_spacing
			do_launch_ball()
			balls_to_spawn -= 1
			if balls_to_spawn <= 0:
				is_spawning = false

	if is_sliding:
		slide_progress += delta / slide_duration
		if slide_progress >= 1.0:
			slide_progress = 1.0
			is_sliding = false
			finish_slide()
		var t = ease_out_cubic(slide_progress)
		for brick in brick_container.get_children():
			if brick.has_meta("slide_from") and brick.has_meta("slide_to"):
				brick.position.y = lerp(float(brick.get_meta("slide_from")), float(brick.get_meta("slide_to")), t)
		for orb in orb_container.get_children():
			if orb.has_meta("slide_from") and orb.has_meta("slide_to"):
				orb.position.y = lerp(float(orb.get_meta("slide_from")), float(orb.get_meta("slide_to")), t)

	if is_dropping:
		drop_progress += delta / drop_duration
		if drop_progress >= 1.0:
			drop_progress = 1.0
			is_dropping = false
			finish_drop()
		var t = drop_progress * drop_progress
		for item in dropping_bricks:
			if is_instance_valid(item["brick"]):
				item["brick"].position.y = lerp(float(item["from_y"]), float(item["to_y"]), t)
		for item in dropping_orbs:
			if is_instance_valid(item["orb"]):
				item["orb"].position.y = lerp(float(item["from_y"]), float(item["to_y"]), t)

func ease_out_cubic(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3)

func add_shake(amount: float):
	shake_amount = max(shake_amount, amount)

func _on_speed_pressed():
	current_speed_idx = (current_speed_idx + 1) % speed_levels.size()
	var spd = speed_levels[current_speed_idx]
	Engine.time_scale = spd
	speed_button.text = "%dx" % int(spd)

func _on_restart_pressed():
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()

func _on_explosive_pressed():
	if explosive_cooldown > 0 or is_firing or not game_active:
		return
	explosive_active = !explosive_active
	update_explosive_ui()
	if explosive_active:
		sound_manager.play_powerup()
func update_explosive_ui():
	if explosive_cooldown > 0:
		explosive_button.disabled = true
		explosive_button.modulate = Color(0.5, 0.5, 0.5)
		explosive_cooldown_label.text = "%d rounds" % explosive_cooldown
		explosive_cooldown_label.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
	elif explosive_active:
		explosive_button.disabled = false
		explosive_button.modulate = Color(1.0, 0.7, 0.3)
		explosive_cooldown_label.text = "ARMED"
		explosive_cooldown_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.15))
	else:
		explosive_button.disabled = false
		explosive_button.modulate = Color(1, 1, 1)
		explosive_cooldown_label.text = "Ready"
		explosive_cooldown_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))

func create_preview_ball():
	if preview_ball:
		preview_ball.queue_free()
	preview_ball = Node2D.new()
	preview_ball.position = launch_point
	add_child(preview_ball)
	var color = Color(1.0, 0.5, 0.15, 0.9) if explosive_active else Color(0.3, 0.55, 0.95, 0.9)
	var c = color  # capture for lambda
	preview_ball.draw.connect(func():
		if explosive_active:
			preview_ball.draw_circle(Vector2.ZERO, 10, Color(1.0, 0.4, 0.1, 0.3))
			preview_ball.draw_circle(Vector2.ZERO, 8, Color(1.0, 0.5, 0.15, 0.9))
		else:
			preview_ball.draw_circle(Vector2.ZERO, 8, Color(0.3, 0.55, 0.95, 0.9))
	)
	preview_ball.queue_redraw()

func update_ammo_label_position():
	ammo_label.offset_left = launch_point.x + 15
	ammo_label.offset_right = launch_point.x + 75
	ammo_label.offset_top = launch_point.y - 10
	ammo_label.offset_bottom = launch_point.y + 15
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

func _input(event):
	if is_firing or not game_active or is_sliding or is_dropping:
		return
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		var pressed = event.pressed
		if pressed:
			is_aiming = true
		elif is_aiming:
			is_aiming = false
			var aim_pos = event.position if event is InputEventMouseButton else event.position
			fire_direction = (aim_pos - launch_point).normalized()
			if fire_direction.y < -0.1:
				start_firing()
			aim_line.clear_points()
			trajectory_preview.clear_points()

	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		if is_aiming:
			var aim_pos = event.position if event is InputEventMouseMotion else event.position
			update_aim_line(aim_pos)

func update_aim_line(target: Vector2):
	var direction = (target - launch_point).normalized()
	if direction.y >= -0.1:
		aim_line.clear_points()
		trajectory_preview.clear_points()
		return

	# Raycast to find first bounce
	aim_line.clear_points()
	trajectory_preview.clear_points()

	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		launch_point + direction * 2,
		launch_point + direction * 800
	)
	query.collision_mask = 1
	var result = space_state.intersect_ray(query)

	if result:
		# Main line: launch to first hit
		aim_line.add_point(launch_point)
		aim_line.add_point(result.position)

		# Bounce preview: thinner, from hit point onward
		var bounce_dir = direction.bounce(result.normal)
		trajectory_preview.add_point(result.position)
		trajectory_preview.add_point(result.position + bounce_dir * 150)
	else:
		# No hit found, just draw straight
		aim_line.add_point(launch_point)
		aim_line.add_point(launch_point + direction * 800)



func start_firing():
	is_firing = true
	balls_in_play = 0
	first_ball_returned = false
	pending_ammo = 0
	if preview_ball:
		preview_ball.visible = false
	ammo_label.visible = false
	aim_line.clear_points()
	trajectory_preview.clear_points()

	balls_to_spawn = ammo + bonus_ammo

	# If explosive is armed, first ball is explosive
	if explosive_active:
		var ball = EXPLOSIVE_BALL_SCENE.instantiate()
		ball.position = launch_point
		ball.speed = 800.0
		ball.ball_returned.connect(_on_ball_returned)
		ball.ball_landed.connect(_on_ball_landed)
		ball_container.add_child(ball)
		ball.launch(fire_direction)
		balls_in_play += 1
		magazine.fire_ball()
		balls_to_spawn -= 1
		explosive_active = false
		explosive_cooldown = explosive_cooldown_max
		update_explosive_ui()

	if balls_to_spawn > 0:
		spawn_distance_accumulator = ball_spacing
		is_spawning = true
	elif balls_in_play == 0:
		end_round()

func do_launch_ball():
	var ball = BALL_SCENE.instantiate()
	ball.position = launch_point
	ball.speed = 800.0
	ball.ball_returned.connect(_on_ball_returned)
	ball.ball_landed.connect(_on_ball_landed)
	ball_container.add_child(ball)
	ball.launch(fire_direction)
	balls_in_play += 1
	magazine.fire_ball()

func do_explosion(center: Vector2, radius: float):
	sound_manager.play_explode()
	add_shake(8.0)
	spawn_explosion_vfx(center, radius)

	var ball_count = ammo + bonus_ammo
	var inner_radius = radius * 0.4
	var outer_radius = radius

	# Damage scaling: min 10, after round 10 scales with ball count
	var direct_damage = max(10, int(5.0 * ball_count)) if current_round > 10 else 10
	var inner_damage = max(5, int(2.5 * ball_count)) if current_round > 10 else 5
	var outer_damage = max(2, int(0.5 * ball_count)) if current_round > 10 else 2
	for brick in brick_container.get_children():
		var dist = center.distance_to(brick.position)
		if dist < 1.0:
			# Direct hit
			brick.take_damage(direct_damage)
			brick.apply_explosion_crack(0)
		elif dist <= inner_radius:
			# Inner ring
			brick.take_damage(inner_damage)
			brick.apply_explosion_crack(1)
		elif dist <= outer_radius:
			# Outer ring
			brick.take_damage(outer_damage)
			brick.apply_explosion_crack(2)

func spawn_explosion_vfx(center: Vector2, radius: float):
	var explosion = Node2D.new()
	explosion.position = center
	particle_container.add_child(explosion)

	# Expanding ring
	var ring = Node2D.new()
	explosion.add_child(ring)
	ring.draw.connect(func():
		ring.draw_arc(Vector2.ZERO, ring.scale.x * radius * 0.5, 0, TAU, 32, Color(1.0, 0.5, 0.1, ring.modulate.a), 3.0)
	)
	ring.queue_redraw()
	var ring_tween = ring.create_tween()
	ring_tween.set_parallel(true)
	ring_tween.tween_property(ring, "scale", Vector2(2.0, 2.0), 0.3).from(Vector2(0.2, 0.2))
	ring_tween.tween_property(ring, "modulate:a", 0.0, 0.3)
	# Burst particles
	for i in range(16):
		var p = ColorRect.new()
		var s = randf_range(3, 8)
		p.size = Vector2(s, s)
		p.position = Vector2(-s/2, -s/2)
		p.color = [Color(1.0, 0.5, 0.1), Color(1.0, 0.8, 0.2), Color(1.0, 0.3, 0.1)][randi() % 3]
		explosion.add_child(p)

		var angle = (TAU / 16.0) * i + randf_range(-0.2, 0.2)
		var dist = randf_range(30, radius)
		var target_pos = Vector2(cos(angle) * dist, sin(angle) * dist)

		var tween = p.create_tween()
		tween.set_parallel(true)
		tween.tween_property(p, "position", target_pos, 0.35).set_ease(Tween.EASE_OUT)
		tween.tween_property(p, "modulate:a", 0.0, 0.35)
		tween.chain().tween_callback(p.queue_free)

	get_tree().create_timer(0.5).timeout.connect(func():
		if is_instance_valid(explosion):
			explosion.queue_free()
	)

func _on_ball_landed(x_pos: float):
	if not first_ball_returned:
		first_ball_returned = true
		next_launch_x = clamp(x_pos, arena_left + 15, arena_right - 15)
		magazine.shift_entrance_to(next_launch_x)
func _on_ball_returned():
	balls_in_play -= 1
	magazine.return_ball()
	if balls_in_play <= 0 and not is_spawning:
		end_round()

func end_round():
	is_firing = false
	current_round += 1
	launch_point.x = next_launch_x

	# Tick cooldowns
	if explosive_cooldown > 0:
		explosive_cooldown -= 1
	update_explosive_ui()
	if pending_ammo > 0:
		for i in range(pending_ammo):
			magazine.add_ball_plop()
		bonus_ammo += pending_ammo
		spawn_ammo_popup(pending_ammo)
		pending_ammo = 0

	# Refresh preview ball (in case explosive toggled)
	create_preview_ball()
	if preview_ball:
		preview_ball.visible = false

	start_slide_existing()
func start_slide_existing():
	is_sliding = true
	slide_progress = 0.0
	for brick in brick_container.get_children():
		brick.set_meta("slide_from", brick.position.y)
		brick.set_meta("slide_to", brick.position.y + cell_height)
	for orb in orb_container.get_children():
		orb.set_meta("slide_from", orb.position.y)
		orb.set_meta("slide_to", orb.position.y + cell_height)

func finish_slide():
	for brick in brick_container.get_children():
		brick.remove_meta("slide_from")
		brick.remove_meta("slide_to")
		var row = round((brick.position.y - grid_start_y) / cell_height)
		if row >= death_row:
			game_over()
			return

	for orb in orb_container.get_children():
		orb.remove_meta("slide_from")
		orb.remove_meta("slide_to")
		if orb.position.y > arena_bottom:
			orb.queue_free()

	var is_first = false
	for brick in brick_container.get_children():
		if brick.has_meta("first_round"):
			brick.remove_meta("first_round")
			is_first = true
	for orb in orb_container.get_children():
		if orb.has_meta("first_round"):
			orb.remove_meta("first_round")

	if is_first:
		after_drop_complete()
	else:
		spawn_and_drop()

func spawn_and_drop():
	var occupied_at_row2 = {}
	for brick in brick_container.get_children():
		var row = round((brick.position.y - grid_start_y) / cell_height)
		var col = round((brick.position.x - grid_start_x) / cell_width)
		if row == 2:
			occupied_at_row2[col] = true

	var new_bricks = spawn_round_bricks_at_row0()
	var new_orbs = spawn_ammo_orbs_at_row0()

	dropping_bricks.clear()
	dropping_orbs.clear()

	var row0_y = grid_start_y
	var row1_y = grid_start_y + cell_height

	for brick in new_bricks:
		var col = round((brick.position.x - grid_start_x) / cell_width)
		var has_below = occupied_at_row2.has(col)
		dropping_bricks.append({
			"brick": brick,
			"from_y": row0_y,
			"to_y": row1_y,
			"has_neighbor_below": has_below
		})

	for orb in new_orbs:
		var col = round((orb.position.x - grid_start_x) / cell_width)
		var has_below = occupied_at_row2.has(col)
		dropping_orbs.append({
			"orb": orb,
			"from_y": row0_y,
			"to_y": row1_y,
			"has_neighbor_below": has_below
		})
	if dropping_bricks.size() > 0 or dropping_orbs.size() > 0:
		is_dropping = true
		drop_progress = 0.0
	else:
		after_drop_complete()

func finish_drop():
	for item in dropping_bricks:
		if is_instance_valid(item["brick"]):
			item["brick"].position.y = item["to_y"]
			if item["has_neighbor_below"]:
				spawn_dust(Vector2(item["brick"].position.x, item["to_y"] + 18))

	for item in dropping_orbs:
		if is_instance_valid(item["orb"]):
			item["orb"].position.y = item["to_y"]

	dropping_bricks.clear()
	dropping_orbs.clear()
	after_drop_complete()

func after_drop_complete():
	update_hud()
	update_ammo_label_position()
	ammo_label.visible = true

	if preview_ball:
		preview_ball.position = launch_point
		preview_ball.visible = true
func spawn_dust(pos: Vector2):
	var dust = Node2D.new()
	dust.position = pos
	particle_container.add_child(dust)

	for i in range(6):
		var p = ColorRect.new()
		var s = randf_range(2, 5)
		p.size = Vector2(s, s)
		p.position = Vector2(-s/2, -s/2)
		p.color = Color(0.75, 0.72, 0.68, 0.7)
		dust.add_child(p)

		var angle = randf_range(-0.4, 0.4) + (PI if i % 2 == 0 else 0)
		var dist = randf_range(8, 22)
		var target_pos = Vector2(cos(angle) * dist, -randf_range(2, 8))

		var tween = p.create_tween()
		tween.set_parallel(true)
		tween.tween_property(p, "position", target_pos, 0.25).set_ease(Tween.EASE_OUT)
		tween.tween_property(p, "modulate:a", 0.0, 0.25)
		tween.chain().tween_callback(p.queue_free)

	get_tree().create_timer(0.3).timeout.connect(func():
		if is_instance_valid(dust):
			dust.queue_free()
	)

func spawn_round_bricks_at_row0() -> Array:
	var spawned = []
	if not game_active:
		return spawned
	var brick_count = randi_range(2, 5)
	var columns = []
	while columns.size() < brick_count:
		var col = randi_range(0, grid_cols - 1)
		if col not in columns:
			columns.append(col)
	for col in columns:
		var brick = BRICK_SCENE.instantiate()
		brick.position = Vector2(grid_start_x + col * cell_width, grid_start_y)
		brick.health = current_round
		brick.max_health = current_round
		brick_container.add_child(brick)
		spawned.append(brick)
	return spawned

func spawn_ammo_orbs_at_row0() -> Array:
	var spawned = []
	if not game_active:
		return spawned
	var occupied = get_occupied_cells()
	var available = []
	for c in range(grid_cols):
		if Vector2(c, 0) not in occupied:
			available.append(c)
	if available.size() > 0:
		var col = available[randi() % available.size()]
		var orb = AMMO_ORB_SCENE.instantiate()
		orb.position = Vector2(grid_start_x + col * cell_width, grid_start_y)
		orb_container.add_child(orb)
		spawned.append(orb)
	return spawned

func spawn_round_bricks():
	spawn_round_bricks_at_row0()

func spawn_ammo_orbs():
	spawn_ammo_orbs_at_row0()

func spawn_ammo_popup(count: int):
	var tier = min(count, 5)
	var label = Label.new()
	label.text = "+%d" % count
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(launch_point.x - 40, launch_point.y - 30)
	var sizes = [16, 22, 28, 36, 44]
	label.add_theme_font_size_override("font_size", sizes[tier - 1])
	var colors = [
		Color(0.4, 0.8, 0.5), Color(0.3, 0.9, 0.4),
		Color(0.95, 0.8, 0.2), Color(1.0, 0.5, 0.15), Color(1.0, 0.2, 0.3),
	]
	label.add_theme_color_override("font_color", colors[tier - 1])
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)
	var float_dist = 40.0 + tier * 10.0
	var duration = 1.0 + tier * 0.15
	var tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - float_dist, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(label, "modulate:a", 0.0, duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	if tier >= 3:
		label.scale = Vector2(1.3, 1.3)
		tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(label.queue_free)

func game_over():
	game_active = false
	is_firing = true
	Engine.time_scale = 1.0
	if score > high_score:
		high_score = score
		save_high_score()
	game_over_label.visible = true
	final_score_label.text = "Score: %d  |  Round %d" % [score, current_round]
	final_score_label.visible = true
	restart_button.visible = true
	ammo_label.visible = false

func add_score(points: int):
	score += points
	update_score_display()

func update_score_display():
	score_label.text = str(score)
	if score >= 1000:
		score_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.3))
	elif score >= 500:
		score_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.15))
	elif score >= 200:
		score_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.2))
	elif score >= 100:
		score_label.add_theme_color_override("font_color", Color(0.6, 0.4, 0.9))
	elif score >= 50:
		score_label.add_theme_color_override("font_color", Color(0.3, 0.55, 0.95))
	elif score >= 20:
		score_label.add_theme_color_override("font_color", Color(0.3, 0.85, 0.5))
	else:
		score_label.add_theme_color_override("font_color", Color(1, 1, 1))

func get_occupied_cells() -> Array:
	var occupied = []
	for brick in brick_container.get_children():
		var col = round((brick.position.x - grid_start_x) / cell_width)
		var row = round((brick.position.y - grid_start_y) / cell_height)
		occupied.append(Vector2(col, row))
	for orb in orb_container.get_children():
		var col = round((orb.position.x - grid_start_x) / cell_width)
		var row = round((orb.position.y - grid_start_y) / cell_height)
		occupied.append(Vector2(col, row))
	return occupied

func update_hud():
	ammo_label.text = "x%d" % (ammo + bonus_ammo)
	round_label.text = "Round %d" % current_round
	high_score_label.text = "Best: %d" % high_score
	update_score_display()
func collect_ammo_orb():
	pending_ammo += 1
	sound_manager.play_orb()

func save_high_score():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(high_score)
		file.close()

func load_high_score():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			high_score = file.get_var()
			file.close()

func spawn_brick_particles(pos: Vector2, color: Color):
	add_shake(3.0)
	sound_manager.play_destroy()
	var particles = Node2D.new()
	particles.position = pos
	particle_container.add_child(particles)
	for i in range(8):
		var p = ColorRect.new()
		var s = randf_range(3, 7)
		p.size = Vector2(s, s)
		p.position = Vector2(-s/2, -s/2)
		p.color = color
		particles.add_child(p)
		var angle = (TAU / 8.0) * i + randf_range(-0.3, 0.3)
		var dist = randf_range(20, 50)
		var target_pos = Vector2(cos(angle) * dist, sin(angle) * dist)
		var tween = p.create_tween()
		tween.set_parallel(true)
		tween.tween_property(p, "position", target_pos, 0.3).set_ease(Tween.EASE_OUT)
		tween.tween_property(p, "modulate:a", 0.0, 0.3)
		tween.chain().tween_callback(p.queue_free)
	get_tree().create_timer(0.4).timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)
