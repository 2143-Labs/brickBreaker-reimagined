extends StaticBody2D

var health: int = 1
var max_health: int = 1
var is_burning: bool = false
var burn_damage: int = 0
var burn_ticks: int = 0

var color_low = Color(0.93, 0.6, 0.5)
var color_high = Color(0.9, 0.35, 0.35)

@onready var sprite = $Sprite
@onready var health_label = $HealthLabel

var crack_level: int = 0
var crack_overlay: Node2D = null

func _ready():
    update_display()
    # Create crack overlay that draws on top of everything
    crack_overlay = Node2D.new()
    crack_overlay.z_index = 1
    add_child(crack_overlay)
    crack_overlay.draw.connect(_draw_cracks)

func take_damage(amount: int):
    health -= amount
    update_display()

    if sprite and health > 0:
        var tween = create_tween()
        tween.tween_property(sprite, "modulate", Color(2, 2, 2, 1), 0.05)
        tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.1)

    if health <= 0:
        destroy()

func apply_explosion_crack(ring: int):
    if ring == 0:
        crack_level = 3
    elif ring == 1:
        crack_level = max(crack_level, 2)
    else:
        crack_level = max(crack_level, 1)

    if crack_overlay:
        crack_overlay.queue_redraw()

func _draw_cracks():
    if crack_level <= 0:
        return

    var hw = 24.0
    var hh = 17.0
    var crack_alpha = 0.3 + crack_level * 0.2
    var crack_width = 1.0 + crack_level * 0.4
    var crack_color = Color(0.1, 0.08, 0.05, crack_alpha)
    # Seed based on position for consistent cracks
    var rng = RandomNumberGenerator.new()
    rng.seed = int(position.x * 100 + position.y * 7)

    var num_cracks = crack_level * 2 + 1

    for i in range(num_cracks):
        var start = Vector2(rng.randf_range(-hw * 0.5, hw * 0.5), rng.randf_range(-hh * 0.5, hh * 0.5))
        var angle = rng.randf_range(0, TAU)
        var length = rng.randf_range(6, 8 + crack_level * 5)
        var end = start + Vector2(cos(angle), sin(angle)) * length
        end.x = clamp(end.x, -hw, hw)
        end.y = clamp(end.y, -hh, hh)
        crack_overlay.draw_line(start, end, crack_color, crack_width)
        # Branch cracks for medium+
        if crack_level >= 2 and rng.randf() > 0.3:
            var b_angle = angle + rng.randf_range(-0.8, 0.8)
            var b_len = length * rng.randf_range(0.3, 0.6)
            var b_end = end + Vector2(cos(b_angle), sin(b_angle)) * b_len
            b_end.x = clamp(b_end.x, -hw, hw)
            b_end.y = clamp(b_end.y, -hh, hh)
            crack_overlay.draw_line(end, b_end, crack_color, crack_width * 0.7)

    # Heavy: center radiating cracks
    if crack_level >= 3:
        for i in range(4):
            var angle = rng.randf_range(0, TAU)
            var length = rng.randf_range(12, 22)
            var end = Vector2(cos(angle), sin(angle)) * length
            end.x = clamp(end.x, -hw, hw)
            end.y = clamp(end.y, -hh, hh)
            crack_overlay.draw_line(Vector2.ZERO, end, crack_color, crack_width * 1.2)

func update_display():
    if health_label:
        health_label.text = str(health)
        health_label.add_theme_color_override("font_color", Color(1, 1, 1))
        health_label.add_theme_font_size_override("font_size", 16)
    if sprite:
        var ratio = clamp(float(health) / max(max_health, 1), 0.0, 1.0)
        sprite.color = color_low.lerp(color_high, ratio)

func apply_burn(dmg: int, ticks: int):
    is_burning = true
    burn_damage = dmg
    burn_ticks = ticks

func process_burn():
    if is_burning and burn_ticks > 0:
        take_damage(burn_damage)
        burn_ticks -= 1
        if burn_ticks <= 0:
            is_burning = false

func destroy():
    var manager = get_tree().get_first_node_in_group("game_manager")
    if manager:
        var points = get_brick_value()
        manager.add_score(points)
        if sprite:
            manager.spawn_brick_particles(global_position, sprite.color)
    queue_free()

func get_brick_value() -> int:
    if max_health < 10:
        return 1
    elif max_health < 50:
        return 2
    elif max_health < 100:
        return 3
    elif max_health < 150:
        return 4
    elif max_health < 200:
        return 5
    else:
        var extra = int((max_health - 200) / 100)
        return 10 + extra * 5