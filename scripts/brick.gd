extends StaticBody2D

var health: int = 1
var max_health: int = 1
var is_burning: bool = false
var burn_damage: int = 0
var burn_ticks: int = 0

@onready var sprite = $Sprite
@onready var health_label = $HealthLabel

# Color palette for bricks based on health ratio
var brick_colors = [
    Color(0.55, 0.82, 0.53),  # green - low hp
    Color(0.95, 0.77, 0.3),   # yellow - mid
    Color(0.9, 0.45, 0.2),    # orange - high
    Color(0.85, 0.2, 0.2),    # red - very high
    Color(0.6, 0.15, 0.6),    # purple - extreme
]

func _ready():
    update_display()

func take_damage(amount: int):
    health -= amount
    update_display()
    if health <= 0:
        destroy()

func update_display():
    if health_label:
        health_label.text = str(health)
        health_label.add_theme_color_override("font_color", Color(1, 1, 1))
        health_label.add_theme_font_size_override("font_size", 10)
    if sprite:
        var ratio = clamp(float(health) / max(max_health, 1), 0.0, 1.0)
        var idx = int(ratio * (brick_colors.size() - 1))
        idx = clamp(idx, 0, brick_colors.size() - 1)
        sprite.color = brick_colors[idx]

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
    queue_free()