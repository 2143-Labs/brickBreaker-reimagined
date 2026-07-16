extends StaticBody2D

var health: int = 1
var max_health: int = 1
var burn_stacks: int = 0
var spin_speed: float = 1.4  # rad/s

@onready var collision_polygon: CollisionPolygon2D = $CollisionPolygon2D
@onready var health_label: Label = $HealthLabel

var is_dying: bool = false
var last_hit_direction: Vector2 = Vector2.DOWN
var hit_flash: float = 0.0

const RADIUS: float = 22.0

func get_color_for_hp(hp: int) -> Color:
    if hp >= 100: return Color(0.55, 0.2, 0.7)
    elif hp >= 50: return Color(0.4, 0.55, 0.9)
    elif hp >= 20: return Color(0.95, 0.65, 0.3)
    elif hp >= 10: return Color(0.93, 0.5, 0.45)
    elif hp >= 5: return Color(0.95, 0.85, 0.4)
    else: return Color(0.6, 0.85, 0.55)

func get_brick_color(ratio: float) -> Color:
    return get_color_for_hp(max_health).lightened((1.0 - ratio) * 0.25)

func _ready():
    add_to_group("triangle_bricks")
    var pts = PackedVector2Array()
    for i in range(3):
        var a = -PI / 2.0 + i * (TAU / 3.0)
        pts.append(Vector2(cos(a), sin(a)) * RADIUS)
    if collision_polygon:
        collision_polygon.polygon = pts
    update_display()
    queue_redraw()

func _process(delta):
    rotation += spin_speed * delta
    if hit_flash > 0.0:
        hit_flash = max(0.0, hit_flash - delta * 4.0)
    if health_label:
        # Keep the HP counter upright while the body spins
        health_label.rotation = -rotation
    queue_redraw()

    # Mouse hover detection for tooltip
    var mouse_pos = get_global_mouse_position()
    var half_size = Vector2(25, 18)
    var hovering = Rect2(position - half_size, half_size * 2).has_point(mouse_pos)
    if hovering != _is_hovered:
        _is_hovered = hovering
        var mgr = get_tree().get_first_node_in_group("game_manager")
        if mgr:
            if hovering:
                mgr.show_brick_tooltip(get_tooltip_text(), mouse_pos + Vector2(10, -25))
            else:
                mgr.hide_brick_tooltip()

func _draw():
    var pts = PackedVector2Array()
    for i in range(3):
        var a = -PI / 2.0 + i * (TAU / 3.0)
        pts.append(Vector2(cos(a), sin(a)) * RADIUS)

    var ratio = clamp(float(health) / max(max_health, 1), 0.0, 1.0)
    var base = get_brick_color(ratio)
    if hit_flash > 0.0:
        base = base.lerp(Color(1, 1, 1), hit_flash * 0.6)

    draw_polygon(pts, PackedColorArray([base, base, base]))

    var outline = pts.duplicate()
    outline.append(pts[0])
    draw_polyline(outline, Color(0.15, 0.12, 0.1, 0.8), 1.5, true)

func take_damage(amount: int, hit_dir: Vector2 = Vector2.DOWN, _is_special: bool = false):
    last_hit_direction = hit_dir
    health -= amount
    hit_flash = 1.0
    update_display()
    if health <= 0:
        destroy()

func add_burn_stack():
    burn_stacks += 1

func process_burn():
    if burn_stacks > 0:
        take_damage(burn_stacks)
        burn_stacks = int(burn_stacks / 2.0)

func apply_explosion_crack(_ring: int):
    take_damage(1)

func update_display():
    if health_label:
        health_label.text = str(max(health, 0))
        health_label.add_theme_color_override("font_color", Color(1, 1, 1))
        health_label.add_theme_font_size_override("font_size", 14)

func destroy():
    if is_dying: return
    is_dying = true
    var manager = get_tree().get_first_node_in_group("game_manager")
    if manager:
        manager.add_score(get_brick_value())
        var ratio = clamp(float(health) / max(max_health, 1), 0.0, 1.0)
        var col = get_brick_color(ratio)
        manager.spawn_brick_particles_directional(global_position, col, last_hit_direction)
        manager.spawn_score_popup(global_position, get_brick_value())
        manager.on_brick_destroyed()
    queue_free()

func get_brick_value() -> int:
    if max_health < 10: return 1
    elif max_health < 50: return 2
    elif max_health < 100: return 3
    elif max_health < 150: return 4
    elif max_health < 200: return 5
    else: return 10
