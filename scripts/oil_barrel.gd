extends StaticBody2D

var health: int = 3
var max_health: int = 3
var explosion_radius: float = 160.0  # 2x normal explosive
var explosion_damage: int = 30
var burn_stacks: int = 0
@onready var sprite = $Sprite
@onready var health_label = $HealthLabel

var is_dying: bool = false
var last_hit_direction: Vector2 = Vector2.DOWN
var barrel_time: float = 0.0
var warning_overlay: Node2D = null

func _ready():
    update_display()
    warning_overlay = Node2D.new()
    warning_overlay.z_index = 2
    add_child(warning_overlay)
    warning_overlay.draw.connect(_draw_warning)
func _process(delta):
    barrel_time += delta
    # Subtle pulsing when low HP
    if health <= 1 and sprite:
        var pulse = 0.5 + 0.5 * sin(barrel_time * 6)
        sprite.modulate = Color(1.0 + pulse * 0.3, 1.0 - pulse * 0.2, 1.0 - pulse * 0.3, 1)
    if warning_overlay:
        warning_overlay.queue_redraw()

func take_damage(amount: int, hit_dir: Vector2 = Vector2.DOWN, _is_special: bool = false):
    last_hit_direction = hit_dir

    # Multi-side bonus: each unique side hit recently multiplies damage
    var _ms_now = Time.get_ticks_msec()
    var unique_sides = 0
    for s in hit_sides.keys():
        if _ms_now - hit_sides[s] <= _multi_side_window_ms:
            unique_sides += 1
    if unique_sides >= 2:
        amount *= unique_sides
    health -= amount
    update_display()
    if sprite and health > 0:
        var tween = create_tween()
        tween.tween_property(sprite, "modulate", Color(2, 1.5, 1, 1), 0.05)
        tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.1)

    if health <= 0:
        destroy()

func apply_explosion_crack(_ring: int):
    # Chain reaction: explosions trigger this barrel too
    destroy()

func add_burn_stack():
    burn_stacks += 1
func process_burn():
    if burn_stacks > 0:
        take_damage(burn_stacks)
        burn_stacks = int(burn_stacks / 2.0)

func _draw_warning():
    # Hazard symbol on barrel
    var flash = 0.5 + 0.3 * sin(barrel_time * 4)
    # Hazard stripes
    warning_overlay.draw_line(Vector2(-20, -12), Vector2(-14, 12), Color(0.1, 0.1, 0.1, 0.4), 3)
    warning_overlay.draw_line(Vector2(-10, -12), Vector2(-4, 12), Color(0.1, 0.1, 0.1, 0.4), 3)
    warning_overlay.draw_line(Vector2(0, -12), Vector2(6, 12), Color(0.1, 0.1, 0.1, 0.4), 3)
    warning_overlay.draw_line(Vector2(10, -12), Vector2(16, 12), Color(0.1, 0.1, 0.1, 0.4), 3)
    # Explosion icon in center
    warning_overlay.draw_circle(Vector2.ZERO, 6, Color(1.0, 0.3, 0.1, flash * 0.4))
    warning_overlay.draw_circle(Vector2.ZERO, 3, Color(1.0, 0.6, 0.2, flash * 0.6))

func update_display():
    if health_label:
        health_label.text = str(health)
        health_label.add_theme_color_override("font_color", Color(1, 1, 1))
        health_label.add_theme_font_size_override("font_size", 14)
    if sprite:
        sprite.color = Color(0.25, 0.2, 0.18)  # Dark barrel color

func destroy():
    if is_dying: return
    is_dying = true

    var manager = get_tree().get_first_node_in_group("game_manager")
    if manager:
        manager.add_score(5)
        # BIG explosion
        manager.do_oil_barrel_explosion(global_position, explosion_radius, explosion_damage)
    queue_free()

func get_brick_value() -> int:
    return 5