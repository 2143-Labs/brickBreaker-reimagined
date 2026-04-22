extends StaticBody2D

var health: int = 1
var max_health: int = 1
var shield_hp: int = 150
var shield_max: int = 150

@onready var sprite = $Sprite
@onready var health_label = $HealthLabel

func _ready():
    update_display()

func take_damage(amount: int, _hit_dir: Vector2 = Vector2.DOWN):
    # Shield absorbs first
    if shield_hp > 0:
        var absorbed = min(shield_hp, amount)
        shield_hp -= absorbed
        amount -= absorbed
        update_display()
        if amount <= 0:
            if sprite:
                var tween = create_tween()
                tween.tween_property(sprite, "modulate", Color(1.5, 1.5, 2, 1), 0.05)
                tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.1)
            return

    health -= amount
    update_display()
    if health <= 0:
        destroy()

func update_display():
    if sprite:
        if shield_hp > 0:
            var ratio = float(shield_hp) / max(shield_max, 1)
            sprite.color = Color(0.3, 0.5, 0.85).lerp(Color(0.2, 0.35, 0.65), 1.0 - ratio)
        else:
            sprite.color = Color(0.5, 0.5, 0.55)
    if health_label:
        if shield_hp > 0:
            health_label.text = str(shield_hp)
        else:
            health_label.text = str(health)
        health_label.add_theme_color_override("font_color", Color(1, 1, 1))
        health_label.add_theme_font_size_override("font_size", 12)

func apply_explosion_crack(_ring: int):
    pass  # Guardians don't crack

func destroy():
    var manager = get_tree().get_first_node_in_group("game_manager")
    if manager:
        manager.add_score(3)
        if sprite:
            manager.spawn_brick_particles(global_position, sprite.color)
    queue_free()