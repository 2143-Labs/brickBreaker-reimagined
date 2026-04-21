extends CharacterBody2D

signal ball_returned
signal ball_landed(x_pos: float)
var direction: Vector2 = Vector2.ZERO
var speed: float = 800.0
var damage: int = 1
var damage_multiplier: float = 1.0
var is_active: bool = true
var launched: bool = false

func _ready():
    add_to_group("balls")
    queue_redraw()

func _draw():
    draw_circle(Vector2.ZERO, 8, Color(0.3, 0.55, 0.95))
func _physics_process(delta):
    if not launched or not is_active:
        return

    velocity = direction * speed
    var collision = move_and_collide(velocity * delta)

    if collision:
        direction = direction.bounce(collision.get_normal())
        var collider = collision.get_collider()
        if collider.has_method("take_damage"):
            collider.take_damage(int(damage * damage_multiplier))

    if position.y > 540:
        is_active = false
        ball_landed.emit(position.x)
        ball_returned.emit()
        queue_free()

func launch(dir: Vector2):
    direction = dir
    launched = true