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
    queue_free()