extends StaticBody2D

var health: int = 1
var max_health: int = 1
var rainbow_time: float = 0.0

@onready var sprite = $Sprite
@onready var health_label = $HealthLabel

func _ready():
    update_display()

func _process(delta):
    rainbow_time += delta * 2.0
    if sprite:
        var hue = fmod(rainbow_time * 0.3, 1.0)
        sprite.color = Color.from_hsv(hue, 0.6, 0.95)
    queue_redraw()
func _draw():
    var sparkle_color = Color(1, 1, 1, 0.4 + 0.3 * sin(rainbow_time * 5))
    draw_circle(Vector2(10 * sin(rainbow_time * 3), 8 * cos(rainbow_time * 4)), 2, sparkle_color)
    draw_circle(Vector2(-8 * cos(rainbow_time * 2.5), -6 * sin(rainbow_time * 3.5)), 2, sparkle_color)

func take_damage(amount: int, _hit_dir: Vector2 = Vector2.DOWN, _is_special: bool = false):
    health -= amount
    if health <= 0:
        destroy()

func apply_explosion_crack(_ring: int):
    pass

func update_display():
    if health_label:
        health_label.text = "?"
        health_label.add_theme_color_override("font_color", Color(1, 1, 1))
        health_label.add_theme_font_size_override("font_size", 18)

func destroy():
    var manager = get_tree().get_first_node_in_group("game_manager")
    if manager:
        manager.add_score(5)
        if sprite:
            for i in range(6):
                var hue = float(i) / 6.0
                manager.spawn_brick_particles(global_position, Color.from_hsv(hue, 0.7, 0.95))
        manager.on_rainbow_brick_destroyed(global_position)
    queue_free()