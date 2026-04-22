extends CharacterBody2D

signal ball_returned
signal ball_landed(x_pos: float)

var direction: Vector2 = Vector2.ZERO
var speed: float = 1200.0
var is_active: bool = true
var launched: bool = false
var pierce_trail: Array = []

func _ready():
    add_to_group("balls")
    # Disable physics collision - railgun moves manually
    $CollisionShape2D.disabled = true
    queue_redraw()

func _draw():
    # Bright cyan/white with electric glow
    draw_circle(Vector2.ZERO, 12, Color(0.2, 0.8, 1.0, 0.2))
    draw_circle(Vector2.ZERO, 8, Color(0.3, 0.9, 1.0, 0.6))
    draw_circle(Vector2.ZERO, 5, Color(0.8, 0.95, 1.0))
    draw_circle(Vector2.ZERO, 2, Color(1, 1, 1))

func _physics_process(delta):
    if not launched or not is_active:
        return

    var move_amount = direction * speed * delta
    position += move_amount

    # Check all bricks for overlap within hit radius
    for brick in get_tree().get_first_node_in_group("game_manager").brick_container.get_children():
        if not is_instance_valid(brick):
            continue
        if brick.has_meta("railgun_hit"):
            continue
        var dist = position.distance_to(brick.position)
        # Hit detection radius based on brick size
        var hit_radius = 30.0
        if brick.has_method("update_size"):
            hit_radius = max(brick.grid_width, brick.grid_height) * 26.0
        if dist < hit_radius:
            brick.set_meta("railgun_hit", true)
            if brick.has_method("update_size"):
                # Boss: half current HP
                var dmg = max(1, int(brick.health / 2.0))
                brick.take_damage(dmg)
            else:
                # Normal: instant kill
                brick.take_damage(brick.health)
            var manager = get_tree().get_first_node_in_group("game_manager")
            if manager:
                manager.spawn_railgun_trail(brick.position)

    # Despawn off screen
    if position.y > 600 or position.y < 40 or position.x < -20 or position.x > 410:
        is_active = false
        ball_landed.emit(position.x)
        ball_returned.emit()
        queue_free()

func launch(dir: Vector2):
    direction = dir
    launched = true