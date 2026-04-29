extends Control

@onready var back_button = $BackButton
@onready var reset_button = $ResetButton
@onready var apply_button = $ApplyButton
@onready var header_card = $HeaderCard
@onready var sp_label = $HeaderCard/SPLabel
@onready var level_label = $HeaderCard/LevelLabel
@onready var xp_bar = $HeaderCard/XPBar
@onready var xp_label = $HeaderCard/XPLabel
@onready var xp_percent = $HeaderCard/XPPercent
@onready var talent_container = $TalentContainer
@onready var grid_inner: GridContainer = $TalentContainer/GridInner

var talent_buttons: Dictionary = {}

func _ready():
	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	apply_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	reset_button.pressed.connect(_on_reset)

	_apply_styles()
	build_talent_grid()
	update_display()


func _apply_styles():
	# Header card background
	var sb = UITheme.make_card(UITheme.BG_CARD, UITheme.LINE, UITheme.R_MD)
	sb.set_content_margin_all(12)
	header_card.add_theme_stylebox_override("panel", sb)

	# XP progress bar — cyan
	var bg = StyleBoxFlat.new()
	bg.bg_color = UITheme.BG_INSET
	bg.set_corner_radius_all(999)
	bg.set_border_width_all(1)
	bg.border_color = UITheme.LINE
	var fill = StyleBoxFlat.new()
	fill.bg_color = UITheme.CYAN
	fill.set_corner_radius_all(999)
	xp_bar.add_theme_stylebox_override("background", bg)
	xp_bar.add_theme_stylebox_override("fill", fill)

	_style_action(back_button, UITheme.TEXT_MUTE, false)
	_style_action(reset_button, UITheme.ROSE, false)
	_style_action(apply_button, UITheme.LIME, true)


func _style_action(btn: Button, accent: Color, primary: bool):
	if not btn: return
	var sb = UITheme.make_card(Color(accent.r, accent.g, accent.b, 0.04 if primary else 0.0), accent if primary else UITheme.LINE_2, UITheme.R_MD)
	sb.set_content_margin_all(8)
	var sb_h = sb.duplicate()
	sb_h.bg_color = Color(accent.r, accent.g, accent.b, 0.10)
	sb_h.border_color = accent
	btn.add_theme_stylebox_override("normal",  sb)
	btn.add_theme_stylebox_override("hover",   sb_h)
	btn.add_theme_stylebox_override("pressed", sb_h)
	btn.add_theme_color_override("font_color",        accent if primary else UITheme.TEXT)
	btn.add_theme_color_override("font_hover_color",  accent)
	btn.add_theme_color_override("font_pressed_color", accent)


func build_talent_grid():
	for child in grid_inner.get_children():
		child.queue_free()
	talent_buttons.clear()

	var prog = get_node("/root/Progression")
	for key in prog.talent_defs:
		var def = prog.talent_defs[key]
		var rank = prog.talents[key]
		var max_rank = def["max"]
		var maxed = rank >= max_rank
		grid_inner.add_child(_make_skill_card(key, def, rank, max_rank, maxed))


func _make_skill_card(key: String, def: Dictionary, rank: int, max_rank: int, maxed: bool) -> Control:
	var card = Panel.new()
	card.custom_minimum_size = Vector2(165, 130)
	var sb = UITheme.make_card(UITheme.BG_CARD, UITheme.LIME_LINE if maxed else UITheme.LINE, UITheme.R_MD)
	sb.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", sb)

	# Title
	var name_lbl = Label.new()
	name_lbl.text = def["name"]
	name_lbl.position = Vector2(12, 10)
	name_lbl.size = Vector2(110, 18)
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", UITheme.TEXT)
	card.add_child(name_lbl)

	# Plus / check / lock
	var plus = Button.new()
	plus.text = "✓" if maxed else "+"
	plus.position = Vector2(133, 8)
	plus.size = Vector2(24, 24)
	plus.add_theme_font_size_override("font_size", 14)
	var psb = UITheme.make_card(UITheme.LIME_SOFT if not maxed else Color(0,0,0,0), UITheme.LINE_2, UITheme.R_SM)
	psb.set_content_margin_all(2)
	plus.add_theme_stylebox_override("normal", psb)
	plus.add_theme_stylebox_override("hover", psb)
	plus.add_theme_stylebox_override("pressed", psb)
	plus.add_theme_stylebox_override("disabled", psb)
	plus.add_theme_color_override("font_color", UITheme.TEXT_DIM if maxed else UITheme.LIME)
	plus.add_theme_color_override("font_hover_color", UITheme.TEXT_DIM if maxed else UITheme.LIME)
	plus.add_theme_color_override("font_pressed_color", UITheme.TEXT_DIM if maxed else UITheme.LIME)
	plus.add_theme_color_override("font_disabled_color", UITheme.TEXT_DIM)
	plus.disabled = maxed
	if not maxed:
		var k = key
		plus.pressed.connect(func():
			var prog = get_node("/root/Progression")
			if prog.spend_skill_point(k):
				build_talent_grid()
				update_display()
		)
	card.add_child(plus)

	# r / m
	var rank_lbl = Label.new()
	rank_lbl.text = "%d / %d" % [rank, max_rank]
	rank_lbl.position = Vector2(12, 34)
	rank_lbl.size = Vector2(120, 16)
	rank_lbl.add_theme_font_size_override("font_size", 10)
	rank_lbl.add_theme_color_override("font_color", UITheme.LIME if maxed else UITheme.TEXT_MUTE)
	card.add_child(rank_lbl)

	# Pip rank bar
	var pips = HBoxContainer.new()
	pips.position = Vector2(12, 54)
	pips.size = Vector2(141, 4)
	pips.add_theme_constant_override("separation", 4)
	for i in range(max_rank):
		var pip = ColorRect.new()
		pip.custom_minimum_size = Vector2(int(141 / max_rank) - 4, 4)
		pip.color = UITheme.LIME if i < rank else UITheme.BG_INSET
		pips.add_child(pip)
	card.add_child(pips)

	# Description
	var desc = Label.new()
	desc.text = def["desc"]
	desc.position = Vector2(12, 70)
	desc.size = Vector2(141, 50)
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", UITheme.TEXT_MUTE)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	card.add_child(desc)

	if maxed:
		card.modulate = Color(1, 1, 1, 1)
	return card


func _on_reset():
	# Soft refresh — actual reset would need API from Progression. For now, just rebuild.
	build_talent_grid()
	update_display()


func update_display():
	var prog = get_node("/root/Progression")
	sp_label.text = "%d" % prog.skill_points
	level_label.text = "%d" % prog.level
	var cur = prog.xp
	var need = prog.xp_for_current_level()
	var pct = int(prog.xp_progress() * 100)
	xp_label.text = "%d / %d XP" % [cur, need]
	xp_percent.text = "%d%% · LV %d" % [pct, prog.level + 1]
	xp_bar.value = pct
	# Apply button label updates
	if prog.skill_points > 0:
		apply_button.text = "▸ APPLY · %d PTS" % prog.skill_points
	else:
		apply_button.text = "▸ DONE"
