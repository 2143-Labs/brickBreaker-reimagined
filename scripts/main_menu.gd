extends Control

const SAVE_PATH = "user://highscore.save"
const STATS_PATH = "user://stats.save"

@onready var title_label = $TitleLabel
@onready var play_button = $PlayButton
@onready var multiplayer_button = $MultiplayerButton
@onready var resume_button = $ResumeButton
@onready var stats_button = $TileGrid/StatsButton
@onready var shop_button  = $TileGrid/ShopButton
@onready var skill_button = $TileGrid/SkillTreeButton
@onready var settings_btn = $TileGrid/SettingsButton
@onready var stats_panel = $StatsPanel
@onready var stats_text = $StatsPanel/StatsText
@onready var stats_close = $StatsPanel/CloseButton
@onready var player_chip = $PlayerChip
@onready var play_sub_label = $PlaySubLabel
@onready var streak_label = $StreakLabel
@onready var dotline = $DotLine

var stats: Dictionary = {
	"high_score": 0,
	"best_round": 0,
	"total_bricks": 0,
	"total_rounds": 0,
	"total_games": 0,
	"bosses_killed": 0,
}

var has_save: bool = false
var save_round: int = 1
var save_score: int = 0
var anim_time: float = 0.0

func _ready():
	load_stats()
	load_high_score()
	check_save_game()

	play_button.pressed.connect(_on_play)
	multiplayer_button.pressed.connect(_on_multiplayer)
	resume_button.pressed.connect(_on_resume)
	stats_button.pressed.connect(_on_stats)
	shop_button.pressed.connect(_on_shop)
	stats_close.pressed.connect(func(): stats_panel.visible = false)
	skill_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/skill_tree.tscn"))
	settings_btn.pressed.connect(_on_shop)  # placeholder until standalone settings exist

	resume_button.visible = has_save
	stats_panel.visible = false

	_style_primary_button(play_button, UITheme.LIME)
	_style_primary_button(multiplayer_button, UITheme.AMBER)
	_style_primary_button(resume_button, UITheme.CYAN)

	_style_tile(stats_button, "STATS",      "lifetime",         UITheme.TEXT_MUTE, "%s" % _format_score(stats.get("high_score", 0)))
	_style_tile(shop_button,  "SHOP",       "coming soon",      UITheme.CYAN,      "")
	_style_tile(skill_button, "SKILL TREE", _skill_sub(),       UITheme.LIME,      "", true)
	_style_tile(settings_btn, "SETTINGS",   "audio · fx",       UITheme.TEXT_MUTE, "")

	_build_player_chip()
	_build_dotline()
	_update_play_sub()

	MusicManager.start_menu_music()


func _process(delta):
	anim_time += delta
	# Subtle breathing on the title color
	if title_label:
		var pulse = sin(anim_time * 0.5) * 0.02
		title_label.add_theme_color_override("font_color", UITheme.TEXT.lightened(pulse))
	# Pulse the skill-tree dot if there are unspent points
	var prog = get_node_or_null("/root/Progression")
	if prog and prog.skill_points > 0:
		var pulse_dot = $TileGrid/SkillTreeButton.get_node_or_null("AccentDot")
		if pulse_dot:
			var a = 0.55 + 0.45 * sin(anim_time * 4.0)
			pulse_dot.modulate = Color(1, 1, 1, a)


# ----- Primary button (corner brackets, accent border, big) -----
func _style_primary_button(btn: Button, accent: Color) -> void:
	if not btn: return
	var sb_normal = UITheme.make_card(Color(accent.r, accent.g, accent.b, 0.04), accent, UITheme.R_MD)
	sb_normal.set_content_margin_all(14)
	sb_normal.border_color = accent
	var sb_hover = sb_normal.duplicate()
	sb_hover.bg_color = Color(accent.r, accent.g, accent.b, 0.10)
	var sb_pressed = sb_normal.duplicate()
	sb_pressed.bg_color = Color(accent.r, accent.g, accent.b, 0.16)
	btn.add_theme_stylebox_override("normal",  sb_normal)
	btn.add_theme_stylebox_override("hover",   sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	btn.add_theme_color_override("font_color",         accent)
	btn.add_theme_color_override("font_hover_color",   accent)
	btn.add_theme_color_override("font_pressed_color", accent)
	btn.add_theme_constant_override("h_separation", 10)
	UITheme.make_corner_brackets(btn, accent.lightened(0.2), 8)


# ----- Secondary tile (card + label + sublabel + accent dot) -----
func _style_tile(btn: Button, label: String, sub: String, accent: Color, hi: String = "", pulse: bool = false) -> void:
	if not btn: return
	# Clear button text — we'll draw our own children.
	btn.text = ""
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.clip_text = true

	var sb_normal = UITheme.make_card(UITheme.BG_CARD, UITheme.LINE, UITheme.R_MD)
	sb_normal.set_content_margin_all(14)
	var sb_hover = sb_normal.duplicate()
	sb_hover.bg_color = UITheme.BG_CARDHI
	sb_hover.border_color = UITheme.LINE_2
	var sb_pressed = sb_hover.duplicate()
	sb_pressed.border_color = accent
	btn.add_theme_stylebox_override("normal",  sb_normal)
	btn.add_theme_stylebox_override("hover",   sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_pressed)

	# Wipe any previously added overlay children to keep _ready idempotent.
	for c in btn.get_children():
		if c.name in ["TileLabel", "TileSub", "TileHi", "AccentDot", "CornerBrackets"]:
			c.queue_free()

	var lbl := Label.new()
	lbl.name = "TileLabel"
	lbl.text = label
	lbl.add_theme_color_override("font_color", UITheme.TEXT)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.position = Vector2(14, 12)
	lbl.size = Vector2(140, 18)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(lbl)

	var sublbl := Label.new()
	sublbl.name = "TileSub"
	sublbl.text = sub.to_upper()
	sublbl.add_theme_color_override("font_color", UITheme.TEXT_MUTE)
	sublbl.add_theme_font_size_override("font_size", 9)
	sublbl.position = Vector2(14, btn.size.y - 22)
	sublbl.size = Vector2(120, 14)
	sublbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(sublbl)
	# When the button gets resized, snap sublabel to bottom.
	btn.resized.connect(func():
		sublbl.position.y = btn.size.y - 22
	)

	if hi != "":
		var hi_lbl := Label.new()
		hi_lbl.name = "TileHi"
		hi_lbl.text = hi
		hi_lbl.add_theme_color_override("font_color", accent)
		hi_lbl.add_theme_font_size_override("font_size", 11)
		hi_lbl.position = Vector2(btn.size.x - 70, btn.size.y - 22)
		hi_lbl.size = Vector2(56, 14)
		hi_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hi_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(hi_lbl)
		btn.resized.connect(func():
			hi_lbl.position = Vector2(btn.size.x - 70, btn.size.y - 22)
		)

	if pulse:
		var dot := ColorRect.new()
		dot.name = "AccentDot"
		dot.color = accent
		dot.size = Vector2(6, 6)
		dot.position = Vector2(btn.size.x - 22, btn.size.y - 20)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(dot)
		btn.resized.connect(func():
			dot.position = Vector2(btn.size.x - 22, btn.size.y - 20)
		)

	UITheme.make_corner_brackets(btn, UITheme.LINE_2, 8)


# ----- Player chip (pill: LV·n | HI score | SP·n) -----
func _build_player_chip() -> void:
	if not player_chip: return
	for c in player_chip.get_children():
		c.queue_free()

	var bg := Panel.new()
	bg.name = "Bg"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := UITheme.make_pill(UITheme.BG_CARD, UITheme.LINE)
	sb.set_content_margin_all(8)
	bg.add_theme_stylebox_override("panel", sb)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_chip.add_child(bg)

	var prog = get_node_or_null("/root/Progression")
	var lv = prog.level if prog else 1
	var sp = prog.skill_points if prog else 0
	var hi = stats.get("high_score", 0)

	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 10)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_chip.add_child(hb)

	hb.add_child(_chip_seg("LV·%d" % lv, UITheme.LIME))
	hb.add_child(_chip_divider())
	hb.add_child(_chip_seg("HI %s" % _format_score(hi), UITheme.TEXT_MUTE))
	hb.add_child(_chip_divider())
	hb.add_child(_chip_seg("SP·%d" % sp, UITheme.CYAN))


func _chip_seg(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _chip_divider() -> ColorRect:
	var d := ColorRect.new()
	d.color = UITheme.LINE_2
	d.custom_minimum_size = Vector2(1, 10)
	return d


# ----- Bottom dotline (7 dots, first 3 lit by default) -----
func _build_dotline() -> void:
	if not dotline: return
	for c in dotline.get_children():
		c.queue_free()
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.alignment = BoxContainer.ALIGNMENT_END
	hb.add_theme_constant_override("separation", 4)
	dotline.add_child(hb)

	var lit = clamp(int(stats.get("total_games", 0)), 0, 7)
	for i in range(7):
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(4, 4)
		dot.color = UITheme.LIME if i < lit else UITheme.TEXT_DIM
		hb.add_child(dot)


# ----- Helpers -----
func _format_score(n: int) -> String:
	var s := str(n)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count == 3 and i > 0:
			out = "," + out
			count = 0
	return out


func _skill_sub() -> String:
	var prog = get_node_or_null("/root/Progression")
	if prog and prog.skill_points > 0:
		return "%d pts" % prog.skill_points
	return "tap to view"


func _update_play_sub() -> void:
	if not play_sub_label:
		return
	if has_save:
		play_sub_label.text = "▸ CONTINUE · ROUND %d · SCORE %s" % [save_round, _format_score(save_score)]
	else:
		play_sub_label.text = "FRESH RUN · NO SAVE"


func check_save_game():
	has_save = FileAccess.file_exists("user://game_save.save")
	# Best-effort peek for round/score — if the format isn't known, leave defaults.
	if has_save:
		var f = FileAccess.open("user://game_save.save", FileAccess.READ)
		if f:
			var data = f.get_var()
			if data is Dictionary:
				save_round = int(data.get("round", data.get("current_round", 1)))
				save_score = int(data.get("score", 0))
			f.close()


func _on_play():
	if FileAccess.file_exists("user://game_save.save"):
		DirAccess.remove_absolute("user://game_save.save")
	increment_stat("total_games")
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_multiplayer():
	get_tree().change_scene_to_file("res://scenes/multiplayer_menu.tscn")


func _on_resume():
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_stats():
	update_stats_display()
	stats_panel.visible = true


func _on_shop():
	pass


func update_stats_display():
	stats_text.text = "HIGH SCORE: %d\nBEST ROUND: %d\nTOTAL BRICKS: %d\nTOTAL ROUNDS: %d\nGAMES PLAYED: %d\nBOSSES KILLED: %d" % [
		stats.get("high_score", 0),
		stats.get("best_round", 0),
		stats.get("total_bricks", 0),
		stats.get("total_rounds", 0),
		stats.get("total_games", 0),
		stats.get("bosses_killed", 0),
	]


func load_stats():
	if FileAccess.file_exists(STATS_PATH):
		var file = FileAccess.open(STATS_PATH, FileAccess.READ)
		if file:
			var data = file.get_var()
			if data is Dictionary:
				stats = data
			file.close()


func save_stats():
	var file = FileAccess.open(STATS_PATH, FileAccess.WRITE)
	if file:
		file.store_var(stats)
		file.close()


func load_high_score():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			stats["high_score"] = file.get_var()
			file.close()


func increment_stat(key: String, amount: int = 1):
	stats[key] = stats.get(key, 0) + amount
	save_stats()


func update_stat(key: String, value: int):
	if value > stats.get(key, 0):
		stats[key] = value
		save_stats()
