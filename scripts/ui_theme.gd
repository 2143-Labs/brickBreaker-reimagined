extends Node
var theme: Theme

func _ready():
    theme = Theme.new()
    
    # Button styles
    var btn_normal = StyleBoxFlat.new()
    btn_normal.bg_color = Color(0.145, 0.157, 0.188, 1)
    btn_normal.corner_radius_top_left = 8
    btn_normal.corner_radius_top_right = 8
    btn_normal.corner_radius_bottom_left = 8
    btn_normal.corner_radius_bottom_right = 8
    btn_normal.border_width_bottom = 1
    btn_normal.border_width_top = 1
    btn_normal.border_width_left = 1
    btn_normal.border_width_right = 1
    btn_normal.border_color = Color(0.25, 0.27, 0.32, 0.5)
    btn_normal.content_margin_left = 8
    btn_normal.content_margin_right = 8
    btn_normal.content_margin_top = 4
    btn_normal.content_margin_bottom = 4
    
    var btn_hover = btn_normal.duplicate()
    btn_hover.bg_color = Color(0.18, 0.2, 0.24, 1)
    
    var btn_pressed = btn_normal.duplicate()
    btn_pressed.bg_color = Color(0.22, 0.24, 0.28, 1)
    
    var btn_disabled = btn_normal.duplicate()
    btn_disabled.bg_color = Color(0.12, 0.13, 0.15, 1)
    btn_disabled.border_color = Color(0.18, 0.2, 0.22, 0.3)
    
    theme.set_stylebox("normal", "Button", btn_normal)
    theme.set_stylebox("hover", "Button", btn_hover)
    theme.set_stylebox("pressed", "Button", btn_pressed)
    theme.set_stylebox("disabled", "Button", btn_disabled)
    theme.set_color("font_color", "Button", Color(0.85, 0.85, 0.88))
    theme.set_color("font_hover_color", "Button", Color(0.95, 0.95, 0.97))
    theme.set_color("font_pressed_color", "Button", Color(1, 1, 1))
    theme.set_color("font_disabled_color", "Button", Color(0.4, 0.4, 0.45))
    
    # Panel styles
    var panel_style = StyleBoxFlat.new()
    panel_style.bg_color = Color(0.12, 0.13, 0.16, 0.95)
    panel_style.corner_radius_top_left = 12
    panel_style.corner_radius_top_right = 12
    panel_style.corner_radius_bottom_left = 12
    panel_style.corner_radius_bottom_right = 12
    panel_style.border_width_bottom = 1
    panel_style.border_width_top = 1
    panel_style.border_width_left = 1
    panel_style.border_width_right = 1
    panel_style.border_color = Color(0.22, 0.24, 0.28, 0.5)
    theme.set_stylebox("panel", "Panel", panel_style)
    
    # Apply globally
    get_tree().root.theme = theme