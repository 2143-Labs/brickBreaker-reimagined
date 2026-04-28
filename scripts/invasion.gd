# invasion_manager.gd
extends Node

signal launcher_hit(damage: int)
signal wave_cleared
signal invasion_over

const ARENA_LEFT  := 13.0
const ARENA_RIGHT := 377.0
const CELL_W      := 52.0
const CELL_H      := 38.0
const GRID_COLS   := 7
const START_X     := ARENA_LEFT + CELL_W * 0.5
const START_Y     := 130.0 + CELL_H * 0.5
const DANGER_Y    := 510.0 # arena_bottom

const DOWN_SPEED  := 10.0 # pixels per second
const SPEED_RAMP  := 1.02 # multiplies speed per row spawned

const SHOOT_MIN  := 3.0
const SHOOT_MAX  := 7.0
const PROJ_SPEED := 200.0

var _bricks: Array[Node2D] = []
var _orbs: Array[Node2D] = []
var _wave     := 0
var _active   := false
var _distance_moved := 0.0

var _shoot_timer := 0.0
var _projectiles: Array[Node2D] = []

var brick_container: Node2D
var _game_manager: Node = null

# ── public ────────────────────────────────────────────────────────────────────

func start(container: Node2D, _hud) -> void:
	brick_container = container
	_game_manager = container.get_parent()
	_wave = 0
	_active = true
	_distance_moved = 0.0

	# Initial spawn of 3 rows staggered from the top
	for i in range(3):
		_spawn_row(START_Y + (2 - i) * CELL_H)

func stop() -> void:
	_active = false
	_clear_projectiles()
	_orbs.clear()

# ── spawning ──────────────────────────────────────────────────────────────────

func _spawn_row(y_pos: float = START_Y) -> void:
	_wave += 1

	if not is_instance_valid(_game_manager):
		return

	# Snapshot what exists before spawning
	var before_bricks := {}
	for b in brick_container.get_children():
		before_bricks[b] = true

	var orb_container: Node = _game_manager.get_node("OrbContainer")
	var before_orbs := {}
	for o in orb_container.get_children():
		before_orbs[o] = true

	# Use the game manager's full spawn pipeline
	_game_manager.spawn_round_bricks_at_row0()
	_game_manager.try_spawn_special_bricks()
	_game_manager.try_spawn_rainbow()
	_game_manager.spawn_ammo_orbs_at_row0()

	# Move new bricks to y_pos and track them
	for b in brick_container.get_children():
		if b in before_bricks:
			continue
		b.position.y = y_pos
		_bricks.append(b)
		b.tree_exited.connect(_on_brick_removed.bind(b))

	# Move new orbs to y_pos and track them
	for o in orb_container.get_children():
		if o in before_orbs:
			continue
		o.position.y = y_pos
		_orbs.append(o)
		o.tree_exited.connect(func(): _orbs.erase(o))

# ── movement ──────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not _active:
		return
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
			# Game over check if any brick crosses the danger line
			if b.position.y + 19.0 >= DANGER_Y:
				invasion_over.emit()
				stop()
				return

	for o in _orbs:
		if is_instance_valid(o):
			o.position.y += move_y

	# Exactly every cell height we move down, spawn a new row at the top
	if _distance_moved >= CELL_H:
		_distance_moved -= CELL_H
		_spawn_row()

# ── shooting ──────────────────────────────────────────────────────────────────

func _tick_shooting(delta: float) -> void:
	_shoot_timer -= delta
	if _shoot_timer > 0.0:
		return
	_shoot_timer = randf_range(SHOOT_MIN, SHOOT_MAX)
	var shooter = _pick_shooter()
	if shooter:
		_fire_projectile(shooter.position)

func _pick_shooter() -> Node2D:
	var col_bottom: Dictionary = {}
	for b in _bricks:
		if not is_instance_valid(b):
			continue
		var key := int(round(b.position.x))
		if not col_bottom.has(key) or b.position.y > col_bottom[key].position.y:
			col_bottom[key] = b
	if col_bottom.is_empty():
		return null
	var candidates := col_bottom.values()
	return candidates[randi() % candidates.size()]

func _fire_projectile(from: Vector2) -> void:
	var proj := Node2D.new()
	proj.position = from
	proj.set_meta("vel", Vector2(randf_range(-15.0, 15.0), PROJ_SPEED))

	var dot := ColorRect.new()
	dot.size     = Vector2(7.0, 7.0)
	dot.position = Vector2(-3.5, -3.5)
	dot.color    = Color(1.0, 0.35, 0.35, 1.0)
	proj.add_child(dot)

	brick_container.get_parent().add_child(proj)
	_projectiles.append(proj)

func _tick_projectiles(delta: float) -> void:
	var dead: Array = []
	for proj in _projectiles:
		if not is_instance_valid(proj):
			dead.append(proj)
			continue
		var vel: Vector2 = proj.get_meta("vel")
		proj.position += vel * delta
		if proj.position.x < ARENA_LEFT or proj.position.x > ARENA_RIGHT:
			vel.x *= -1.0
			proj.set_meta("vel", vel)
		if proj.position.y > DANGER_Y + 30.0:
			launcher_hit.emit(1)
			proj.queue_free()
			dead.append(proj)
	for p in dead:
		_projectiles.erase(p)

func _clear_projectiles() -> void:
	for p in _projectiles:
		if is_instance_valid(p):
			p.queue_free()
	_projectiles.clear()

func _on_brick_removed(_brick: Node2D) -> void:
	_bricks = _bricks.filter(func(b): return is_instance_valid(b) and b != _brick)
	if _bricks.is_empty() and _active:
		wave_cleared.emit()
		_distance_moved = 0.0
		_spawn_row()