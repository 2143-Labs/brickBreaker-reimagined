extends StaticBody2D

var health: int = 1
var max_health: int = 1
var burn_stacks: int = 0
var fire_overlay: Node2D = null
var fire_time: float = 0.0

@onready var sprite = $Sprite
@onready var health_label = $HealthLabel

var crack_level: int = 0
var crack_overlay: Node2D = null

# Color tier thresholds
static var tier_thresholds = [5, 10, 20, 50, 100]

func get_color_for_hp(hp: int) -> Color:
    if hp >= 100:
        return Color(0.55, 0.2, 0.7)    # purple
    elif hp >= 50:
        return Color(0.4, 0.55, 0.9)    # blue
    elif hp >= 20:
        return Color(0.95, 0.65, 0.3)   # orange
    elif hp >= 10:
        return Color(0.93, 0.5, 0.45)   # red
    elif hp >= 5:
        return Color(0.95, 0.85, 0.4)   # yellow
    else:
        return Color(0.6, 0.85, 0.55)   # green
func get_next_tier_color(hp: int) -> Color:
    # What color will this brick be when it drops to the next tier?
    for threshold in tier_thresholds:
        if hp > threshold:
            continue
        # hp is at or below this threshold, find the tier below
        break
    # Just get the color for hp-1 tier
    if hp >= 100:
        return Color(0.4, 0.55, 0.9)    # blue (next below purple)
    elif hp >= 50:
        return Color(0.95, 0.65, 0.3)   # orange (next below blue)
    elif hp >= 20:
        return Color(0.93, 0.5, 0.45)   # red (next below orange)
    elif hp >= 10:
        return Color(0.95, 0.85, 0.4)   # yellow (next below red)
    elif hp >= 5:
        return Color(0.6, 0.85, 0.55)   # green (next below yellow)
    else:
        return Color(0.8, 0.9, 0.8)     # light green (almost gone)

func get_brick_color(ratio: float) -> Color:
    # Blend within the current tier
    var base = get_color_for_hp(max_health)
    return base.lightened((1.0 - ratio) * 0.25)

func _ready():
    update_display()
    crack_overlay = Node2D.new()
    crack_overlay.z_index = 1
    add_child(crack_overlay)
    crack_overlay.draw.connect(_draw_cracks)
    fire_overlay = Node2D.new()
    fire_overlay.z_index = 2
    fire_overlay.visible = false
    add_child(fire_overlay)
    fire_overlay.draw.connect(_draw_fire)

func take_damage(amount: int):
    var old_hp = health
    health -= amount
    update_display()

    if sprite and health > 0:
        # Flash to next tier color briefly
        var next_color = get_next_tier_color(health)
        var tween = create_tween()
        tween.tween_property(sprite, "color", next_color, 0.06)
        tween.tween_property(sprite, "color", get_brick_color(clamp(float(health) / max(max_health, 1), 0.0, 1.0)), 0.12)
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
        if crack_level >= 2 and rng.randf() > 0.3:
            var b_angle = angle + rng.randf_range(-0.8, 0.8)
            var b_len = length * rng.randf_range(0.3, 0.6)
            var b_end = end + Vector2(cos(b_angle), sin(b_angle)) * b_len
            b_end.x = clamp(b_end.x, -hw, hw)
            b_end.y = clamp(b_end.y, -hh, hh)
            crack_overlay.draw_line(end, b_end, crack_color, crack_width * 0.7)
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
        sprite.color = get_brick_color(ratio)

func _process(delta):
    if burn_stacks > 0:
        fire_time += delta
        if fire_overlay:
            fire_overlay.visible = true
            fire_overlay.queue_redraw()
    elif fire_overlay:
        fire_overlay.visible = false

func _draw_fire():
    if burn_stacks <= 0:
        return
    # Flickering flames on top of brick
    var intensity = min(burn_stacks, 10) / 10.0
    var hw = 20.0
    var flames = 3 + int(intensity * 4)
    for i in range(flames):
        var x = randf_range(-hw, hw)
        var height = randf_range(6, 12 + intensity * 8)
        var width = randf_range(3, 5)
        var flicker = sin(fire_time * 8 + i * 2.0) * 3
        var base_y = -16.0
        # Flame colors: yellow core, orange mid, red tips
        var tip_y = base_y - height + flicker
        fire_overlay.draw_line(
            Vector2(x, base_y),
            Vector2(x, tip_y),
            Color(1.0, 0.6, 0.1, 0.4 + intensity * 0.3),
            width
        )
        fire_overlay.draw_circle(
            Vector2(x, tip_y),
            width * 0.6,
            Color(1.0, 0.3, 0.1, 0.3 + intensity * 0.2)
        )

func add_burn_stack():
    burn_stacks += 1
    if fire_overlay:
        fire_overlay.visible = true
        fire_overlay.queue_redraw()

func process_burn():
    # Burn is processed once per round by the game manager. Damage equals current stacks,
    # then stacks halve (integer division) to model diminishing DOT.
    if burn_stacks > 0:
        var dmg = burn_stacks
        take_damage(dmg)
        burn_stacks = int(burn_stacks / 2.0)
        # Small burn particles/feedback
        var manager = get_tree().get_first_node_in_group("game_manager")
        if manager:
            manager.spawn_brick_particles(global_position, Color(1.0, 0.45, 0.12))

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