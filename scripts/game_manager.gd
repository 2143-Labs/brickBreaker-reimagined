extends Node2D

const BRICK_SCENE = preload("res://scenes/brick.tscn")
const BALL_SCENE = preload("res://scenes/ball.tscn")
const AMMO_ORB_SCENE = preload("res://scenes/ammo_orb.tscn")

@onready var brick_container = $BrickContainer
@onready var ball_container = $BallContainer
@onready var aim_line = $AimLine
@onready var ammo_label = $HUD/AmmoLabel
@onready var round_label = $HUD/RoundLabel
@onready var orb_container = $OrbContainer
@onready var speed_button = $HUD/SpeedButton

var current_round: int = 1
var ammo: int = 1
var bonus_ammo: int = 0
var is_aiming: bool = false
var is_firing: bool = false
var fire_direction: Vector2
var balls_in_play: int = 0
var preview_ball: Node2D = null
var game_active: bool = true
var first_ball_returned: bool = false
var next_launch_x: float = 195.0

var speed_levels = [1.0, 2.0, 4.0]
var current_speed_idx: int = 0

var arena_left: float = 13.0
var arena_right: float = 377.0
var arena_top: float = 80.0

var grid_cols: int = 7
var cell_width: float = 52.0
var cell_height: float = 38.0
var max_rows: int = 11

var grid_start_x: float
var grid_start_y: float
var arena_bottom: float
var launch_point: Vector2

func _ready():
    add_to_group("game_manager")
    grid_start_x = arena_left + cell_width / 2.0
    grid_start_y = arena_top + cell_height / 2.0
    arena_bottom = arena_top + max_rows * cell_height
    launch_point = Vector2(195, arena_bottom + 20)
    speed_button.pressed.connect(_on_speed_pressed)

    spawn_round_bricks()
    spawn_ammo_orbs()
    update_hud()
    create_preview_ball()
    queue_redraw()

func _draw():
    var border_color = Color(1, 1, 1, 0.9)
    var thickness = 2.0
    draw_line(Vector2(arena_left, arena_top), Vector2(arena_left, arena_bottom), border_color, thickness)
    draw_line(Vector2(arena_right, arena_top), Vector2(arena_right, arena_bottom), border_color, thickness)
    draw_line(Vector2(arena_left, arena_top), Vector2(arena_right, arena_top), border_color, thickness)
    draw_line(Vector2(arena_left, arena_bottom), Vector2(arena_right, arena_bottom), border_color, thickness)

func _on_speed_pressed():
    current_speed_idx = (current_speed_idx + 1) % speed_levels.size()
    var spd = speed_levels[current_speed_idx]
    Engine.time_scale = spd
    speed_button.text = "%dx" % int(spd)

func create_preview_ball():
    if preview_ball:
        preview_ball.queue_free()
    preview_ball = Node2D.new()
    preview_ball.position = launch_point
    add_child(preview_ball)
    preview_ball.draw.connect(func(): preview_ball.draw_circle(Vector2.ZERO, 8, Color(0.3, 0.55, 0.95, 0.9)))
    preview_ball.queue_redraw()

func update_ammo_label_position():
    ammo_label.offset_left = launch_point.x - 30
    ammo_label.offset_right = launch_point.x + 30
    ammo_label.offset_top = launch_point.y + 12
    ammo_label.offset_bottom = launch_point.y + 35
    ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _input(event):
    if is_firing or not game_active:
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

    if event is InputEventMouseMotion or event is InputEventScreenDrag:
        if is_aiming:
            var aim_pos = event.position if event is InputEventMouseMotion else event.position
            update_aim_line(aim_pos)
func update_aim_line(target: Vector2):
    var direction = (target - launch_point).normalized()
    if direction.y >= -0.1:
        aim_line.clear_points()
        return
    aim_line.clear_points()
    aim_line.add_point(launch_point)
    aim_line.add_point(launch_point + direction * 500)

func start_firing():
    is_firing = true
    balls_in_play = 0
    first_ball_returned = false
    if preview_ball:
        preview_ball.visible = false
    ammo_label.visible = false
    var total = ammo + bonus_ammo
    for i in range(total):
        get_tree().create_timer(i * 0.025).timeout.connect(func(): launch_ball())

func launch_ball():
    var ball = BALL_SCENE.instantiate()
    ball.position = launch_point
    ball.speed = 800.0
    ball.ball_returned.connect(_on_ball_returned)
    ball.ball_landed.connect(_on_ball_landed)
    ball_container.add_child(ball)
    ball.launch(fire_direction)
    balls_in_play += 1
func _on_ball_landed(x_pos: float):
    if not first_ball_returned:
        first_ball_returned = true
        next_launch_x = clamp(x_pos, arena_left + 15, arena_right - 15)

func _on_ball_returned():
    balls_in_play -= 1
    if balls_in_play <= 0:
        end_round()

func end_round():
    is_firing = false
    current_round += 1
    launch_point.x = next_launch_x
    move_bricks_down()
    move_orbs_down()
    spawn_round_bricks()
    spawn_ammo_orbs()
    update_hud()
    update_ammo_label_position()
    ammo_label.visible = true

    if preview_ball:
        preview_ball.position = launch_point
        preview_ball.visible = true

func move_bricks_down():
    for brick in brick_container.get_children():
        brick.position.y += cell_height
        if brick.position.y >= arena_bottom - cell_height / 2.0:
            game_over()
            return

func move_orbs_down():
    for orb in orb_container.get_children():
        orb.position.y += cell_height
        if orb.position.y > arena_bottom:
            orb.queue_free()

func game_over():
    game_active = false
    is_firing = true
    Engine.time_scale = 1.0
    round_label.text = "GAME OVER"
    ammo_label.text = "Round %d" % current_round

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

func spawn_round_bricks():
    if not game_active:
        return
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
func spawn_ammo_orbs():
    if not game_active:
        return
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
func update_hud():
    ammo_label.text = "x%d" % (ammo + bonus_ammo)
    round_label.text = "Round %d" % current_round

func collect_ammo_orb():
    bonus_ammo += 1
    update_hud()