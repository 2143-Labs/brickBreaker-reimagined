extends Node2D

@export var player_id: int = 1
@export var synced_aim_dir: Vector2 = Vector2.DOWN

@onready var launcher = $Launcher
@onready var magazine = $Magazine
@onready var aim_line = $AimLine
@onready var trajectory_preview = $TrajectoryPreview
@onready var preview_ball = $PreviewBall

var game_manager: Node2D
var ball_container: Node2D
var ammo_label: Label

var arena_left: float
var arena_right: float

var launch_point: Vector2
var next_launch_x: float

var has_fired: bool = false
var first_ball_returned: bool = false

var is_spawning: bool = false
var balls_to_spawn: int = 0
var fire_dir: Vector2

var current_powerup: int = 0
var damage_multiplier: float = 1.0
var applies_burn: bool = false
var is_powered: bool = false

var _last_drawn_dir: Vector2 = Vector2.DOWN

func _ready():
	launcher.player_id = player_id
	magazine.player_id = player_id
	
	# Visibility rules for Co-Op
	if MultiplayerManager.is_multiplayer:
		var am_server = multiplayer.is_server()
		# Only show magazine for the local player's gun
		if (player_id == 1 and not am_server) or (player_id == 2 and am_server):
			magazine.visible = false
			if ammo_label:
				ammo_label.visible = false
	
	_setup_preview_draw()

func setup():
	position = Vector2.ZERO
	launcher.position = launch_point
	magazine.position = Vector2(0, launch_point.y + 25)
	magazine.entrance_x = launch_point.x
	magazine.target_entrance_x = launch_point.x
	magazine.build_tube_path()
	preview_ball.position = launch_point

func _process(_delta):
	# Automatically draw the aim line if the synced direction changes
	if synced_aim_dir != _last_drawn_dir:
		_draw_aim_line(synced_aim_dir)
		_last_drawn_dir = synced_aim_dir

func _physics_process(_delta):
	if is_spawning and balls_to_spawn > 0:
		if can_spawn_ball():
			do_launch_ball(fire_dir)
			balls_to_spawn -= 1
			if balls_to_spawn <= 0:
				is_spawning = false

func can_spawn_ball() -> bool:
	if ball_container and ball_container.get_child_count() > 0:
		for ball in ball_container.get_children():
			if ball.get("player_id") == player_id and is_instance_valid(ball):
				if ball.position.distance_to(launch_point) < 1.0:
					return false
	return true

func do_launch_ball(dir: Vector2):
	if game_manager and game_manager.sound_manager:
		game_manager.sound_manager.play("launch")

	var ball = preload("res://scenes/ball.tscn").instantiate()
	ball.player_id = player_id
	ball.position = launch_point
	ball.speed = 800.0
	ball.damage_multiplier = damage_multiplier
	ball.is_powered = is_powered
	ball.applies_burn = applies_burn
	ball.ball_returned.connect(func(pid): handle_ball_returned(pid))
	ball.ball_landed.connect(func(x, pid): handle_ball_landed(x, pid))
	ball_container.add_child(ball, true)
	ball.launch(dir)
	
	if MultiplayerManager.is_multiplayer and multiplayer.is_server():
		sync_magazine_fire.rpc()
	else:
		sync_magazine_fire()

@rpc("authority", "call_local", "reliable")
func start_firing_rpc(dir: Vector2, total_ammo: int, p_type: int, dmg_mult: float, burn_active: bool, is_pow: bool = false):
	has_fired = true
	first_ball_returned = false
	
	preview_ball.visible = false
	if ammo_label and (not MultiplayerManager.is_multiplayer or (player_id == 1 and multiplayer.is_server()) or (player_id == 2 and not multiplayer.is_server())):
		ammo_label.visible = false
		
	synced_aim_dir = Vector2.DOWN # Clears aim
	launcher.clear_aim()

	damage_multiplier = dmg_mult
	applies_burn = burn_active
	is_powered = is_pow
	update_powerup_state(p_type, is_powered)

	# Only the server physically spawns the balls and progresses the spawning state loop
	if not MultiplayerManager.is_multiplayer or multiplayer.is_server():
		fire_dir = dir
		balls_to_spawn = total_ammo
		is_spawning = (balls_to_spawn > 0)
		
		if p_type != 0 and p_type != 3: # 3 is BURN, which just applies to all regular balls
			var special_scene = null
			if p_type == 1: special_scene = preload("res://scenes/explosive_ball.tscn")
			elif p_type == 2: special_scene = preload("res://scenes/railgun_ball.tscn")
			
			if special_scene:
				var ball = special_scene.instantiate()
				ball.player_id = player_id
				ball.position = launch_point
				ball.speed = 800.0 if p_type != 2 else 1500.0
				ball.ball_returned.connect(func(pid): handle_ball_returned(pid))
				ball.ball_landed.connect(func(x, pid): handle_ball_landed(x, pid))
				ball_container.add_child(ball, true)
				ball.launch(dir)
				
				if p_type == 2: # RAILGUN
					if game_manager:
						game_manager.sound_manager.play_railgun()
						game_manager.railgun_active = true
					for i in range(balls_to_spawn): 
						if MultiplayerManager.is_multiplayer: sync_magazine_fire.rpc()
						else: sync_magazine_fire()
					balls_to_spawn = 0
					is_spawning = false
				else: # EXPLOSIVE
					if MultiplayerManager.is_multiplayer: sync_magazine_fire.rpc()
					else: sync_magazine_fire()
					balls_to_spawn -= 1
					if balls_to_spawn <= 0: is_spawning = false
func handle_ball_landed(x_pos: float, p_id: int):
	var nx = clamp(x_pos, arena_left + 15, arena_right - 15)
	if not first_ball_returned:
		first_ball_returned = true
		if MultiplayerManager.is_multiplayer and multiplayer.is_server():
			animate_launcher.rpc(nx)
		elif not MultiplayerManager.is_multiplayer:
			animate_launcher(nx)
			
	if game_manager:
		game_manager._on_ball_landed(x_pos, p_id)

func handle_ball_returned(p_id: int):
	if MultiplayerManager.is_multiplayer and multiplayer.is_server():
		sync_magazine_return.rpc()
	else:
		sync_magazine_return()
		
	if game_manager:
		game_manager._on_ball_returned(p_id)

@rpc("authority", "call_local", "reliable")
func sync_magazine_fire():
	magazine.fire_ball()

@rpc("authority", "call_local", "reliable")
func sync_magazine_return():
	magazine.return_ball()

@rpc("authority", "call_local")
func animate_launcher(new_x: float):
	next_launch_x = new_x
	launch_point.x = new_x # Immediate update for aim line
	magazine.shift_entrance_to(new_x)
	create_tween().tween_property(launcher, "position:x", new_x, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func update_ammo_label_position():
	if ammo_label:
		ammo_label.offset_left = launch_point.x + 15
		ammo_label.offset_right = launch_point.x + 75
		ammo_label.offset_top = launch_point.y - 10
		ammo_label.offset_bottom = launch_point.y + 15
		ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

func set_ammo(amount: int):
	magazine.set_ammo(amount)

func clear_aim():
	synced_aim_dir = Vector2.DOWN
	aim_line.clear_points()
	trajectory_preview.clear_points()
	launcher.clear_aim()

func set_preview_visible(is_visible: bool):
	preview_ball.visible = is_visible
	if is_visible:
		preview_ball.position = launch_point

func update_powerup_state(powerup_id: int, powered: bool):
	current_powerup = powerup_id
	is_powered = powered
	launcher.set_type(powerup_id)
	preview_ball.queue_redraw()

func _setup_preview_draw():
	preview_ball.draw.connect(func():
		match current_powerup:
			1: # EXPLOSIVE
				preview_ball.draw_circle(Vector2.ZERO, 10, Color(1.0, 0.4, 0.1, 0.3))
				var inner = Color(1.0, 0.5, 0.15, 0.9) if player_id == 1 else Color(1.0, 0.2, 0.4, 0.9)
				preview_ball.draw_circle(Vector2.ZERO, 8, inner)
			2: # RAILGUN
				preview_ball.draw_circle(Vector2.ZERO, 10, Color(0.2, 0.8, 1.0, 0.2))
				var glow = Color(0.3, 0.9, 1.0, 0.8) if player_id == 1 else Color(0.9, 0.3, 1.0, 0.8)
				preview_ball.draw_circle(Vector2.ZERO, 6, glow)
				preview_ball.draw_circle(Vector2.ZERO, 3, Color(1, 1, 1, 0.9))
			3: # BURN
				preview_ball.draw_circle(Vector2.ZERO, 10, Color(0.95, 0.4, 0.1, 0.2))
				var col = Color(0.95, 0.5, 0.15) if player_id == 1 else Color(0.95, 0.2, 0.3)
				preview_ball.draw_circle(Vector2.ZERO, 8, col)
				preview_ball.draw_circle(Vector2.ZERO, 5, Color(1.0, 0.7, 0.2))
			_:
				if is_powered:
					preview_ball.draw_circle(Vector2.ZERO, 10, Color(0.9, 0.2, 0.15, 0.25))
					preview_ball.draw_circle(Vector2.ZERO, 8, Color(0.85, 0.3, 0.25))
				elif player_id == 2:
					preview_ball.draw_circle(Vector2.ZERO, 8, Color(0.95, 0.35, 0.4, 0.9))
				else:
					preview_ball.draw_circle(Vector2.ZERO, 8, Color(0.3, 0.55, 0.95, 0.9))
	)
	preview_ball.queue_redraw()

func _draw_aim_line(direction: Vector2):
	if direction.y >= -0.1:
		aim_line.clear_points()
		trajectory_preview.clear_points()
		launcher.clear_aim()
		return
		
	launcher.set_aim(atan2(direction.y, direction.x))
	aim_line.clear_points()
	trajectory_preview.clear_points()

	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(launch_point + direction * 2, launch_point + direction * 800)
	query.collision_mask = 1
	var result = space_state.intersect_ray(query)
	
	if result:
		var total_dist = launch_point.distance_to(result.position)
		var dir_norm = (result.position - launch_point).normalized()
		var pos = launch_point
		var traveled = 0.0
		
		# to_local is no longer required because our positions are essentially global
		while traveled < total_dist:
			var seg = min(8.0, total_dist - traveled)
			aim_line.add_point(pos)
			pos = pos + dir_norm * seg
			traveled += seg
			aim_line.add_point(pos)
			var gap = min(5.0, total_dist - traveled)
			pos = pos + dir_norm * gap
			traveled += gap

		if current_powerup != 2: # NOT RAILGUN
			var bounce_dir = direction.bounce(result.normal)
			var b_pos = result.position
			for i in range(5):
				trajectory_preview.add_point(b_pos)
				b_pos = b_pos + bounce_dir * 6.0
				trajectory_preview.add_point(b_pos)
				b_pos = b_pos + bounce_dir * 5.0
		else:
			var b_pos = result.position
			for i in range(10):
				trajectory_preview.add_point(b_pos)
				b_pos = b_pos + direction * 6.0
				trajectory_preview.add_point(b_pos)
				b_pos = b_pos + direction * 5.0

		trajectory_preview.add_point(result.position - Vector2(1, 0))
		trajectory_preview.add_point(result.position + Vector2(1, 0))
	else:
		var dir_norm = direction
		var pos = launch_point
		for i in range(25):
			aim_line.add_point(pos)
			pos = pos + dir_norm * 8.0
			aim_line.add_point(pos)
			pos = pos + dir_norm * 5.0