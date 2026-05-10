extends Node2D

const BRICK_SCENE = preload("res://scenes/brick.tscn")
const BALL_SCENE = preload("res://scenes/ball.tscn")
const AMMO_ORB_SCENE = preload("res://scenes/ammo_orb.tscn")
const EXPLOSIVE_BALL_SCENE = preload("res://scenes/explosive_ball.tscn")
const RAILGUN_BALL_SCENE = preload("res://scenes/railgun_ball.tscn")
const BURN_BALL_SCENE = preload("res://scenes/burn_ball.tscn")
const BOSS_BRICK_SCENE = preload("res://scenes/boss_brick.tscn")
const GUARDIAN_BRICK_SCENE = preload("res://scenes/guardian_brick.tscn")
const RAINBOW_BRICK_SCENE = preload("res://scenes/rainbow_brick.tscn")
const ARMORED_BRICK_SCENE = preload("res://scenes/armored_brick.tscn")
const TRIANGLE_BRICK_SCENE = preload("res://scenes/triangle_brick.tscn")
const DIAGONAL_BRICK_SCENE = preload("res://scenes/diagonal_brick.tscn")
const BOARD_CLEAR_SHADER = preload("res://assets/shaders/board_clear.gdshader")
const OIL_BARREL_SCENE = preload("res://scenes/oil_barrel.tscn")
const PICKUP_SCENE = preload("res://scenes/pickup.tscn")
const SAVE_PATH = "user://highscore.save"

@onready var brick_container = $BrickContainer
@onready var ball_container = $BallContainer
@onready var aim_line = $AimLine
@onready var trajectory_preview = $TrajectoryPreview
@onready var ammo_label = $HUD/AmmoLabel
@onready var round_label = $HUD/RoundLabel
@onready var score_label = $HUD/ScoreLabel
@onready var high_score_label = $HUD/HighScoreLabel
@onready var xp_bar_fill = $HUD/XPBarFill
@onready var xp_text = $HUD/XPText
@onready var level_label = $HUD/LevelLabel
@onready var sp_label = $HUD/SPLabel
@onready var orb_container = $OrbContainer
@onready var speed_button = $HUD/SpeedButton
@onready var restart_button = $HUD/RestartButton
@onready var game_over_label = $HUD/GameOverLabel
@onready var final_score_label = $HUD/FinalScoreLabel
@onready var particle_container = $ParticleContainer
@onready var magazine = $Magazine
@onready var sound_manager = $SoundManager
@onready var launcher = $Launcher
@onready var xp_fill = $HUD/XPBar/XPFill
@onready var xp_preview_fill = $HUD/XPPreviewFill

var settings_menu: Node = null

# Powerup UI
@onready var explosive_button = $HUD/PowerupBar/ExplosiveButton
@onready var explosive_name_label = $HUD/PowerupBar/ExplosiveButton/ExplosiveLabel
@onready var explosive_cooldown_label = $HUD/PowerupBar/ExplosiveButton/ExplosiveCooldown
@onready var railgun_button = $HUD/PowerupBar/RailgunButton
@onready var railgun_name_label = $HUD/PowerupBar/RailgunButton/RailgunLabel
@onready var railgun_cooldown_label = $HUD/PowerupBar/RailgunButton/RailgunCooldown
@onready var burn_button = $HUD/PowerupBar/BurnButton
@onready var burn_name_label = $HUD/PowerupBar/BurnButton/BurnLabel
@onready var burn_cooldown_label = $HUD/PowerupBar/BurnButton/BurnCooldown
@onready var nuke_button = $HUD/PowerupBar/NukeButton
@onready var nuke_name_label = $HUD/PowerupBar/NukeButton/NukeLabel
@onready var nuke_label = $HUD/PowerupBar/NukeButton/NukeStatus
var triple_button: Button = null

var current_round: int = 1
var score: int = 0
var pending_xp: int = 0
var high_score: int = 0
var ammo: int = 1
var bonus_ammo: int = 0
var pending_ammo: int = 0
var is_aiming: bool = false
var last_aim_pos: Vector2 = Vector2.ZERO
var is_firing: bool = false
var railgun_deaths_pending: int = 0
var railgun_total_kills: int = 0
var railgun_active: bool = false
var fire_direction: Vector2
var balls_in_play: int = 0
var preview_ball: Node2D = null
var game_active: bool = true
var first_ball_returned: bool = false
var first_ball_missed: bool = false
var next_launch_x: float = 195.0

var is_spawning: bool = false
var balls_to_spawn: int = 0
var spawn_distance_accumulator: float = 0.0
var ball_spacing: float = 20.0

var speed_levels = [1.0, 2.0, 4.0]
var current_speed_idx: int = 0

var arena_left: float = 13.0
var arena_right: float = 377.0
var arena_top: float = 130.0
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

var damage_multiplier: float = 1.0
var ammo_multiplier: float = 1.0
var next_round_damage_mult: float = 1.0
var next_round_ammo_mult: float = 1.0
# Powerup states
enum ActivePowerup { NONE, EXPLOSIVE, RAILGUN, BURN, TRIPLE }
var active_powerup: int = ActivePowerup.NONE
var explosive_cooldown: int = 0
var explosive_cooldown_max: int = 4
var railgun_cooldown: int = 0
var railgun_cooldown_max: int = 0  # disabled for testing — railgun has no cooldown
var burn_cooldown: int = 0
var burn_cooldown_max: int = 5
var triple_cooldown: int = 0
var triple_cooldown_max: int = 3
var nuke_charges: int = 2
var burn_round_active: bool = false

# Boss system
var boss_schedule = {
	25: {"w": 2, "h": 2, "shield": 0},
	50: {"w": 2, "h": 3, "shield": 0},
	100: {"w": 3, "h": 3, "shield": 10},
	150: {"w": 3, "h": 4, "shield": 25},
	200: {"w": 4, "h": 4, "shield": 50},
}
var final_boss_start: int = 300
var final_boss_interval: int = 100
var bosses_killed: Array = []
var active_elites: int = 0
var max_elites: int = 2
var elite_chance: float = 0.12
# Pre-reservation: when an elite roll wins but no clear footprint, defer it
# and hold a strip of top-row columns clear so space opens up over a few rounds.
var pending_elite_info: Variant = null
var reserved_top_cols: Array = []
var pending_elite_rounds_waited: int = 0
const MAX_PENDING_ELITE_ROUNDS: int = 8

var board_clear_played: bool = false

# Rainbow brick
var rainbow_on_board: bool = false
var rainbow_spawn_chance: float = 0.05
var rounds_since_rainbow: int = 0

func _ready():
	add_to_group("game_manager")
	grid_start_x = arena_left + cell_width / 2.0
	grid_start_y = arena_top + cell_height / 2.0
	arena_bottom = arena_top + max_rows * cell_height
	launch_point = Vector2(195, arena_bottom + 20)
	original_position = position
	launcher.position = launch_point

	speed_button.pressed.connect(_on_speed_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	explosive_button.pressed.connect(func(): toggle_powerup(ActivePowerup.EXPLOSIVE))
	railgun_button.pressed.connect(func(): toggle_powerup(ActivePowerup.RAILGUN))
	burn_button.pressed.connect(func(): toggle_powerup(ActivePowerup.BURN))
	nuke_button.pressed.connect(_on_nuke_pressed)

	# TRIPLE shot button — created programmatically
	triple_button = Button.new()
	triple_button.text = "TRIPLE"
	triple_button.add_theme_font_size_override("font_size", 11)
	triple_button.pressed.connect(func(): toggle_powerup(ActivePowerup.TRIPLE))
	$HUD/PowerupBar.add_child(triple_button)
	_style_powerup_card(triple_button, UITheme.CYAN, "ready")

	load_high_score()

	# Apply talent effects
	explosive_cooldown_max = max(1, 4 - Progression.get_cooldown_reduction())
	railgun_cooldown_max = max(1, 8 - Progression.get_cooldown_reduction())
	burn_cooldown_max = max(1, 5 - Progression.get_cooldown_reduction())

	magazine.position = Vector2(0, launch_point.y + 25)
	magazine.pipe_left = arena_left
	magazine.pipe_right = arena_right
	magazine.entrance_x = launch_point.x
	magazine.set_ammo(ammo + bonus_ammo)

	spawn_round_bricks_at_row0()
	spawn_ammo_orbs_at_row0()

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

	# Apply lofi card stylebox to the HUD level card and gear/speed buttons
	_apply_hud_styling()

	update_hud()
	update_ammo_label_position()
	update_all_powerup_ui()
	create_preview_ball()
	queue_redraw()
	# Combo bar — add to HUD so it always renders above the game layer
	combo_bar = Node2D.new()
	combo_bar.position = Vector2(0, arena_top + 2)
	combo_bar.z_index = 100
	combo_bar.visible = false
	# Add under the HUD CanvasLayer so it draws above Node2D children
	if $HUD:
		$HUD.add_child(combo_bar)
	else:
		add_child(combo_bar)
	combo_bar.draw.connect(_draw_combo_bar)

	# Settings menu: instantiate on startup so it's available for the HUD GearButton
	var settings_scene = preload("res://scenes/settings_menu.tscn")
	settings_menu = settings_scene.instantiate()
	add_child(settings_menu)
	# Ensure the panel is hidden initially
	if settings_menu and settings_menu.has_node("Panel"):
		settings_menu.get_node("Panel").visible = false

	# Start game music
	MusicManager.start_game_music()

	# Connect gear button with debug prints and safe null check
	$HUD/GearButton.pressed.connect(func():
		print("Gear clicked")
		if settings_menu:
			settings_menu.toggle_menu()
		else:
			print("No settings menu!")
	)
func _draw():
	var border_color = UITheme.LINE_2
	var corner_radius = 8.0

	# Draw rounded arena border
	var rect = Rect2(arena_left, arena_top, arena_right - arena_left, arena_bottom - arena_top)
	draw_rounded_rect_outline(rect, border_color, corner_radius, 1.0)

	# Tiny corner brackets like the design
	var L = 10.0
	var bracket = UITheme.LINE_2
	# top-left
	draw_line(Vector2(arena_left + 6, arena_top + 6), Vector2(arena_left + 6 + L, arena_top + 6), bracket, 1.0)
	draw_line(Vector2(arena_left + 6, arena_top + 6), Vector2(arena_left + 6, arena_top + 6 + L), bracket, 1.0)
	# top-right
	draw_line(Vector2(arena_right - 6, arena_top + 6), Vector2(arena_right - 6 - L, arena_top + 6), bracket, 1.0)
	draw_line(Vector2(arena_right - 6, arena_top + 6), Vector2(arena_right - 6, arena_top + 6 + L), bracket, 1.0)
	# bottom-left
	draw_line(Vector2(arena_left + 6, arena_bottom - 6), Vector2(arena_left + 6 + L, arena_bottom - 6), bracket, 1.0)
	draw_line(Vector2(arena_left + 6, arena_bottom - 6), Vector2(arena_left + 6, arena_bottom - 6 - L), bracket, 1.0)
	# bottom-right
	draw_line(Vector2(arena_right - 6, arena_bottom - 6), Vector2(arena_right - 6 - L, arena_bottom - 6), bracket, 1.0)
	draw_line(Vector2(arena_right - 6, arena_bottom - 6), Vector2(arena_right - 6, arena_bottom - 6 - L), bracket, 1.0)

	# Grid lines
	var should_draw_grid = true
	if settings_menu != null:
		should_draw_grid = settings_menu.grid_enabled
	if should_draw_grid:
		var grid_color = Color(1, 1, 1, 0.05)
		for i in range(1, grid_cols):
			var x = arena_left + i * cell_width
			draw_line(Vector2(x, arena_top), Vector2(x, arena_bottom), grid_color, 1.0)
		for i in range(1, max_rows):
			var y = arena_top + i * cell_height
			draw_line(Vector2(arena_left, y), Vector2(arena_right, y), grid_color, 1.0)

func draw_rounded_rect(rect: Rect2, color: Color, radius: float):
	# Center fill
	draw_rect(Rect2(rect.position.x + radius, rect.position.y, rect.size.x - radius * 2, rect.size.y), color)
	draw_rect(Rect2(rect.position.x, rect.position.y + radius, rect.size.x, rect.size.y - radius * 2), color)
	# Corner circles
	draw_circle(Vector2(rect.position.x + radius, rect.position.y + radius), radius, color)
	draw_circle(Vector2(rect.end.x - radius, rect.position.y + radius), radius, color)
	draw_circle(Vector2(rect.position.x + radius, rect.end.y - radius), radius, color)
	draw_circle(Vector2(rect.end.x - radius, rect.end.y - radius), radius, color)

func draw_rounded_rect_outline(rect: Rect2, color: Color, radius: float, width: float):
	# Top
	draw_line(Vector2(rect.position.x + radius, rect.position.y), Vector2(rect.end.x - radius, rect.position.y), color, width)
	# Bottom
	draw_line(Vector2(rect.position.x + radius, rect.end.y), Vector2(rect.end.x - radius, rect.end.y), color, width)
	# Left
	draw_line(Vector2(rect.position.x, rect.position.y + radius), Vector2(rect.position.x, rect.end.y - radius), color, width)
	# Right
	draw_line(Vector2(rect.end.x, rect.position.y + radius), Vector2(rect.end.x, rect.end.y - radius), color, width)
	# Corners
	draw_arc(Vector2(rect.position.x + radius, rect.position.y + radius), radius, PI, PI * 1.5, 8, color, width)
	draw_arc(Vector2(rect.end.x - radius, rect.position.y + radius), radius, PI * 1.5, TAU, 8, color, width)
	draw_arc(Vector2(rect.position.x + radius, rect.end.y - radius), radius, PI * 0.5, PI, 8, color, width)
	draw_arc(Vector2(rect.end.x - radius, rect.end.y - radius), radius, 0, PI * 0.5, 8, color, width)

# Public helper so external menus can request a redraw when settings change
func refresh_draw():
	queue_redraw()

func _physics_process(delta):
	if shake_amount > 0.1:
		shake_amount = lerp(shake_amount, 0.0, shake_decay * delta)
		position = original_position + Vector2(randf_range(-shake_amount, shake_amount), randf_range(-shake_amount, shake_amount))
	elif shake_amount > 0:
		shake_amount = 0.0
		position = original_position
	if is_spawning and balls_to_spawn > 0:
		# Check if last spawned ball has traveled far enough
		var can_spawn = true
		if ball_container.get_child_count() > 0:
			var last_ball = ball_container.get_child(ball_container.get_child_count() - 1)
			if is_instance_valid(last_ball):
				var dist_from_launch = last_ball.position.distance_to(launch_point)
				if dist_from_launch < 1.0:  # ball diameter + padding
					can_spawn = false
		if can_spawn:
			do_launch_ball()
			balls_to_spawn -= 1
			if balls_to_spawn <= 0:
				is_spawning = false
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
	Engine.time_scale = speed_levels[current_speed_idx]
	speed_button.text = "%dx" % int(speed_levels[current_speed_idx])

func _on_restart_pressed():
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

# ---- POWERUP MANAGEMENT ----

func toggle_powerup(powerup: int):
	if not game_active:
		return
	var cd = get_cooldown(powerup)
	if cd > 0:
		return
	if active_powerup == powerup:
		active_powerup = ActivePowerup.NONE
	else:
		active_powerup = powerup
		sound_manager.play_powerup()
	update_all_powerup_ui()
	create_preview_ball()
	match active_powerup:
		ActivePowerup.NONE: launcher.set_type(0)
		ActivePowerup.EXPLOSIVE: launcher.set_type(1)
		ActivePowerup.RAILGUN: launcher.set_type(2)
		ActivePowerup.BURN: launcher.set_type(3)
		ActivePowerup.TRIPLE: launcher.set_type(0)

	update_launcher_type()

func get_cooldown(powerup: int) -> int:
	match powerup:
		ActivePowerup.EXPLOSIVE: return explosive_cooldown
		ActivePowerup.RAILGUN: return railgun_cooldown
		ActivePowerup.BURN: return burn_cooldown
		ActivePowerup.TRIPLE: return triple_cooldown
	return 0
func set_cooldown(powerup: int):
	match powerup:
		ActivePowerup.EXPLOSIVE: explosive_cooldown = explosive_cooldown_max
		ActivePowerup.RAILGUN: railgun_cooldown = railgun_cooldown_max
		ActivePowerup.BURN: burn_cooldown = burn_cooldown_max
		ActivePowerup.TRIPLE: triple_cooldown = triple_cooldown_max

func tick_cooldowns():
	if explosive_cooldown > 0: explosive_cooldown -= 1
	if railgun_cooldown > 0: railgun_cooldown -= 1
	if burn_cooldown > 0: burn_cooldown -= 1
	if triple_cooldown > 0: triple_cooldown -= 1

func _apply_hud_styling():
	# Card backing for the level row
	var lc = $HUD.get_node_or_null("LevelCard")
	if lc:
		var sb = UITheme.make_card(UITheme.BG_CARD, UITheme.LINE, UITheme.R_MD)
		sb.set_content_margin_all(8)
		lc.add_theme_stylebox_override("panel", sb)

	# Compact icon-style buttons in the top bar
	_style_icon_button(speed_button, UITheme.CYAN)
	_style_icon_button($HUD/GearButton, UITheme.TEXT)

func _style_icon_button(btn: Button, accent: Color):
	if not btn: return
	var sb_n = UITheme.make_card(UITheme.BG_CARD, UITheme.LINE_2, UITheme.R_SM)
	sb_n.set_content_margin_all(4)
	var sb_h = sb_n.duplicate()
	sb_h.bg_color = UITheme.BG_CARDHI
	sb_h.border_color = accent
	var sb_p = sb_h.duplicate()
	sb_p.bg_color = Color(accent.r, accent.g, accent.b, 0.10)
	btn.add_theme_stylebox_override("normal",  sb_n)
	btn.add_theme_stylebox_override("hover",   sb_h)
	btn.add_theme_stylebox_override("pressed", sb_p)

# Apply card stylebox + top-edge accent ribbon to a powerup button.
# state: "ready" (accent), "armed" (lime+amber tint), "off" (rose), "cd" (rose dim)
func _style_powerup_card(btn: Button, accent: Color, state: String) -> void:
	if not btn: return
	var border_col := UITheme.LINE
	var bg_col := UITheme.BG_CARD
	if state == "armed":
		border_col = accent
		bg_col = Color(accent.r, accent.g, accent.b, 0.10)
	elif state == "ready":
		border_col = Color(accent.r, accent.g, accent.b, 0.45)
	elif state == "cd":
		bg_col = UITheme.BG_CARD.darkened(0.15)
	elif state == "off":
		border_col = UITheme.LINE
		bg_col = UITheme.BG_CARD.darkened(0.20)

	var sb := UITheme.make_card(bg_col, border_col, UITheme.R_MD)
	sb.set_content_margin_all(6)
	# Accent ribbon on top
	if state == "ready" or state == "armed":
		sb.border_width_top = 2
	elif state == "off" or state == "cd":
		sb.border_width_top = 2
	btn.add_theme_stylebox_override("normal",  sb)
	btn.add_theme_stylebox_override("hover",   sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("disabled", sb)
	# When disabled the ribbon becomes rose-dim; visualize via modulate
	btn.modulate = Color(1, 1, 1, 0.45) if state == "off" or state == "cd" else Color(1, 1, 1)

func _set_powerup_status(name_lbl: Label, status_lbl: Label, accent: Color, state: String, status_text: String) -> void:
	if not name_lbl or not status_lbl: return
	name_lbl.add_theme_color_override("font_color", UITheme.TEXT if state != "off" else UITheme.TEXT_DIM)
	status_lbl.text = status_text
	if state == "armed":
		status_lbl.add_theme_color_override("font_color", UITheme.AMBER)
	elif state == "ready":
		status_lbl.add_theme_color_override("font_color", accent)
	else:
		status_lbl.add_theme_color_override("font_color", UITheme.ROSE)

func update_powerup_button(button: Button, label: Label, cd: int, is_active: bool, cd_max: int):
	# Legacy signature kept for compatibility; routed through the new card styling.
	pass

func update_all_powerup_ui():
	# Explosive (lime)
	if explosive_cooldown > 0:
		_style_powerup_card(explosive_button, UITheme.LIME, "cd")
		_set_powerup_status(explosive_name_label, explosive_cooldown_label, UITheme.LIME, "cd", "%d ROUNDS" % explosive_cooldown)
		explosive_button.disabled = true
	elif active_powerup == ActivePowerup.EXPLOSIVE:
		_style_powerup_card(explosive_button, UITheme.LIME, "armed")
		_set_powerup_status(explosive_name_label, explosive_cooldown_label, UITheme.LIME, "armed", "ARMED")
		explosive_button.disabled = false
	else:
		_style_powerup_card(explosive_button, UITheme.LIME, "ready")
		_set_powerup_status(explosive_name_label, explosive_cooldown_label, UITheme.LIME, "ready", "READY")
		explosive_button.disabled = false

	# Railgun (cyan)
	if railgun_cooldown > 0:
		_style_powerup_card(railgun_button, UITheme.CYAN, "cd")
		_set_powerup_status(railgun_name_label, railgun_cooldown_label, UITheme.CYAN, "cd", "%d ROUNDS" % railgun_cooldown)
		railgun_button.disabled = true
	elif active_powerup == ActivePowerup.RAILGUN:
		_style_powerup_card(railgun_button, UITheme.CYAN, "armed")
		_set_powerup_status(railgun_name_label, railgun_cooldown_label, UITheme.CYAN, "armed", "ARMED")
		railgun_button.disabled = false
	else:
		_style_powerup_card(railgun_button, UITheme.CYAN, "ready")
		_set_powerup_status(railgun_name_label, railgun_cooldown_label, UITheme.CYAN, "ready", "READY")
		railgun_button.disabled = false

	# Burn (amber)
	if burn_cooldown > 0:
		_style_powerup_card(burn_button, UITheme.AMBER, "cd")
		_set_powerup_status(burn_name_label, burn_cooldown_label, UITheme.AMBER, "cd", "%d ROUNDS" % burn_cooldown)
		burn_button.disabled = true
	elif active_powerup == ActivePowerup.BURN:
		_style_powerup_card(burn_button, UITheme.AMBER, "armed")
		_set_powerup_status(burn_name_label, burn_cooldown_label, UITheme.AMBER, "armed", "ARMED")
		burn_button.disabled = false
	else:
		_style_powerup_card(burn_button, UITheme.AMBER, "ready")
		_set_powerup_status(burn_name_label, burn_cooldown_label, UITheme.AMBER, "ready", "READY")
		burn_button.disabled = false

	# Nuke (rose) — charges-based
	if nuke_charges > 0:
		_style_powerup_card(nuke_button, UITheme.ROSE, "ready")
		_set_powerup_status(nuke_name_label, nuke_label, UITheme.ROSE, "ready", "× %d READY" % nuke_charges)
		nuke_button.disabled = false
	else:
		_style_powerup_card(nuke_button, UITheme.ROSE, "off")
		_set_powerup_status(nuke_name_label, nuke_label, UITheme.ROSE, "off", "NO CHARGES")
		nuke_button.disabled = true

	# Triple (cyan)
	if triple_cooldown > 0:
		_style_powerup_card(triple_button, UITheme.CYAN, "cd")
		triple_button.disabled = true
	elif active_powerup == ActivePowerup.TRIPLE:
		_style_powerup_card(triple_button, UITheme.CYAN, "armed")
		triple_button.disabled = false
	else:
		_style_powerup_card(triple_button, UITheme.CYAN, "ready")
		triple_button.disabled = false

func update_launcher_type():
		match active_powerup:
			ActivePowerup.NONE:
				launcher.set_type(0)      # DEFAULT
			ActivePowerup.EXPLOSIVE:
				launcher.set_type(1)  # BOMB
			ActivePowerup.RAILGUN:
				launcher.set_type(2)    # RAILGUN
			ActivePowerup.TRIPLE: launcher.set_type(0)
			ActivePowerup.BURN:
				launcher.set_type(3)       # BURN
func _on_nuke_pressed():
	if launcher:
		launcher.set_type(4)  # NUKE visual briefly
	if nuke_charges <= 0 or is_firing or not game_active or is_sliding or is_dropping:
		return
	nuke_charges -= 1
	do_nuke()
	update_all_powerup_ui()

func do_nuke():
	sound_manager.play_nuke()
	add_shake(12.0)
	spawn_modifier_popup("☢ NUKE ☢", Color(1.0, 0.9, 0.2))

	# Destroy all bricks with big VFX
	var bricks = brick_container.get_children().duplicate()
	for brick in bricks:
		if is_instance_valid(brick):
			if brick.has_node("Sprite"):
				spawn_brick_particles(brick.global_position, brick.get_node("Sprite").color)
			# Score for each
			if brick.has_method("get_brick_value"):
				add_score(brick.get_brick_value())
			brick.queue_free()

	# Big center explosion VFX
	spawn_explosion_vfx(Vector2(195, arena_top + (arena_bottom - arena_top) / 2), 200)

# ---- PREVIEW & AIMING ----

func create_preview_ball():
	if preview_ball:
		preview_ball.queue_free()
	preview_ball = Node2D.new()
	preview_ball.position = launch_point
	add_child(preview_ball)
	var pw = active_powerup
	var is_pow = damage_multiplier > 1.0
	preview_ball.draw.connect(func():
		match pw:
			ActivePowerup.EXPLOSIVE:
				preview_ball.draw_circle(Vector2.ZERO, 10, Color(1.0, 0.4, 0.1, 0.3))
				preview_ball.draw_circle(Vector2.ZERO, 8, Color(1.0, 0.5, 0.15, 0.9))
			ActivePowerup.RAILGUN:
				preview_ball.draw_circle(Vector2.ZERO, 10, Color(0.2, 0.8, 1.0, 0.2))
				preview_ball.draw_circle(Vector2.ZERO, 6, Color(0.3, 0.9, 1.0, 0.8))
				preview_ball.draw_circle(Vector2.ZERO, 3, Color(1, 1, 1, 0.9))
			ActivePowerup.BURN:
				preview_ball.draw_circle(Vector2.ZERO, 10, Color(0.95, 0.4, 0.1, 0.2))
				preview_ball.draw_circle(Vector2.ZERO, 8, Color(0.95, 0.5, 0.15))
				preview_ball.draw_circle(Vector2.ZERO, 5, Color(1.0, 0.7, 0.2))
			_:
				if is_pow:
					preview_ball.draw_circle(Vector2.ZERO, 10, Color(0.9, 0.2, 0.15, 0.25))
					preview_ball.draw_circle(Vector2.ZERO, 8, Color(0.85, 0.3, 0.25))
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
		var pos = event.position if event is InputEventMouseButton else event.position
		if pressed:
			if pos.y > 70 and pos.y < 700 and pos.x > arena_left and pos.x < arena_right:
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
			last_aim_pos = aim_pos
			update_aim_line(aim_pos)

func update_aim_line(target: Vector2):
	var direction = (target - launch_point).normalized()
	if direction.y >= -0.1:
		aim_line.clear_points()
		trajectory_preview.clear_points()
		launcher.clear_aim()
		return
	launcher.set_aim(atan2(direction.y, direction.x))
	aim_line.clear_points()
	trajectory_preview.clear_points()

	# launch sound will play when the first ball instance is actually launched
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(launch_point + direction * 2, launch_point + direction * 800)
	query.collision_mask = 1
	var result = space_state.intersect_ray(query)
	if result:
		# Dotted main line to first bounce
		var total_dist = launch_point.distance_to(result.position)
		var dir_norm = (result.position - launch_point).normalized()
		var pos = launch_point
		var traveled = 0.0
		while traveled < total_dist:
			var seg = min(8.0, total_dist - traveled)
			aim_line.add_point(pos)
			pos = pos + dir_norm * seg
			traveled += seg
			aim_line.add_point(pos)
			var gap = min(5.0, total_dist - traveled)
			pos = pos + dir_norm * gap
			traveled += gap

		# Bounce preview — shorter dots, fading feel
		if active_powerup != ActivePowerup.RAILGUN:
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

		# Small dot at bounce point
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

# ---- FIRING ----

func start_firing():
	is_firing = true
	balls_in_play = 0
	first_ball_returned = false
	first_ball_missed = false
	pending_ammo = 0
	railgun_deaths_pending = 0
	railgun_total_kills = 0
	railgun_active = false
	if preview_ball:
		preview_ball.visible = false
	ammo_label.visible = false
	aim_line.clear_points()
	trajectory_preview.clear_points()

	# Debug launch sound
	print("Trying launch sound")
	print("Players: ", sound_manager.players.keys())
	var key = "launch"
	if sound_manager.players.has(key):
		print("Has player, stream: ", sound_manager.players[key].stream)
		if sound_manager.players[key].stream:
			sound_manager.players[key].play()
			print("Playing!")
		else:
			print("No stream loaded!")
	else:
		print("No player for key: ", key)

	var total = ammo + bonus_ammo
	if ammo_multiplier > 1.0:
		total = int(total * ammo_multiplier)
	balls_to_spawn = total

	# Reset pending XP preview when firing begins
	pending_xp = 0
	if xp_preview_fill:
		xp_preview_fill.visible = false
		xp_preview_fill.offset_left = 60.0
		xp_preview_fill.offset_right = 60.0

	# Fire special ball first if powerup armed
	if active_powerup != ActivePowerup.NONE:
		# BURN is a round modifier: enable burn for the whole round and don't spawn a special ball
		if active_powerup == ActivePowerup.BURN:
			burn_round_active = true
			set_cooldown(ActivePowerup.BURN)
			active_powerup = ActivePowerup.NONE
			update_all_powerup_ui()
			update_launcher_type()
			launcher.clear_aim()
		else:
			var special_scene = null
			match active_powerup:
				ActivePowerup.EXPLOSIVE: special_scene = EXPLOSIVE_BALL_SCENE
				ActivePowerup.RAILGUN: special_scene = RAILGUN_BALL_SCENE

			if special_scene:
				var ball = special_scene.instantiate()
				ball.position = launch_point
				ball.speed = 800.0 if active_powerup != ActivePowerup.RAILGUN else 1500.0
				ball.ball_returned.connect(_on_ball_returned)
				ball.ball_landed.connect(_on_ball_landed)
				ball_container.add_child(ball)
				ball.launch(fire_direction)
				if active_powerup == ActivePowerup.RAILGUN:
					sound_manager.play_railgun()
					# mark railgun active so normal destroy sounds are suppressed until railgun sequence completes
					railgun_active = true
				balls_in_play += 1
				if active_powerup == ActivePowerup.RAILGUN:
					# Railgun consumes all ammo - single shot only
					for i in range(balls_to_spawn):
						magazine.fire_ball()
					balls_to_spawn = 0
				else:
					magazine.fire_ball()
					balls_to_spawn -= 1
				set_cooldown(active_powerup)
				active_powerup = ActivePowerup.NONE
				update_all_powerup_ui()
				update_launcher_type()
				launcher.clear_aim()

	# TRIPLE SHOT: fire 3 balls in spread pattern
	if active_powerup == ActivePowerup.TRIPLE:
		var center_dir = fire_direction
		var spread_angle = deg_to_rad(15.0)
		var angles = [-spread_angle, 0.0, spread_angle]
		for a in angles:
			fire_direction = center_dir.rotated(a)
			do_launch_ball()
			balls_to_spawn -= 1
		fire_direction = center_dir
		set_cooldown(ActivePowerup.TRIPLE)
		active_powerup = ActivePowerup.NONE
		update_all_powerup_ui()
		update_launcher_type()
		launcher.clear_aim()

	if balls_to_spawn > 0:
		is_spawning = true
	elif balls_in_play == 0:
		end_round()

func do_launch_ball():
	sound_manager.play("launch")
	var ball = BALL_SCENE.instantiate()
	ball.position = launch_point
	ball.speed = 800.0
	ball.damage_multiplier = damage_multiplier * Progression.get_damage_multiplier()
	ball.is_powered = (damage_multiplier > 1.0)
	# If a burn round is active, this ball will apply burn stacks on hit
	ball.applies_burn = burn_round_active
	ball.ball_returned.connect(_on_ball_returned)
	ball.ball_landed.connect(_on_ball_landed)
	ball_container.add_child(ball)
	ball.launch(fire_direction)
	balls_in_play += 1
	magazine.fire_ball()

# ---- EXPLOSION ----

func do_explosion(center: Vector2, radius: float):
	sound_manager.play_explode()
	add_shake(8.0)
	spawn_explosion_vfx(center, radius)
	var ball_count = ammo + bonus_ammo
	var inner_radius = radius * 0.4
	var direct_damage = max(20, int(8.0 * ball_count)) if current_round > 10 else 20
	var inner_damage = max(10, int(4.0 * ball_count)) if current_round > 10 else 10
	var outer_damage = max(5, int(1.5 * ball_count)) if current_round > 10 else 5
	for brick in brick_container.get_children():
		var dist = center.distance_to(brick.position)
		if dist < 1.0:
				brick.take_damage(direct_damage, Vector2.DOWN, true)
				if brick.has_method("apply_explosion_crack"):
					brick.apply_explosion_crack(0)
		elif dist <= inner_radius:
				brick.take_damage(inner_damage, Vector2.DOWN, true)
				if brick.has_method("apply_explosion_crack"):
					brick.apply_explosion_crack(1)
		elif dist <= radius:
				brick.take_damage(outer_damage, Vector2.DOWN, true)
				if brick.has_method("apply_explosion_crack"):
					brick.apply_explosion_crack(2)

func spawn_explosion_vfx(center: Vector2, radius: float):
	var explosion = Node2D.new()
	explosion.position = center
	particle_container.add_child(explosion)
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

func do_oil_barrel_explosion(center: Vector2, radius: float, base_damage: int):
	sound_manager.play_explode()
	add_shake(10.0)
	# Bigger, fierier explosion VFX
	var explosion = Node2D.new()
	explosion.position = center
	particle_container.add_child(explosion)
	# Fire particles
	for i in range(24):
		var p = ColorRect.new()
		var s = randf_range(4, 10)
		p.size = Vector2(s, s)
		p.position = Vector2(-s/2, -s/2)
		p.color = [Color(1.0, 0.4, 0.05), Color(1.0, 0.6, 0.1), Color(1.0, 0.8, 0.2), Color(0.3, 0.3, 0.3)][randi() % 4]
		explosion.add_child(p)
		var angle = (TAU / 24.0) * i + randf_range(-0.15, 0.15)
		var dist = randf_range(20, radius * 0.8)
		var target_pos = Vector2(cos(angle) * dist, sin(angle) * dist)
		var tween = p.create_tween()
		tween.set_parallel(true)
		tween.tween_property(p, "position", target_pos, 0.5).set_ease(Tween.EASE_OUT)
		tween.tween_property(p, "modulate:a", 0.0, 0.5)
		tween.chain().tween_callback(p.queue_free)
	# Smoke ring
	for i in range(8):
		var smoke = ColorRect.new()
		smoke.size = Vector2(8, 8)
		smoke.position = Vector2(-4, -4)
		smoke.color = Color(0.2, 0.2, 0.2, 0.4)
		explosion.add_child(smoke)
		var angle = randf_range(0, TAU)
		var dist = randf_range(radius * 0.5, radius)
		var target_pos = Vector2(cos(angle) * dist, sin(angle) * dist - 20)
		var tween = smoke.create_tween()
		tween.set_parallel(true)
		tween.tween_property(smoke, "position", target_pos, 0.8).set_ease(Tween.EASE_OUT)
		tween.tween_property(smoke, "modulate:a", 0.0, 0.8)
		tween.chain().tween_callback(smoke.queue_free)
	get_tree().create_timer(0.9).timeout.connect(func():
		if is_instance_valid(explosion):
			explosion.queue_free()
	)
	# Damage all bricks in radius - strips armor too
	var inner_radius = radius * 0.3
	for brick in brick_container.get_children():
		var dist = center.distance_to(brick.position)
		if dist <= radius:
			# Strip armor on any armored brick in range
			if brick.has_method("strip_armor"):
				brick.strip_armor()
			# Apply damage
			if dist < 1.0:
				brick.take_damage(base_damage, Vector2.DOWN, true)
			elif dist <= inner_radius:
				brick.take_damage(int(base_damage * 0.7), Vector2.DOWN, true)
			else:
				var falloff = 1.0 - (dist / radius)
				brick.take_damage(max(1, int(base_damage * falloff)), Vector2.DOWN, true)
			if brick.has_method("apply_explosion_crack"):
				brick.apply_explosion_crack(0 if dist < inner_radius else 1 if dist < radius * 0.6 else 2)
	# Screen flash for big explosion
	spawn_screen_flash()
func spawn_railgun_trail(pos: Vector2):
	var trail = Node2D.new()
	trail.position = pos
	particle_container.add_child(trail)
	# Electric spark effect
	for i in range(4):
		var p = ColorRect.new()
		p.size = Vector2(3, 3)
		p.position = Vector2(-1.5, -1.5)
		p.color = Color(0.3, 0.9, 1.0)
		trail.add_child(p)
		var target_pos = Vector2(randf_range(-15, 15), randf_range(-15, 15))
		var tween = p.create_tween()
		tween.set_parallel(true)
		tween.tween_property(p, "position", target_pos, 0.2)
		tween.tween_property(p, "modulate:a", 0.0, 0.2)
		tween.chain().tween_callback(p.queue_free)
	get_tree().create_timer(0.3).timeout.connect(func():
		if is_instance_valid(trail):
			trail.queue_free()
	)

# ---- PICKUPS & RAINBOW ----

func collect_pickup(pickup_type: int):
	if pickup_type == 0:
		next_round_ammo_mult = 2.0
		spawn_modifier_popup("2x AMMO NEXT", Color(0.9, 0.65, 0.15))
	elif pickup_type == 1:
		next_round_damage_mult = 2.0
		spawn_modifier_popup("2x DMG NEXT", Color(0.85, 0.25, 0.2))
	elif pickup_type == 2:
		nuke_charges += 1
		spawn_modifier_popup("☢ NUKE CHARGE!", Color(1.0, 0.9, 0.2))
		update_all_powerup_ui()

func on_rainbow_brick_destroyed(pos: Vector2):
	rainbow_on_board = false
	rounds_since_rainbow = 0
	rainbow_spawn_chance = 0.05
	# Drop: 40% 2x ammo, 40% 2x damage, 20% nuke charge
	var roll = randf()
	var pickup = PICKUP_SCENE.instantiate()
	pickup.position = pos
	if roll < 0.4:
		pickup.pickup_type = 0  # 2x ammo
	elif roll < 0.8:
		pickup.pickup_type = 1  # 2x damage
	else:
		pickup.pickup_type = 2  # nuke charge
	orb_container.add_child(pickup)

func on_boss_killed(boss):
	if boss.is_final_boss:
		spawn_modifier_popup("FINAL BOSS DEFEATED!", Color(1.0, 0.85, 0.2))
	elif boss.is_elite:
		active_elites -= 1
		# Drop a random powerup (0 or 1)
		var pickup = PICKUP_SCENE.instantiate()
		pickup.position = boss.global_position
		pickup.pickup_type = randi_range(0, 1)
		orb_container.add_child(pickup)
		spawn_modifier_popup("ELITE DEFEATED!", Color(0.6, 0.3, 0.9))
	# Track killed boss rounds for elite system
	for round_num in boss_schedule.keys():
		var info = boss_schedule[round_num]
		if boss.grid_width == info["w"] and boss.grid_height == info["h"]:
			if round_num not in bosses_killed:
				bosses_killed.append(round_num)

# ---- ROUND MANAGEMENT ----

func _on_ball_landed(x_pos: float):
	if not first_ball_returned:
		first_ball_returned = true
		# Record the next launch x based on where the ball landed
		next_launch_x = clamp(x_pos, arena_left + 15, arena_right - 15)
		magazine.shift_entrance_to(next_launch_x)
		# Animate launcher to new position in sync with magazine
		var tween = create_tween()
		tween.tween_property(launcher, "position:x", next_launch_x, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _on_ball_returned():
	balls_in_play -= 1
	magazine.return_ball()
	if balls_in_play <= 0 and not is_spawning:
		if railgun_deaths_pending > 0:
			pass  # Wait for railgun deaths to finish
		else:
			end_round()

func on_ball_missed():
	if first_ball_missed:
		return
	# Only trigger after 55+ balls have fired
	var total = ammo + bonus_ammo
	var balls_fired = total - balls_to_spawn
	if balls_fired < 55:
		return
	first_ball_missed = true
	# If still spawning, cancel remaining balls and return them to the magazine
	if is_spawning:
		for i in range(balls_to_spawn):
			magazine.return_ball()
		balls_to_spawn = 0
		is_spawning = false

func on_railgun_death_finished():
	railgun_deaths_pending -= 1
	railgun_total_kills += 1
	
	if railgun_deaths_pending <= 0:
		# All railgun deaths done — play appropriate sound
		if railgun_total_kills > 1:
			sound_manager.play_multi_destroy()
		else:
			sound_manager.play_destroy()
		railgun_total_kills = 0
		# railgun sequence finished
		railgun_active = false
		
		if balls_in_play <= 0 and not is_spawning:
			end_round()

func end_round():
	is_firing = false
	board_clear_played = false
	current_round += 1
	launch_point.x = next_launch_x

	# Move magazine entrance and animate launcher to the new launch position
	magazine.shift_entrance_to(next_launch_x)
	var launcher_tween = create_tween()
	launcher_tween.tween_property(launcher, "position:x", next_launch_x, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	damage_multiplier = next_round_damage_mult
	ammo_multiplier = next_round_ammo_mult
	next_round_damage_mult = 1.0
	next_round_ammo_mult = 1.0

	if damage_multiplier > 1.0:
		magazine.modifier_tint = Color(0.9, 0.15, 0.1, 0.3)
	elif ammo_multiplier > 1.0:
		magazine.modifier_tint = Color(0.9, 0.7, 0.15, 0.3)
	else:
		magazine.modifier_tint = Color(1, 1, 1, 0)

	tick_cooldowns()
	update_all_powerup_ui()

	# Process burn DOT on all bricks
	for brick in brick_container.get_children():
		if brick.has_method("process_burn"):
			brick.process_burn()

	# Reset stacking hit counts for new round
	for brick in brick_container.get_children():
		if "hit_count" in brick:
			brick.hit_count = 0

	# Burn round modifier only applies to the current round's launched balls
	burn_round_active = false

	# Clear temporary railgun hit metadata so bricks can be targeted in subsequent rounds
	for brick in brick_container.get_children():
		if brick.has_meta("railgun_hit"):
			brick.remove_meta("railgun_hit")

	# Regenerate boss shields
	# Flash XP preview to green then apply
	if pending_xp > 0 and xp_preview_fill:
		xp_preview_fill.color = Color(0.741, 1.0, 0.024, 0.8)
		var xp_tween = create_tween()
		xp_tween.tween_property(xp_preview_fill, "modulate:a", 0.0, 0.3)
		xp_tween.tween_callback(func():
			xp_preview_fill.visible = false
			xp_preview_fill.modulate.a = 1.0
			xp_preview_fill.color = Color(1, 1, 1, 0.5)
		)
	Progression.add_xp(pending_xp)
	pending_xp = 0
	update_hud()
	for brick in brick_container.get_children():
		if brick.has_method("regenerate_shield"):
			brick.regenerate_shield()

	spawn_guardians_if_needed()

	if pending_ammo > 0:
		for i in range(pending_ammo):
			magazine.add_ball_plop()
		bonus_ammo += pending_ammo
		spawn_ammo_popup(pending_ammo)
		pending_ammo = 0

	create_preview_ball()
	if preview_ball:
		preview_ball.visible = false
	update_launcher_type()
	spawn_round_content()
	start_slide_existing()

func spawn_guardians_if_needed():
	for brick in brick_container.get_children():
		if brick.has_method("should_spawn_guardians") and brick.should_spawn_guardians():
			var boss_row = round((brick.position.y - grid_start_y) / cell_height)
			var target_row = boss_row + brick.grid_height + 1
			if target_row < max_rows:
				var occupied = get_occupied_cells()
				var available = []
				for c in range(grid_cols):
					if Vector2(c, target_row) not in occupied:
						available.append(c)
				available.shuffle()
				for i in range(min(2, available.size())):
					var g = GUARDIAN_BRICK_SCENE.instantiate()
					g.position = Vector2(grid_start_x + available[i] * cell_width, grid_start_y + target_row * cell_height)
					brick_container.add_child(g)

func spawn_round_content():
	try_spawn_pending_elite()
	try_spawn_boss()
	try_spawn_elite()
	spawn_round_bricks_at_row0()
	spawn_ammo_orbs_at_row0()
	try_spawn_special_bricks()
	try_spawn_rainbow()

func try_spawn_special_bricks():
	if not game_active:
		return
	var occupied = get_occupied_cells()
	# Armored brick: 10% chance after round 15
	if current_round >= 15 and randf() < 0.10:
		var available = []
		for c in range(grid_cols):
			if Vector2(c, 0) not in occupied:
				available.append(c)
		if available.size() > 0:
			var col = available[randi() % available.size()]
			var brick = ARMORED_BRICK_SCENE.instantiate()
			brick.position = Vector2(grid_start_x + col * cell_width, grid_start_y)
			brick.health = current_round
			brick.max_health = current_round
			brick_container.add_child(brick)
			occupied.append(Vector2(col, 0))

	# Rotating triangle brick — chaotic spinning hazard, max one on board
	var has_triangle = false
	var has_diagonal = false
	for b in brick_container.get_children():
		if b.is_in_group("triangle_bricks"):
			has_triangle = true
		if b.is_in_group("diagonal_bricks"):
			has_diagonal = true
	if not has_triangle and randf() < 0.5:
		var available = []
		for c in range(grid_cols):
			if Vector2(c, 0) not in occupied and c not in reserved_top_cols:
				available.append(c)
		if available.size() > 0:
			var col = available[randi() % available.size()]
			var tri = TRIANGLE_BRICK_SCENE.instantiate()
			tri.position = Vector2(grid_start_x + col * cell_width, grid_start_y)
			tri.health = current_round
			tri.max_health = current_round
			tri.rotation = randf() * TAU
			tri.spin_speed = randf_range(1.0, 2.0) * (1.0 if randf() > 0.5 else -1.0)
			brick_container.add_child(tri)
			occupied.append(Vector2(col, 0))

	# Diagonal-cut brick — grid-aligned right triangle, slightly more common
	if not has_diagonal and randf() < 0.6:
		var available = []
		for c in range(grid_cols):
			if Vector2(c, 0) not in occupied and c not in reserved_top_cols:
				available.append(c)
		if available.size() > 0:
			var col = available[randi() % available.size()]
			var d = DIAGONAL_BRICK_SCENE.instantiate()
			d.position = Vector2(grid_start_x + col * cell_width, grid_start_y)
			d.health = current_round
			d.max_health = current_round
			d.orientation = randi() % 4
			brick_container.add_child(d)
			occupied.append(Vector2(col, 0))

	# Oil barrel: 8% chance after round 10
	if current_round >= 10 and randf() < 0.08:
		var available = []
		for c in range(grid_cols):
			if Vector2(c, 0) not in occupied:
				available.append(c)
		if available.size() > 0:
			var col = available[randi() % available.size()]
			var barrel = OIL_BARREL_SCENE.instantiate()
			barrel.position = Vector2(grid_start_x + col * cell_width, grid_start_y)
			brick_container.add_child(barrel)

func try_spawn_boss():
	var boss_info = get_boss_info(current_round)
	if boss_info:
		spawn_boss(boss_info)

func get_boss_info(round_num: int) -> Variant:
	if boss_schedule.has(round_num):
		var info = boss_schedule[round_num].duplicate()
		info["hp_mult"] = 2
		return info
	if round_num >= final_boss_start and (round_num - final_boss_start) % final_boss_interval == 0:
		var iteration = (round_num - final_boss_start) / final_boss_interval
		return {
			"w": 7, "h": 2, "shield": 50,
			"hp_mult": 2, "is_final": true,
			"health_override": 1000 + iteration * 500,
			"guardians": true, "moves_every_other": true
		}
	return null

func try_spawn_elite():
	if current_round < 75 or active_elites >= max_elites:
		return
	if pending_elite_info != null:
		return  # already have one waiting for space
	var eligible = []
	for boss_round in boss_schedule.keys():
		if boss_round <= current_round - 50 and boss_round in bosses_killed:
			eligible.append(boss_round)
	if eligible.size() == 0:
		return
	if randf() < elite_chance:
		var template_round = eligible[randi() % eligible.size()]
		var info = boss_schedule[template_round].duplicate()
		info["is_elite"] = true
		info["hp_mult"] = 1
		var col = find_clear_boss_footprint(info["w"], info["h"])
		if col >= 0:
			spawn_boss_at(info, col)
			active_elites += 1
		else:
			# Defer — pre-reserve a top-row strip so space opens up
			defer_elite(info)

func defer_elite(info: Dictionary):
	pending_elite_info = info
	pending_elite_rounds_waited = 0
	reserved_top_cols = pick_reservation_strip(info["w"])

func try_spawn_pending_elite():
	if pending_elite_info == null:
		return
	var info = pending_elite_info
	var col = find_clear_boss_footprint(info["w"], info["h"])
	if col >= 0:
		spawn_boss_at(info, col)
		active_elites += 1
		pending_elite_info = null
		reserved_top_cols = []
		pending_elite_rounds_waited = 0
		return
	pending_elite_rounds_waited += 1
	if pending_elite_rounds_waited >= MAX_PENDING_ELITE_ROUNDS:
		pending_elite_info = null
		reserved_top_cols = []
		pending_elite_rounds_waited = 0
	else:
		# Refresh reservation in case existing strip was overrun by destruction shifts
		reserved_top_cols = pick_reservation_strip(info["w"])

func find_clear_boss_footprint(w: int, h: int) -> int:
	var occupied = get_occupied_cells()
	var candidates = []
	var max_col = grid_cols - w
	for col in range(max_col + 1):
		var clear = true
		for dx in range(w):
			for dy in range(h):
				if Vector2(col + dx, dy) in occupied:
					clear = false
					break
			if not clear:
				break
		if clear:
			candidates.append(col)
	if candidates.is_empty():
		return -1
	return candidates[randi() % candidates.size()]

func pick_reservation_strip(w: int) -> Array:
	# Choose a contiguous w-cell strip in row 0 that isn't currently occupied.
	var occupied = get_occupied_cells()
	var candidates = []
	var max_col = grid_cols - w
	for col in range(max_col + 1):
		var ok = true
		for dx in range(w):
			if Vector2(col + dx, 0) in occupied:
				ok = false
				break
		if ok:
			candidates.append(col)
	if candidates.is_empty():
		return []
	var start = candidates[randi() % candidates.size()]
	var strip = []
	for dx in range(w):
		strip.append(start + dx)
	return strip

func try_spawn_rainbow():
	if rainbow_on_board:
		return
	rounds_since_rainbow += 1
	var chance = rainbow_spawn_chance + int(rounds_since_rainbow / 10) * 0.05
	if randf() < chance:
		var occupied = get_occupied_cells()
		var available = []
		for c in range(grid_cols):
			if Vector2(c, 0) not in occupied and c not in reserved_top_cols:
				available.append(c)
		if available.size() > 0:
			var col = available[randi() % available.size()]
			var rb = RAINBOW_BRICK_SCENE.instantiate()
			rb.position = Vector2(grid_start_x + col * cell_width, grid_start_y)
			brick_container.add_child(rb)
			rainbow_on_board = true

func spawn_boss(info: Dictionary):
	var max_col = grid_cols - info["w"]
	spawn_boss_at(info, randi_range(0, max(0, max_col)))

func spawn_boss_at(info: Dictionary, col: int):
	var boss = BOSS_BRICK_SCENE.instantiate()
	boss.grid_width = info["w"]
	boss.grid_height = info["h"]
	if info.get("is_final", false):
		boss.is_final_boss = true
		boss.health = info.get("health_override", 1000)
		boss.max_health = boss.health
		boss.moves_every_other = info.get("moves_every_other", false)
		boss.guardian_spawn_enabled = info.get("guardians", false)
	elif info.get("is_elite", false):
		boss.is_elite = true
		boss.health = current_round
		boss.max_health = current_round
		# Give elites a shield equal to their HP
		boss.has_shield = true
		boss.shield_hp = current_round
		boss.shield_max = current_round
	else:
		boss.health = current_round * info.get("hp_mult", 2)
		boss.max_health = boss.health
	if info["shield"] > 0:
		boss.has_shield = true
		boss.shield_hp = info["shield"]
		boss.shield_max = info["shield"]
	var x = grid_start_x + col * cell_width + (info["w"] - 1) * cell_width / 2.0
	var y = grid_start_y + (info["h"] - 1) * cell_height / 2.0
	boss.position = Vector2(x, y)
	brick_container.add_child(boss)

# ---- SLIDE & DROP ----

func start_slide_existing():
	is_sliding = true
	slide_progress = 0.0
	for brick in brick_container.get_children():
		if brick.has_method("should_move_this_turn"):
			if not brick.should_move_this_turn():
				continue
		brick.set_meta("slide_from", brick.position.y)
		brick.set_meta("slide_to", brick.position.y + cell_height)
	for orb in orb_container.get_children():
		orb.set_meta("slide_from", orb.position.y)
		orb.set_meta("slide_to", orb.position.y + cell_height)

func finish_slide():
	for brick in brick_container.get_children():
		if brick.has_meta("slide_from"):
			brick.remove_meta("slide_from")
		if brick.has_meta("slide_to"):
			brick.remove_meta("slide_to")
		var row = round((brick.position.y - grid_start_y) / cell_height)
		if row >= death_row:
			game_over()
			return
	for orb in orb_container.get_children():
		if orb.has_meta("slide_from"):
			orb.remove_meta("slide_from")
		if orb.has_meta("slide_to"):
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
	dropping_bricks.clear()
	dropping_orbs.clear()
	for brick in brick_container.get_children():
		var row = round((brick.position.y - grid_start_y) / cell_height)
		if row == 0:
			var col = round((brick.position.x - grid_start_x) / cell_width)
			dropping_bricks.append({"brick": brick, "from_y": brick.position.y, "to_y": brick.position.y + cell_height, "has_neighbor_below": occupied_at_row2.has(col)})
	for orb in orb_container.get_children():
		var row = round((orb.position.y - grid_start_y) / cell_height)
		if row == 0:
			var col = round((orb.position.x - grid_start_x) / cell_width)
			dropping_orbs.append({"orb": orb, "from_y": orb.position.y, "to_y": orb.position.y + cell_height, "has_neighbor_below": occupied_at_row2.has(col)})
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
	sound_manager.play_reload()
	match active_powerup:
		ActivePowerup.NONE: launcher.set_type(0)
		ActivePowerup.EXPLOSIVE: launcher.set_type(1)
		ActivePowerup.RAILGUN: launcher.set_type(2)
		ActivePowerup.BURN: launcher.set_type(3)

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
		var dist_val = randf_range(8, 22)
		var target_pos = Vector2(cos(angle) * dist_val, -randf_range(2, 8))
		var tween = p.create_tween()
		tween.set_parallel(true)
		tween.tween_property(p, "position", target_pos, 0.25).set_ease(Tween.EASE_OUT)
		tween.tween_property(p, "modulate:a", 0.0, 0.25)
		tween.chain().tween_callback(p.queue_free)
	get_tree().create_timer(0.3).timeout.connect(func():
		if is_instance_valid(dust):
			dust.queue_free()
	)

# ---- SPAWNING ----

func spawn_round_bricks_at_row0() -> Array:
	var spawned = []
	if not game_active:
		return spawned
	var occupied = get_occupied_cells()
	var brick_count = randi_range(2, 5)
	var columns = []
	var attempts = 0
	while columns.size() < brick_count and attempts < 20:
		var col = randi_range(0, grid_cols - 1)
		if col not in columns and Vector2(col, 0) not in occupied and col not in reserved_top_cols:
			columns.append(col)
		attempts += 1
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
		if Vector2(c, 0) not in occupied and c not in reserved_top_cols:
			available.append(c)
	if available.size() > 0:
		var col = available[randi() % available.size()]
		var orb = AMMO_ORB_SCENE.instantiate()
		orb.position = Vector2(grid_start_x + col * cell_width, grid_start_y)
		orb_container.add_child(orb)
		spawned.append(orb)
		# Ammo magnet: chance for bonus orb
		var magnet_chance = Progression.get_extra_orb_chance()
		if magnet_chance > 0 and randf() < magnet_chance:
			available.erase(col)
			if available.size() > 0:
				var col2 = available[randi() % available.size()]
				var orb2 = AMMO_ORB_SCENE.instantiate()
				orb2.position = Vector2(grid_start_x + col2 * cell_width, grid_start_y)
				orb_container.add_child(orb2)
				spawned.append(orb2)
	return spawned

func get_occupied_cells() -> Array:
	var occupied = []
	for brick in brick_container.get_children():
		if brick.has_method("update_size"):
			var center_col = round((brick.position.x - grid_start_x) / cell_width)
			var center_row = round((brick.position.y - grid_start_y) / cell_height)
			var half_w = (brick.grid_width - 1) / 2.0
			var half_h = (brick.grid_height - 1) / 2.0
			var start_col = int(center_col - half_w)
			var start_row = int(center_row - half_h)
			for dx in range(brick.grid_width):
				for dy in range(brick.grid_height):
					occupied.append(Vector2(start_col + dx, start_row + dy))
		else:
			var col = round((brick.position.x - grid_start_x) / cell_width)
			var row = round((brick.position.y - grid_start_y) / cell_height)
			occupied.append(Vector2(col, row))
	for orb in orb_container.get_children():
		var col = round((orb.position.x - grid_start_x) / cell_width)
		var row = round((orb.position.y - grid_start_y) / cell_height)
		occupied.append(Vector2(col, row))
	return occupied

# ---- HUD & SCORE ----

func spawn_ammo_popup(count: int):
	var tier = min(count, 5)
	var label = Label.new()
	label.text = "+%d" % count
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(launch_point.x - 40, launch_point.y - 30)
	var sizes = [16, 22, 28, 36, 44]
	label.add_theme_font_size_override("font_size", sizes[tier - 1])
	var colors = [Color(0.4, 0.8, 0.5), Color(0.3, 0.9, 0.4), Color(0.95, 0.8, 0.2), Color(1.0, 0.5, 0.15), Color(1.0, 0.2, 0.3)]
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

func spawn_modifier_popup(text: String, color: Color):
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(155, launch_point.y - 50)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	var tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 40, 1.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 1.2).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)

func spawn_score_popup(pos: Vector2, points: int):
	var label = Label.new()
	var display_points = points * max(1, combo_count)
	label.text = "+%d" % display_points
	label.position = pos + Vector2(-15, -10)
	label.add_theme_font_size_override("font_size", 11 + min(combo_count, 5) * 2)

	# Color based on combo
	var col: Color
	if combo_count >= 7: col = Color(1.0, 0.3, 0.2)
	elif combo_count >= 5: col = Color(1.0, 0.5, 0.15)
	elif combo_count >= 3: col = Color(0.95, 0.8, 0.2)
	else: col = Color(1, 1, 1, 0.8)
	label.add_theme_color_override("font_color", col)

	add_child(label)
	var tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 35, 0.7).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_ease(Tween.EASE_IN)
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
	var multiplied = points * max(1, combo_count)
	score += multiplied
	pending_xp += multiplied
	update_score_display()
	update_xp_preview()

func update_score_display():
	score_label.text = "%04d" % score if score < 10000 else str(score)
	if score >= 1000:
		score_label.add_theme_color_override("font_color", UITheme.ROSE)
	elif score >= 500:
		score_label.add_theme_color_override("font_color", UITheme.AMBER)
	elif score >= 100:
		score_label.add_theme_color_override("font_color", UITheme.CYAN)
	else:
		score_label.add_theme_color_override("font_color", UITheme.LIME)

func update_xp_preview():
	if not xp_preview_fill or not xp_bar_fill:
		return
	var bar_start = 60.0
	var bar_width = 240.0
	var xp_needed = Progression.xp_for_current_level()
	var current_ratio = float(Progression.xp) / max(xp_needed, 1)
	var preview_ratio = clamp(float(Progression.xp + pending_xp) / max(xp_needed, 1), 0.0, 1.0)

	xp_preview_fill.offset_left = bar_start + current_ratio * bar_width
	xp_preview_fill.offset_right = bar_start + preview_ratio * bar_width
	xp_preview_fill.visible = pending_xp > 0

func update_hud():
	ammo_label.text = "× %d" % (ammo + bonus_ammo)
	round_label.text = "%02d" % current_round
	high_score_label.text = "SCORE · BEST %d" % high_score
	update_score_display()
	# XP display
	if xp_bar_fill and xp_text and level_label and sp_label:
		var progress = Progression.xp_progress()
		xp_bar_fill.offset_right = 60.0 + progress * 240.0
		xp_text.text = "%d / %d XP" % [Progression.xp, Progression.xp_for_current_level()]
		level_label.text = "%d" % Progression.level
		# Update SP prefix and numeric label separately
		if $HUD.has_node("SPPrefix"):
			$HUD.get_node("SPPrefix").add_theme_color_override("font_color", UITheme.TEXT_MUTE)
		if Progression.skill_points > 0:
			$HUD.get_node("SPLabel").add_theme_color_override("font_color", UITheme.LIME)
		else:
			$HUD.get_node("SPLabel").add_theme_color_override("font_color", UITheme.TEXT_MUTE)
		$HUD.get_node("SPLabel").text = "%d" % Progression.skill_points

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

func spawn_brick_particles_directional(pos: Vector2, color: Color, hit_dir: Vector2):
	add_shake(3.0)
	if not railgun_active:
		sound_manager.play_destroy()
	var particles = Node2D.new()
	particles.position = pos
	particle_container.add_child(particles)

	for i in range(10):
		var p = ColorRect.new()
		var s = randf_range(2, 7)
		p.size = Vector2(s, s)
		p.position = Vector2(-s/2, -s/2)
		p.color = color.lightened(randf_range(-0.1, 0.15))
		particles.add_child(p)

		# Directional: particles fly mostly in the hit direction with spread
		var base_angle = hit_dir.angle()
		var spread = randf_range(-0.8, 0.8)
		var angle = base_angle + spread
		var dist = randf_range(15, 55)
		var target_pos = Vector2(cos(angle) * dist, sin(angle) * dist)

		var tween = p.create_tween()
		tween.set_parallel(true)
		tween.tween_property(p, "position", target_pos, 0.35).set_ease(Tween.EASE_OUT)
		tween.tween_property(p, "modulate:a", 0.0, 0.35)
		# Slight rotation for debris feel
		tween.tween_property(p, "rotation", randf_range(-2, 2), 0.35)
		tween.chain().tween_callback(p.queue_free)

	get_tree().create_timer(0.4).timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)

func spawn_brick_particles(pos: Vector2, color: Color):
	spawn_brick_particles_directional(pos, color, Vector2.DOWN)

# Combo tracking
var combo_count: int = 0
var combo_timer: float = 0.0
var combo_timeout: float = 1.2  # seconds between kills to maintain combo
var combo_label: Label = null
var combo_bar: Node2D = null
var combo_slow_timer: float = 0.0

func _process(delta):
	# Re-run trajectory each frame while aiming so it tracks moving/rotating bricks
	if is_aiming and not is_firing and game_active and not is_sliding and not is_dropping:
		update_aim_line(last_aim_pos)

	# Combo timer decay (supports temporary slow-down when bricks are hit)
	if combo_timer > 0:
		var slow_ratio = clamp(combo_slow_timer / 0.1, 0.0, 1.0)
		var decay_rate = lerp(1.0, 0.2, slow_ratio)
		combo_timer -= delta * decay_rate
		combo_slow_timer = max(0, combo_slow_timer - delta * 0.5)
		if combo_bar:
			combo_bar.visible = true
			combo_bar.queue_redraw()
		if combo_timer <= 0:
			combo_count = 0
			if combo_bar:
				combo_bar.visible = false
	elif combo_bar and combo_bar.visible:
		combo_bar.visible = false

func on_brick_hit():
	if combo_count >= 2:
		combo_slow_timer = 0.1

func on_brick_destroyed():
	combo_count += 1
	combo_timer = combo_timeout

	if combo_count >= 5:
		# Screen flash
		spawn_screen_flash()
		# Combo text
		spawn_combo_text(combo_count)
	# Combo sound — pitches up a half-step per combo level
	if combo_count >= 5 and sound_manager:
		sound_manager.play_combo(combo_count)

	# Check if board is clear
	call_deferred("_check_board_clear_visual")

func _is_board_clear() -> bool:
	for b in brick_container.get_children():
		if not is_instance_valid(b):
			continue
		if "is_dying" in b and b.is_dying:
			continue
		return false
	for o in orb_container.get_children():
		if not is_instance_valid(o):
			continue
		if "is_dying" in o and o.is_dying:
			continue
		return false
	return true

func _check_board_clear_visual():
	if board_clear_played or not is_firing:
		return
	if not _is_board_clear():
		return
	board_clear_played = true
	play_board_clear()
	# Kill all balls so the round ends without waiting for them to drift back
	for ball in ball_container.get_children():
		if is_instance_valid(ball):
			ball.queue_free()
	# Brief delay so the player sees the celebration before the next round
	var t = create_tween()
	t.tween_interval(0.55)
	t.tween_callback(func():
		if is_firing:
			end_round()
	)

func play_board_clear():
	var rect = ColorRect.new()
	var mat = ShaderMaterial.new()
	mat.shader = BOARD_CLEAR_SHADER
	mat.set_shader_parameter("progress", 0.0)
	mat.set_shader_parameter("center", Vector2(0.5, 0.5))
	rect.material = mat
	rect.color = Color(1, 1, 1, 1)
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.z_index = 100
	$HUD.add_child(rect)
	await get_tree().process_frame
	var sz = rect.size
	if sz.x > 0 and sz.y > 0:
		mat.set_shader_parameter("aspect", sz.x / sz.y)

	add_shake(6.0)
	if sound_manager:
		sound_manager.play_combo(8)

	var tween = create_tween()
	tween.tween_method(func(p: float):
		if is_instance_valid(rect):
			mat.set_shader_parameter("progress", p)
	, 0.0, 1.0, 1.1)
	tween.tween_callback(rect.queue_free)

	# Big celebratory text
	var label = Label.new()
	label.text = "BOARD CLEAR!"
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 6)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = false
	label.anchor_left = 0.0
	label.anchor_right = 1.0
	label.anchor_top = 0.4
	label.anchor_bottom = 0.4
	label.offset_left = 0
	label.offset_right = 0
	label.offset_top = -30
	label.offset_bottom = 30
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 101
	label.modulate.a = 0.0
	$HUD.add_child(label)
	# Pivot at center so the scale tween doesn't push it off-screen
	label.pivot_offset = label.size * 0.5
	var ltween = create_tween()
	ltween.set_parallel(true)
	ltween.tween_property(label, "modulate:a", 1.0, 0.15)
	ltween.tween_property(label, "scale", Vector2(1.3, 1.3), 0.7).from(Vector2(0.6, 0.6)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ltween.chain().tween_property(label, "modulate:a", 0.0, 0.4)
	ltween.chain().tween_callback(label.queue_free)


func check_early_round_end():
	# Only consider early end while firing
	if not is_firing:
		return
	# Only if we have a large amount of ammo
	if (ammo + bonus_ammo) < 50:
		return
	# If no bricks or pickups remain, force balls to return and end the round
	if brick_container.get_child_count() == 0 and orb_container.get_child_count() == 0:
		for ball in ball_container.get_children():
			if is_instance_valid(ball):
				ball.queue_free()
		balls_in_play = 0
		is_spawning = false
		balls_to_spawn = 0
		end_round()

func spawn_screen_flash():
	var flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0.15)
	flash.anchors_preset = 15
	flash.anchor_right = 1.0
	flash.anchor_bottom = 1.0
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(flash)
	var tween = flash.create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.15)
	tween.tween_callback(flash.queue_free)

func _draw_combo_bar():
	if combo_count < 2:
		return
	var bar_width = arena_right - arena_left
	var bar_height = 4.0
	var ratio = combo_timer / combo_timeout
	var bar_y = 0.0

	# Background
	combo_bar.draw_rect(Rect2(arena_left, bar_y, bar_width, bar_height), Color(0.2, 0.22, 0.25, 0.8))

	# Fill
	var fill_width = bar_width * ratio
	var bar_color: Color
	if combo_count >= 7: bar_color = Color(1.0, 0.3, 0.15)
	elif combo_count >= 5: bar_color = Color(1.0, 0.6, 0.15)
	elif combo_count >= 3: bar_color = Color(0.95, 0.8, 0.25)
	else: bar_color = Color(0.7, 0.7, 0.7)
	combo_bar.draw_rect(Rect2(arena_left, bar_y, fill_width, bar_height), bar_color)

	# Flame tip
	if ratio > 0.05:
		var tip_x = arena_left + fill_width
		var flame_flicker = sin(Time.get_ticks_msec() * 0.015) * 2
		combo_bar.draw_circle(Vector2(tip_x, bar_y + bar_height / 2 + flame_flicker), 4, Color(1.0, 0.5, 0.1, 0.6))
		combo_bar.draw_circle(Vector2(tip_x, bar_y + bar_height / 2), 2.5, Color(1.0, 0.8, 0.3, 0.8))

	# Multiplier text - centered above the bar, scales with combo
	var font_size = 14 + min(combo_count, 8) * 3
	var text = "%dx" % combo_count
	var text_x = arena_left
	var text_y = bar_y - 6
	# Glow behind text
	combo_bar.draw_string(ThemeDB.fallback_font, Vector2(text_x + 1, text_y + 1), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0, 0, 0, 0.4))
	combo_bar.draw_string(ThemeDB.fallback_font, Vector2(text_x, text_y), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, bar_color)

func spawn_combo_text(combo: int):
	# Reuse single label — remove old one
	if combo_label and is_instance_valid(combo_label):
		combo_label.queue_free()

	combo_label = Label.new()
	if combo >= 10:
		combo_label.text = "ULTRA x%d!" % combo
	elif combo >= 7:
		combo_label.text = "MEGA x%d!" % combo
	elif combo >= 5:
		combo_label.text = "COMBO x%d!" % combo
	else:
		combo_label.text = "x%d" % combo
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.position = Vector2(120, 250)

	var size = min(18 + combo * 3, 42)
	combo_label.add_theme_font_size_override("font_size", size)

	var col: Color
	if combo >= 10: col = Color(1.0, 0.2, 0.3)
	elif combo >= 7: col = Color(1.0, 0.5, 0.15)
	elif combo >= 5: col = Color(0.95, 0.8, 0.2)
	else: col = Color(1, 1, 1)
	combo_label.add_theme_color_override("font_color", col)
	combo_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	combo_label.add_theme_constant_override("shadow_offset_x", 2)
	combo_label.add_theme_constant_override("shadow_offset_y", 2)

	add_child(combo_label)

	var tween = combo_label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(combo_label, "position:y", combo_label.position.y - 30, 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(combo_label, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	if combo >= 5:
		combo_label.scale = Vector2(1.4, 1.4)
		tween.tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(func():
		if is_instance_valid(combo_label):
			combo_label.queue_free()
			combo_label = null
	)
