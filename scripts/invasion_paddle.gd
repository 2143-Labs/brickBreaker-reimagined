extends Node2D

signal launcher_hit(damage: int)
signal wave_cleared
signal invasion_over

const ARENA_LEFT  := 13.0
const ARENA_RIGHT := 377.0
const PADDLE_Y    := 480.0 
const PADDLE_SPEED := 500.0

var paddle_body: CharacterBody2D
var brick_container: Node2D
var _bricks: Array[Node2D] = []
var _active := false
var _wave := 0

# Swarm movement
const DOWN_SPEED := 8.0
const SPEED_RAMP := 1.02
var _distance_moved := 0.0

# Shooting logic
const SHOOT_MIN  := 3.0
const SHOOT_MAX  := 7.0
const PROJ_SPEED := 220.0
var _shoot_timer := 0.0
var _projectiles: Array[Node2D] = []

func _ready():
	_setup_paddle_physics()

func _setup_paddle_physics():
	paddle_body = CharacterBody2D.new()
	paddle_body.name = "PaddleBody"
	paddle_body.position = Vector2(195, PADDLE_Y)
	paddle_body.add_to_group("paddle")
	
	# Visuals
	var visual = ColorRect.new()
	visual.size = Vector2(80, 14)
	visual.position = Vector2(-40, -7)
	visual.color = Color(0.2, 0.7, 1.0)
	paddle_body.add_child(visual)
	
	# Collision
	var col_shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(80, 14)
	col_shape.shape = rect
	paddle_body.add_child(col_shape)
	
	# IMPORTANT: Paddle is on Layer 2.
	paddle_body.collision_layer = 2
	paddle_body.collision_mask = 0 
	
	add_child(paddle_body)

func _physics_process(delta):
	if not _active: return
	
	# Arrow Key Movement
	var move_dir = 0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_action_pressed("ui_left"):
		move_dir -= 1
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_action_pressed("ui_right"):
		move_dir += 1
		
	paddle_body.velocity = Vector2(move_dir * PADDLE_SPEED, 0)
	paddle_body.move_and_slide()
	
	# Clamp position and lock Y
	paddle_body.position.x = clamp(paddle_body.position.x, ARENA_LEFT + 40, ARENA_RIGHT - 40)
	paddle_body.position.y = PADDLE_Y
	
	_move_swarm(delta)
	_tick_shooting(delta)
	_tick_projectiles(delta)

func _move_swarm(delta: float) -> void:
	var current_speed = DOWN_SPEED * pow(SPEED_RAMP, _wave - 1)
	var move_y = current_speed * delta
	_distance_moved += move_y
	
	for b in _bricks:
		if is_instance_valid(b):
			b.position.y += move_y
			if b.position.y + 18.0 >= PADDLE_Y - 10:
				invasion_over.emit()
				stop()
				return
	
	if _distance_moved >= 38.0:
		_distance_moved -= 38.0
		_spawn_random_row()

func _tick_shooting(delta: float) -> void:
	_shoot_timer -= delta
	if _shoot_timer <= 0:
		_shoot_timer = randf_range(SHOOT_MIN, SHOOT_MAX)
		var b = _bricks.pick_random() if _bricks.size() > 0 else null
		if b: _fire_projectile(b.position)

func _fire_projectile(from: Vector2) -> void:
	var proj = Node2D.new()
	proj.position = from
	var visual = ColorRect.new()
	visual.size = Vector2(6, 12)
	visual.position = Vector2(-3, -6)
	visual.color = Color(1, 0.4, 0.4)
	proj.add_child(visual)
	brick_container.get_parent().add_child(proj)
	_projectiles.append(proj)

func _tick_projectiles(delta: float) -> void:
	var to_remove = []
	for p in _projectiles:
		if not is_instance_valid(p):
			to_remove.append(p)
			continue
		p.position.y += PROJ_SPEED * delta
		if p.position.y > 540:
			launcher_hit.emit(1)
			p.queue_free()
			to_remove.append(p)
	for p in to_remove: _projectiles.erase(p)

func start(container: Node2D, _hud) -> void:
	brick_container = container
	_wave = 0
	_active = true
	_spawn_random_row()

func stop() -> void:
	_active = false

func cleanup() -> void:
	stop()
	for p in _projectiles: if is_instance_valid(p): p.queue_free()
	if is_instance_valid(paddle_body): paddle_body.queue_free()

func _spawn_random_row():
	_wave += 1
	for i in range(randi_range(3, 5)):
		var b = (load("res://scenes/brick.tscn") as PackedScene).instantiate()
		b.position = Vector2(ARENA_LEFT + 26 + (randi()%7)*52, 130 + 19)
		brick_container.add_child(b, true)
		_bricks.append(b)
		b.tree_exited.connect(func(): _bricks.erase(b))
		