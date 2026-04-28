extends CharacterBody2D

signal ball_returned
signal ball_landed(x_pos: float)

var direction: Vector2 = Vector2.ZERO
var speed: float = 800.0
var damage: int = 1
var damage_multiplier: float = 1.0
var is_active: bool = true
var launched: bool = false

var explosion_radius: float = 110.0

var pulse_time: float = 0.0

func _ready():
	add_to_group("balls")
	explosion_radius = 110.0 * Progression.get_explosion_radius_mult()
	
	if MultiplayerManager.is_multiplayer:
		var sync = MultiplayerSynchronizer.new()
		sync.name = "BallSync"
		var config = SceneReplicationConfig.new()
		config.add_property(".:position")
		config.property_set_replication_mode(".:position", SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
		sync.replication_config = config
		add_child(sync)
		if not is_multiplayer_authority():
			set_physics_process(false)
			
	queue_redraw()

func _draw():
	var pulse = 0.5 + 0.5 * sin(pulse_time * 8.0)
	var glow_size = 12 + pulse * 4
	draw_circle(Vector2.ZERO, glow_size, Color(1.0, 0.4, 0.1, 0.15 + pulse * 0.1))
	draw_circle(Vector2.ZERO, 10, Color(1.0, 0.5, 0.15))
	draw_circle(Vector2.ZERO, 6, Color(1.0, 0.8, 0.3))
	draw_circle(Vector2.ZERO, 3, Color(1, 1, 1, 0.8))

func _process(delta):
	if MultiplayerManager.is_multiplayer and not is_multiplayer_authority():
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
		ball_landed.emit(position.x)
		ball_returned.emit()
		queue_free()

func launch(dir: Vector2):
	direction = dir
	launched = true

func explode():
	is_active = false
	var manager = get_tree().get_first_node_in_group("game_manager")
	if manager:
		manager.do_explosion(global_position, explosion_radius)
	ball_landed.emit(position.x)
	ball_returned.emit()
	queue_free()