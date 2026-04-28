extends StaticBody2D

var health: int = 1
var max_health: int = 1
var armored: bool = true
var burn_stacks: int = 0

@onready var sprite = $Sprite
@onready var health_label = $HealthLabel
@onready var armor_overlay: Node2D = null

var is_dying: bool = false
var last_hit_direction: Vector2 = Vector2.DOWN

func _ready():
    update_display()
    armor_overlay = Node2D.new()
    armor_overlay.z_index = 2
    add_child(armor_overlay)
    armor_overlay.draw.connect(_draw_armor)
    armor_overlay.queue_redraw()
    
    if MultiplayerManager.is_multiplayer and not is_multiplayer_authority():
        request_initial_state.rpc_id(1)

@rpc("any_peer", "call_remote")
func request_initial_state():
    if is_multiplayer_authority():
        var sender = multiplayer.get_remote_sender_id()
        sync_state.rpc_id(sender, position, health, max_health, burn_stacks, armored)

@rpc("authority", "call_remote")
func sync_state(p_pos, p_health, p_max_health, p_burn_stacks, p_armored):
    position = p_pos
    health = p_health
    max_health = p_max_health
    burn_stacks = p_burn_stacks
    armored = p_armored
    update_display()
    if armor_overlay:
        armor_overlay.queue_redraw()

func take_damage(amount: int, hit_dir: Vector2 = Vector2.DOWN, _is_special: bool = false):
    if MultiplayerManager.is_multiplayer and not is_multiplayer_authority():
        return
    last_hit_direction = hit_dir
    if armored:
        # Armored: immune to normal damage, show deflect effect
        if sprite:
            var tween = create_tween()
            tween.tween_property(sprite, "modulate", Color(1.5, 1.5, 1.5, 1), 0.05)
            tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.1)
        return

    health -= amount
    update_display()
    if sprite and health > 0:
        var tween = create_tween()
        tween.tween_property(sprite, "modulate", Color(2, 2, 2, 1), 0.05)
        tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.1)

    if health <= 0:
        destroy()

func strip_armor():
    if not armored:
        return
    armored = false
    # Armor break VFX
    spawn_armor_break_vfx()
    if armor_overlay:
        armor_overlay.queue_redraw()
    update_display()

func apply_explosion_crack(_ring: int):
    # Explosions strip armor instead of dealing damage
    if armored:
        strip_armor()

func spawn_armor_break_vfx():
    var manager = get_tree().get_first_node_in_group("game_manager")
    if not manager:
        return
    # Metal plates shattering off
    for i in range(6):
        var p = ColorRect.new()
        var s = randf_range(4, 9)
        p.size = Vector2(s, s * 0.6)
        p.position = global_position + Vector2(randf_range(-15, 15), randf_range(-10, 10))
        p.color = [Color(0.6, 0.6, 0.65), Color(0.5, 0.5, 0.55), Color(0.7, 0.7, 0.72)][randi() % 3]
        p.rotation = randf_range(0, TAU)
        manager.particle_container.add_child(p)

        var angle = randf_range(0, TAU)
        var dist = randf_range(25, 55)
        var target_pos = p.position + Vector2(cos(angle) * dist, sin(angle) * dist)

        var tween = p.create_tween()
        tween.set_parallel(true)
        tween.tween_property(p, "position", target_pos, 0.4).set_ease(Tween.EASE_OUT)
        tween.tween_property(p, "rotation", p.rotation + randf_range(-3, 3), 0.4)
        tween.tween_property(p, "modulate:a", 0.0, 0.4)
        tween.chain().tween_callback(p.queue_free)

    manager.add_shake(4.0)

func _draw_armor():
    if not armored:
        return
    # Steel plates with rivets
    var hw = 24.0
    var hh = 17.0
    # Steel border
    armor_overlay.draw_rect(Rect2(-hw, -hh, hw * 2, hh * 2), Color(0.6, 0.6, 0.65, 0.4), false, 2.0)
    # Cross plates
    armor_overlay.draw_line(Vector2(-hw, 0), Vector2(hw, 0), Color(0.55, 0.55, 0.6, 0.5), 1.5)
    armor_overlay.draw_line(Vector2(0, -hh), Vector2(0, hh), Color(0.55, 0.55, 0.6, 0.5), 1.5)
    # Corner rivets
    var rivet_color = Color(0.5, 0.5, 0.55, 0.7)
    armor_overlay.draw_circle(Vector2(-hw + 4, -hh + 4), 2.5, rivet_color)
    armor_overlay.draw_circle(Vector2(hw - 4, -hh + 4), 2.5, rivet_color)
    armor_overlay.draw_circle(Vector2(-hw + 4, hh - 4), 2.5, rivet_color)
    armor_overlay.draw_circle(Vector2(hw - 4, hh - 4), 2.5, rivet_color)
    # Highlight rivets
    armor_overlay.draw_circle(Vector2(-hw + 4, -hh + 4), 1, Color(0.7, 0.7, 0.72, 0.5))
    armor_overlay.draw_circle(Vector2(hw - 4, -hh + 4), 1, Color(0.7, 0.7, 0.72, 0.5))

func add_burn_stack():
    if armored:
        return  # Can't burn while armored
    burn_stacks += 1
    # Visual feedback for burning
    if sprite:
        var tween = create_tween()
        tween.tween_property(sprite, "modulate", Color(1.5, 0.8, 0.2), 0.1)
        tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.2)
func process_burn():
    if burn_stacks > 0 and not armored:
        take_damage(burn_stacks)
        burn_stacks = int(burn_stacks / 2.0)

func update_display():
    if health_label:
        health_label.text = str(health)
        health_label.add_theme_color_override("font_color", Color(1, 1, 1))
        health_label.add_theme_font_size_override("font_size", 16)
    if sprite:
        if armored:
            sprite.color = Color(0.55, 0.55, 0.6)  # Steel gray
        else:
            var ratio = clamp(float(health) / max(max_health, 1), 0.0, 1.0)
            sprite.color = Color(0.7, 0.65, 0.6).lerp(Color(0.5, 0.45, 0.4), ratio)

func destroy():
    if is_dying: return
    is_dying = true
    var manager = get_tree().get_first_node_in_group("game_manager")
    if manager:
        manager.add_score(get_brick_value())
        if sprite:
            manager.spawn_brick_particles_directional(global_position, sprite.color, last_hit_direction)
            manager.on_brick_destroyed()
    queue_free()

func get_brick_value() -> int:
    return max(2, int(max_health / 10.0))
