extends StaticBody2D

var health: int = 1
var max_health: int = 1
var burn_stacks: int = 0
var grid_width: int = 2
var grid_height: int = 2
var has_shield: bool = false
var shield_hp: int = 0
var shield_max: int = 10
var is_elite: bool = false
var is_final_boss: bool = false
var moves_every_other: bool = false
var turns_since_move: int = 0
var guardian_spawn_enabled: bool = false

var color_base = Color(0.55, 0.1, 0.1)
var color_damaged = Color(0.75, 0.2, 0.15)
var elite_color = Color(0.15, 0.1, 0.55)
var final_color = Color(0.4, 0.05, 0.05)

@onready var sprite = $Sprite
@onready var health_label = $HealthLabel
@onready var collision_shape = $CollisionShape2D
@onready var shield_bar = $ShieldBar

var crack_level: int = 0
var crack_overlay: Node2D = null

func _ready():
    update_size()
    update_display()
    crack_overlay = Node2D.new()
    crack_overlay.z_index = 1
    add_child(crack_overlay)
    crack_overlay.draw.connect(_draw_cracks)
    
    if MultiplayerManager.is_multiplayer and not is_multiplayer_authority():
        request_initial_state.rpc_id(1)

@rpc("any_peer", "call_remote")
func request_initial_state():
    if is_multiplayer_authority():
        var sender = multiplayer.get_remote_sender_id()
        sync_state.rpc_id(sender, position, health, max_health, burn_stacks, grid_width, grid_height, has_shield, shield_hp, shield_max, is_elite, is_final_boss)

@rpc("authority", "call_remote")
func sync_state(p_pos, p_health, p_max_health, p_burn_stacks, p_grid_w, p_grid_h, p_has_shield, p_shield_hp, p_shield_max, p_is_elite, p_is_final):
    position = p_pos
    health = p_health
    max_health = p_max_health
    burn_stacks = p_burn_stacks
    grid_width = p_grid_w
    grid_height = p_grid_h
    has_shield = p_has_shield
    shield_hp = p_shield_hp
    shield_max = p_shield_max
    is_elite = p_is_elite
    is_final_boss = p_is_final
    update_size()
    update_display()
    update_shield_display()

func update_size():
    var w = grid_width * 52.0 - 2.0
    var h = grid_height * 38.0 - 2.0
    var half_w = w / 2.0
    var half_h = h / 2.0

    var shape = RectangleShape2D.new()
    shape.size = Vector2(w, h)
    collision_shape.shape = shape

    sprite.offset_left = -half_w
    sprite.offset_top = -half_h
    sprite.offset_right = half_w
    sprite.offset_bottom = half_h

    health_label.offset_left = -half_w
    health_label.offset_top = -half_h
    health_label.offset_right = half_w
    health_label.offset_bottom = half_h

    shield_bar.offset_left = -half_w
    shield_bar.offset_top = -half_h - 5
    shield_bar.offset_right = half_w
    shield_bar.offset_bottom = -half_h - 1

func take_damage(amount: int, _hit_dir: Vector2 = Vector2.DOWN, is_special: bool = false):
    if MultiplayerManager.is_multiplayer and not is_multiplayer_authority():
        return
    # Bosses and elites take 50% less from bombs and railguns
    if is_special:
        amount = max(1, int(amount * 0.5))

    if has_shield and shield_hp > 0:
        var absorbed = min(shield_hp, amount)
        shield_hp -= absorbed
        amount -= absorbed
        update_shield_display()
        if amount <= 0:
            if shield_bar:
                var tween = create_tween()
                tween.tween_property(shield_bar, "modulate", Color(3, 3, 3, 1), 0.05)
                tween.tween_property(shield_bar, "modulate", Color(1, 1, 1, 1), 0.1)
            return

    health -= amount
    update_display()

    if sprite and health > 0:
        var tween = create_tween()
        tween.tween_property(sprite, "modulate", Color(2, 2, 2, 1), 0.05)
        tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.1)

    if health <= 0:
        destroy()

func regenerate_shield():
    if has_shield:
        shield_hp = shield_max
        update_shield_display()

func should_move_this_turn() -> bool:
    if not moves_every_other:
        return true
    turns_since_move += 1
    if turns_since_move >= 2:
        turns_since_move = 0
        return true
    return false

func should_spawn_guardians() -> bool:
    return guardian_spawn_enabled and turns_since_move == 0

func update_shield_display():
    if not has_shield:
        shield_bar.visible = false
        return
    shield_bar.visible = true
    var w = grid_width * 52.0 - 2.0
    var ratio = float(shield_hp) / max(shield_max, 1)
    var half_w = w / 2.0
    shield_bar.offset_left = -half_w
    shield_bar.offset_right = -half_w + w * ratio
    if shield_hp <= 0:
        shield_bar.modulate = Color(1, 1, 1, 0.3)
    else:
        shield_bar.modulate = Color(1, 1, 1, 1)
    # Refresh numeric label too
    update_display()

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
    var hw = grid_width * 26.0
    var hh = grid_height * 19.0
    var crack_alpha = 0.3 + crack_level * 0.2
    var crack_width = 1.2 + crack_level * 0.5
    var crack_color = Color(0.05, 0.02, 0.0, crack_alpha)
    var rng = RandomNumberGenerator.new()
    rng.seed = int(position.x * 100 + position.y * 7)
    var num_cracks = crack_level * 3 + 2
    for i in range(num_cracks):
        var start = Vector2(rng.randf_range(-hw * 0.6, hw * 0.6), rng.randf_range(-hh * 0.6, hh * 0.6))
        var angle = rng.randf_range(0, TAU)
        var length = rng.randf_range(8, 12 + crack_level * 6)
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
func update_display():
    if health_label:
        if has_shield and shield_hp > 0:
            health_label.text = str(shield_hp)
            health_label.add_theme_color_override("font_color", Color(0.3, 0.6, 1.0))
        else:
            health_label.text = str(health)
            health_label.add_theme_color_override("font_color", Color(1, 1, 1))
        var font_size = 20 if not is_final_boss else 24
        health_label.add_theme_font_size_override("font_size", font_size)
    if sprite:
        var ratio = clamp(float(health) / max(max_health, 1), 0.0, 1.0)
        var base = final_color if is_final_boss else (elite_color if is_elite else color_base)
        var damaged = color_damaged
        sprite.color = damaged.lerp(base, ratio)

func destroy():
    var manager = get_tree().get_first_node_in_group("game_manager")
    if manager:
        var points = get_brick_value() * grid_width * grid_height
        manager.add_score(points)
        if sprite:
            for i in range(grid_width * grid_height):
                var offset = Vector2(
                    randf_range(-grid_width * 20, grid_width * 20),
                    randf_range(-grid_height * 15, grid_height * 15)
                )
                manager.spawn_brick_particles(global_position + offset, sprite.color)
            manager.add_shake(6.0)
        manager.on_boss_killed(self)
    queue_free()

func get_brick_value() -> int:
    if is_final_boss: return 50
    elif is_elite: return 8
    elif max_health < 100: return 5
    elif max_health < 300: return 10
    elif max_health < 500: return 20
    else: return 30