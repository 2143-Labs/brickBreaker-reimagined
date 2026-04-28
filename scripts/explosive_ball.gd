extends CharacterBody2D

signal ball_returned(p_id: int)
signal ball_landed(x_pos: float, p_id: int)

var direction: Vector2 = Vector2.ZERO
var speed: float = 800.0
var damage: int = 1
var damage_multiplier: float = 1.0
var is_active: bool = true
var launched: bool = false
var player_id: int = 1

var explosion_radius: float = 110.0
var pulse_time: float = 0.0

func _ready():
	add_to_group("balls")
	explosion_radius = 110.0 * Progression.get_explosion_radius_mult()
	
	if MP.is_multiplayer:
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
	var pulse = 0.5 + 0.5 * sin(pulse_time * 8.0)
	var glow_size = 12 + pulse * 4
	draw_circle(Vector2.ZERO, glow_size, Color(1.0, 0.4, 0.1, 0.15 + pulse * 0.1))
	var inner = Color(1.0, 0.5, 0.15) if player_id == 1 else Color(1.0, 0.2, 0.4)
	draw_circle(Vector2.ZERO, 10, inner)
	draw_circle(Vector2.ZERO, 6, Color(1.0, 0.8, 0.3))
	draw_circle(Vector2.ZERO, 3, Color(1, 1, 1, 0.8))

func _process(delta):
	if not is_multiplayer_authority():
		pulse_time += delta
		queue_redraw()

func _physics_process(delta):
	if not launched or not is_active:
		return

	pulse_time += delta
	queue_redraw()

	velocity = direction * speed
	var collision = move_and_collide(velocity * delta)

	if collision:
		direction = direction.bounce(collision.get_normal())
		var collider = collision.get_collider()
		if collider.has_method("take_damage"):
			explode()
			return

	if position.y > 540:
		is_active = false
		ball_landed.emit(position.x, player_id)
		ball_returned.emit(player_id)
		queue_free()

func launch(dir: Vector2):
	direction = dir
	launched = true

func explode():
	if not is_active: return
	is_active = false
	var manager = get_tree().get_first_node_in_group("game_manager")
	if manager:
		manager.do_explosion(global_position, explosion_radius)
	ball_landed.emit(position.x, player_id) # Added player_id
	ball_returned.emit(player_id)           # Added player_id
	queue_free()

# ... also replace the out-of-bounds logic in _physics_process ...
	if position.y > 540:
		is_active = false
		ball_landed.emit(position.x, player_id)
		ball_returned.emit(player_id)
		queue_free()
