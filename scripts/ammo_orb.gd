extends Area2D

var collected: bool = false
var ammo_value: int = 1
var is_blue: bool = false

# Theme-consistent colors (matches theme.gd accent_green / dark blue)
const COLOR_GREEN_GLOW = Color(0.741, 1.0, 0.024, 0.30)  # #bdff06 @ 30%
const COLOR_GREEN_FILL = Color(0.741, 1.0, 0.024, 0.90)
const COLOR_BLUE_GLOW  = Color(0.10, 0.25, 0.55, 0.35)   # dark navy blue glow
const COLOR_BLUE_FILL  = Color(0.18, 0.40, 0.85, 0.95)   # #2e66d9-ish, reads "ammo +5"

func _ready():
    queue_redraw()
    body_entered.connect(_on_body_entered)

func _draw():
    var glow = COLOR_BLUE_GLOW if is_blue else COLOR_GREEN_GLOW
    var fill = COLOR_BLUE_FILL if is_blue else COLOR_GREEN_FILL
    var radius_outer = 13.0 if is_blue else 11.0
    var radius_inner = 10.0 if is_blue else 9.0
    draw_circle(Vector2.ZERO, radius_outer, glow)
    draw_circle(Vector2.ZERO, radius_inner, fill)
    draw_arc(Vector2.ZERO, radius_outer, 0, TAU, 32, Color(1, 1, 1, 0.55), 1.5)
    if is_blue:
        # "+5" label drawn as a small white pip cluster — keeps it stylistically minimal
        var f := ThemeDB.fallback_font
        if f:
            var txt = "+5"
            var size = 10
            var tw = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
            draw_string(f, Vector2(-tw * 0.5, 4), txt, HORIZONTAL_ALIGNMENT_CENTER, -1, size, Color(1, 1, 1, 0.95))

func _on_body_entered(body):
    if collected:
        return
    if body.is_in_group("balls"):
        collected = true
        var manager = get_tree().get_first_node_in_group("game_manager")
        if manager:
            manager.collect_ammo_orb(ammo_value)
        var tween = create_tween()
        tween.tween_property(self, "scale", Vector2.ZERO, 0.15)
        tween.tween_callback(queue_free)