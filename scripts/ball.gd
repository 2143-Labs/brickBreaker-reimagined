extends CharacterBody2D

signal ball_returned
signal ball_landed(x_pos: float)

var direction: Vector2 = Vector2.ZERO
var speed: float = 800.0
var damage: int = 1
var damage_multiplier: float = 1.0
var is_active: bool = true
var launched: bool = false
var is_powered: bool = false  # red tint for 2x damage round
var applies_burn: bool = false  # if true this ball will add burn stacks to bricks it hits

# Stuck detection
var wall_bounce_count: int = 0
var last_brick_hit_time: float = 0.0
var time_alive: float = 0.0
var stuck_threshold: float = 1.5  # seconds of only wall bounces = stuck
var last_wall_bounce_time: float = 0.0

func _ready():
    add_to_group("balls")
    queue_redraw()
func _draw():
    if applies_burn:
        # Burn ball visual (orange glow)
        draw_circle(Vector2.ZERO, 12, Color(1.0, 0.5, 0.15, 0.25))
        draw_circle(Vector2.ZERO, 9, Color(1.0, 0.55, 0.2))
    elif is_powered:
        draw_circle(Vector2.ZERO, 10, Color(0.9, 0.2, 0.15, 0.25))
        draw_circle(Vector2.ZERO, 8, Color(0.85, 0.3, 0.25))
    else:
        draw_circle(Vector2.ZERO, 8, Color(0.3, 0.55, 0.95))

func _physics_process(delta):
    if not launched or not is_active:
        return

    time_alive += delta

    velocity = direction * speed
    var collision = move_and_collide(velocity * delta)

    if collision:
        direction = direction.bounce(collision.get_normal())
        var collider = collision.get_collider()
        if collider.has_method("take_damage"):
            collider.take_damage(int(damage * damage_multiplier))
            # Apply burn stack if this ball carries the burn modifier
            if applies_burn and collider.has_method("add_burn_stack"):
                collider.add_burn_stack()
            last_brick_hit_time = time_alive
            wall_bounce_count = 0
            var manager = get_tree().get_first_node_in_group("game_manager")
            if manager and manager.sound_manager:
                manager.sound_manager.play_hit()
        else:
            # Wall bounce
            wall_bounce_count += 1
            last_wall_bounce_time = time_alive
            var manager = get_tree().get_first_node_in_group("game_manager")
            if manager and manager.sound_manager:
                manager.sound_manager.play_bounce()

    # Stuck detection: if we haven't hit a brick in stuck_threshold seconds
    # and have bounced off walls multiple times, nudge the ball
    if time_alive - last_brick_hit_time > stuck_threshold and wall_bounce_count > 4:
        unstick()

    if position.y > 540:
        is_active = false
        ball_landed.emit(position.x)
        ball_returned.emit()
        queue_free()
func unstick():
    # Force a strong downward angle to escape
    if abs(direction.y) < 0.3:
        direction.y = -0.5 if direction.y < 0 else 0.5
        direction = direction.normalized()
    else:
        direction = direction.rotated(randf_range(-0.3, 0.3))
        direction = direction.normalized()
    wall_bounce_count = 0
    last_brick_hit_time = time_alive

func launch(dir: Vector2):
    direction = dir
    launched = true