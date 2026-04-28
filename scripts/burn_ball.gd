extends CharacterBody2D

signal ball_returned(p_id: int)
signal ball_landed(x_pos: float, p_id: int)

var direction: Vector2 = Vector2.ZERO
var speed: float = 800.0
var is_active: bool = true
var launched: bool = false
var burn_damage: int = 2
var burn_ticks: int = 3
var pulse_time: float = 0.0
var player_id: int = 1

func _ready():
	add_to_group("balls")
	
	if MultiplayerManager.is_multiplayer:
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
	var pulse = 0.5 + 0.5 * sin(pulse_time * 6.0)
	draw_circle(Vector2.ZERO, 10 + pulse * 3, Color(0.9, 0.4, 0.1, 0.15))
	var col = Color(0.95, 0.5, 0.15) if player_id == 1 else Color(0.95, 0.2, 0.3)
	draw_circle(Vector2.ZERO, 8, col)
	draw_circle(Vector2.ZERO, 5, Color(1.0, 0.7, 0.2))
	draw_circle(Vector2.ZERO, 5, Color(1.0, 0.7, 0.2))
	# Small flame particles
	var flame_y = -6 - pulse * 3
	draw_circle(Vector2(randf_range(-3, 3), flame_y), 3, Color(1.0, 0.6, 0.1, 0.5 + pulse * 0.3))

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
			collider.take_damage(1)
			# Corrected method name: add_burn_stack
			if collider.has_method("add_burn_stack"):
				collider.add_burn_stack()
				if collider.has_node("Sprite"):
					var sprite = collider.get_node("Sprite")
					var tween = collider.create_tween()
					tween.tween_property(sprite, "modulate", Color(1.3, 0.8, 0.5), 0.1)
					tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.2)

	if position.y > 540:
		is_active = false
		ball_landed.emit(position.x, player_id) # Added player_id
		ball_returned.emit(player_id)           # Added player_id
		queue_free()
func launch(dir: Vector2):
	direction = dir
	launched = true
