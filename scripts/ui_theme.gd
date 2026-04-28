extends Node

# ===== Lofi Brick Breaker palette =====
# Surfaces
const BG_DEEP   = Color(0.055, 0.067, 0.086)   # #0e1116
const BG_BASE   = Color(0.075, 0.090, 0.125)   # #131720
const BG_CARD   = Color(0.102, 0.122, 0.169)   # #1a1f2b
const BG_CARDHI = Color(0.137, 0.165, 0.224)   # #232a39
const BG_INSET  = Color(0.043, 0.055, 0.078)   # #0b0e14

# Lines
const LINE        = Color(1, 1, 1, 0.08)
const LINE_2      = Color(1, 1, 1, 0.14)
const LINE_STRONG = Color(1, 1, 1, 0.22)

# Text
const TEXT      = Color(0.906, 0.925, 0.953)   # #e7ecf3
const TEXT_MUTE = Color(0.541, 0.576, 0.651)   # #8a93a6
const TEXT_DIM  = Color(0.357, 0.392, 0.475)   # #5b6479

# Brand accents
const LIME     = Color(0.714, 0.949, 0.290)    # #b6f24a
const LIME_DIM = Color(0.494, 0.659, 0.169)    # #7ea82b
const CYAN     = Color(0.424, 0.831, 1.0)      # #6cd4ff
const AMBER    = Color(1.0, 0.761, 0.400)      # #ffc266
const ROSE     = Color(1.0, 0.478, 0.541)      # #ff7a8a

const LIME_SOFT  = Color(0.714, 0.949, 0.290, 0.06)
const LIME_LINE  = Color(0.714, 0.949, 0.290, 0.35)
const CYAN_SOFT  = Color(0.424, 0.831, 1.0, 0.06)
const CYAN_LINE  = Color(0.424, 0.831, 1.0, 0.30)
const AMBER_SOFT = Color(1.0, 0.761, 0.400, 0.07)
const AMBER_LINE = Color(1.0, 0.761, 0.400, 0.35)
const ROSE_SOFT  = Color(1.0, 0.478, 0.541, 0.06)
const ROSE_LINE  = Color(1.0, 0.478, 0.541, 0.30)

# Radii (Godot uses int corner radius in px)
const R_SM = 4
const R_MD = 8
const R_LG = 12

var theme: Theme

func _ready():
	theme = Theme.new()

	# ----- Buttons -----
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(1, 1, 1, 0)
	btn_normal.set_corner_radius_all(R_MD)
	btn_normal.set_border_width_all(1)
	btn_normal.border_color = LINE_2
	btn_normal.set_content_margin_all(10)

	var btn_hover = btn_normal.duplicate()
	btn_hover.bg_color = Color(1, 1, 1, 0.03)
	btn_hover.border_color = LINE_STRONG

	var btn_pressed = btn_normal.duplicate()
	btn_pressed.bg_color = Color(1, 1, 1, 0.06)
	btn_pressed.border_color = LINE_STRONG

	var btn_disabled = btn_normal.duplicate()
	btn_disabled.bg_color = Color(1, 1, 1, 0.015)
	btn_disabled.border_color = LINE

	theme.set_stylebox("normal",   "Button", btn_normal)
	theme.set_stylebox("hover",    "Button", btn_hover)
	theme.set_stylebox("pressed",  "Button", btn_pressed)
	theme.set_stylebox("disabled", "Button", btn_disabled)
	theme.set_color("font_color",          "Button", TEXT)
	theme.set_color("font_hover_color",    "Button", TEXT)
	theme.set_color("font_pressed_color",  "Button", TEXT)
	theme.set_color("font_disabled_color", "Button", TEXT_DIM)

	# ----- Panels (treated as "card") -----
	var panel = StyleBoxFlat.new()
	panel.bg_color = BG_CARD
	panel.set_corner_radius_all(R_LG)
	panel.set_border_width_all(1)
	panel.border_color = LINE
	panel.set_content_margin_all(14)
	theme.set_stylebox("panel", "Panel", panel)
	theme.set_stylebox("panel", "PanelContainer", panel)

	# ----- Labels -----
	theme.set_color("font_color", "Label", TEXT)

	# ----- Progress / Slider -----
	var pbar_bg = StyleBoxFlat.new()
	pbar_bg.bg_color = BG_INSET
	pbar_bg.set_corner_radius_all(999)
	pbar_bg.set_border_width_all(1)
	pbar_bg.border_color = LINE
	var pbar_fill = StyleBoxFlat.new()
	pbar_fill.bg_color = LIME
	pbar_fill.set_corner_radius_all(999)
	theme.set_stylebox("background", "ProgressBar", pbar_bg)
	theme.set_stylebox("fill",       "ProgressBar", pbar_fill)
	theme.set_color("font_color", "ProgressBar", TEXT_MUTE)

	var sl_track = pbar_bg.duplicate()
	var sl_fill  = pbar_fill.duplicate()
	var sl_grab  = StyleBoxFlat.new()
	sl_grab.bg_color = TEXT
	sl_grab.set_corner_radius_all(999)
	theme.set_stylebox("slider",       "HSlider", sl_track)
	theme.set_stylebox("grabber_area", "HSlider", sl_fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", sl_fill)

	get_tree().root.theme = theme


# ----- Helpers -----

static func make_card(bg: Color = BG_CARD, border: Color = LINE, radius: int = R_LG) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(1)
	sb.border_color = border
	sb.set_content_margin_all(12)
	return sb

static func make_pill(bg: Color, border: Color) -> StyleBoxFlat:
	var sb = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(999)
	sb.set_border_width_all(1)
	sb.border_color = border
	sb.set_content_margin_all(6)
	return sb

# Corner-bracket overlay node (the four little L-shapes on buttons in the design).
# Returns a Control that paints onto the parent's rect.
static func make_corner_brackets(parent: Control, color: Color = LINE_2, length: int = 8) -> Control:
	var overlay := Control.new()
	overlay.name = "CornerBrackets"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.set_meta("bracket_color", color)
	overlay.set_meta("bracket_length", length)
	overlay.draw.connect(func():
		var size = overlay.size
		var c: Color = overlay.get_meta("bracket_color")
		var L: int = overlay.get_meta("bracket_length")
		var w := 1.0
		# top-left
		overlay.draw_line(Vector2(0, 0), Vector2(L, 0), c, w)
		overlay.draw_line(Vector2(0, 0), Vector2(0, L), c, w)
		# top-right
		overlay.draw_line(Vector2(size.x - L, 0), Vector2(size.x, 0), c, w)
		overlay.draw_line(Vector2(size.x, 0), Vector2(size.x, L), c, w)
		# bottom-left
		overlay.draw_line(Vector2(0, size.y), Vector2(L, size.y), c, w)
		overlay.draw_line(Vector2(0, size.y - L), Vector2(0, size.y), c, w)
		# bottom-right
		overlay.draw_line(Vector2(size.x - L, size.y), Vector2(size.x, size.y), c, w)
		overlay.draw_line(Vector2(size.x, size.y - L), Vector2(size.x, size.y), c, w)
	)
	overlay.resized.connect(overlay.queue_redraw)
	parent.add_child(overlay)
	return overlay
