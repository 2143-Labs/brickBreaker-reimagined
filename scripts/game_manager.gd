extends Node2D

const BRICK_SCENE = preload("res://scenes/brick.tscn")
const BALL_SCENE = preload("res://scenes/ball.tscn")

@onready var brick_container = $BrickContainer
@onready var ball_container = $BallContainer
@onready var aim_line = $AimLine
@onready var ammo_label = $HUD/AmmoLabel
@onready var round_label = $HUD/RoundLabel
@onready var floor_area = $FloorArea
@onready var arena_border = $ArenaBorder

var current_round: int = 1
var ammo: int = 1
var bonus_ammo: int = 0
var is_aiming: bool = false
var is_firing: bool = false
var aim_start: Vector2
var fire_direction: Vector2
var balls_in_play: int = 0
var launch_point: Vector2 = Vector2(195, 790)
var time_scale: float = 1.0
var preview_ball: Node2D = null

# Grid settings
var grid_cols: int = 9
var grid_start_x: float = 30.0
var grid_start_y: float = 80.0
var cell_width: float = 42.0
var cell_height: float = 30.0

# Arena bounds
var arena_left: float = 5.0
var arena_right: float = 385.0
var arena_top: float = 5.0
var arena_bottom: float = 810.0

func _ready():
    aim_start = launch_point
    aim_line.default_color = Color(0.9, 0.2, 0.2, 0.8)
    aim_line.width = 2.0
    spawn_round_bricks()
    update_hud()
    create_preview_ball()
    queue_redraw()

func _draw():
    # Draw arena border
    var border_color = Color(0.3, 0.3, 0.35, 1.0)
    var thickness = 3.0
    # Left
    draw_line(Vector2(arena_left, arena_top), Vector2(arena_left, arena_bottom), border_color, thickness)
    # Right
    draw_line(Vector2(arena_right, arena_top), Vector2(arena_right, arena_bottom), border_color, thickness)
    # Top
    draw_line(Vector2(arena_left, arena_top), Vector2(arena_right, arena_top), border_color, thickness)
    # Bottom (floor line)
    draw_line(Vector2(arena_left, arena_bottom), Vector2(arena_right, arena_bottom), Color(0.3, 0.3, 0.35, 0.4), 1.0)
    # Launch point indicator
    draw_circle(launch_point, 4, Color(0.9, 0.2, 0.2, 0.5))

func create_preview_ball():
    if preview_ball:
        preview_ball.queue_free()
    preview_ball = Node2D.new()
    preview_ball.position = launch_point
    preview_ball.set_script(null)
    add_child(preview_ball)
    preview_ball.draw.connect(func(): preview_ball.draw_circle(Vector2.ZERO, 8, Color(0.1, 0.5, 0.95, 0.6)))
    preview_ball.queue_redraw()

func _input(event):
    if is_firing:
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
    # Dotted line effect: multiple short segments
    var seg_length = 10.0
    var gap_length = 6.0
    var total_dist = 400.0
    var pos = launch_point
    var traveled = 0.0
    aim_line.add_point(pos)
    while traveled < total_dist:
        pos = pos + direction * seg_length
        traveled += seg_length
        aim_line.add_point(pos)
        pos = pos + direction * gap_length
        traveled += gap_length
        aim_line.add_point(pos)

func start_firing():
    is_firing = true
    balls_in_play = 0
    if preview_ball:
        preview_ball.visible = false
    var total = ammo + bonus_ammo
    for i in range(total):
        get_tree().create_timer(i * 0.08).timeout.connect(func(): launch_ball())
func launch_ball():
    var ball = BALL_SCENE.instantiate()
    ball.position = launch_point
    ball.speed = 500.0
    ball.ball_returned.connect(_on_ball_returned)
    ball_container.add_child(ball)
    ball.launch(fire_direction)
    balls_in_play += 1

func _on_ball_returned():
    balls_in_play -= 1
    if balls_in_play <= 0:
        end_round()

func end_round():
    is_firing = false
    current_round += 1
    move_bricks_down()
    spawn_round_bricks()
    update_hud()
    if preview_ball:
        preview_ball.visible = true

func move_bricks_down():
    for brick in brick_container.get_children():
        brick.position.y += cell_height

func spawn_round_bricks():
    var brick_count = randi_range(3, grid_cols)
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

func update_hud():
    ammo_label.text = "Ammo: %d" % (ammo + bonus_ammo)
    round_label.text = "Round: %d" % current_round
func collect_ammo_orb():
    bonus_ammo += 1
    update_hud()