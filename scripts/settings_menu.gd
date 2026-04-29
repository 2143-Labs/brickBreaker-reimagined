extends CanvasLayer

const SETTINGS_PATH = "user://settings.save"

@onready var panel = $Panel
@onready var close_btn = $Panel/CloseButton
@onready var resume_btn = $Panel/ResumeButton
@onready var restart_btn = $Panel/RestartButton
@onready var menu_btn = $Panel/MenuButton
@onready var toggle_card = $Panel/ToggleCard
@onready var shake_toggle = $Panel/ToggleCard/ShakeToggle
@onready var shake_name_lbl = $Panel/ToggleCard/ShakeName
@onready var shake_label = $Panel/ToggleCard/ShakeLabel
@onready var grid_toggle = $Panel/ToggleCard/GridToggle
@onready var grid_name_lbl = $Panel/ToggleCard/GridName
@onready var grid_label = $Panel/ToggleCard/GridLabel
@onready var audio_card = $Panel/AudioCard
@onready var slider_container = $Panel/AudioCard/SliderContainer

var is_open: bool = false
var screen_shake_enabled: bool = true
var grid_enabled: bool = true
var music_enabled: bool = true
var sfx_enabled: bool = true

var volumes: Dictionary = {
	"master": 1.0,
	"launch": 0.7,
	"hit": 1.0,
	"destroy": 0.55,
	"multi_destroy": 0.8,
	"explode": 0.8,
	"nuke": 0.7,
	"railgun": 0.9,
	"orb_collect": 0.35,
	"reload": 0.5,
	"bounce": 1.0,
	"combo": 0.8,
	"music": 0.6,
}

var sliders: Dictionary = {}

func _ready():
	panel.visible = false
	load_settings()

	close_btn.pressed.connect(close_menu)
	resume_btn.pressed.connect(close_menu)
	restart_btn.pressed.connect(_on_restart)
	menu_btn.pressed.connect(_on_menu)
	shake_toggle.pressed.connect(_toggle_shake)
	grid_toggle.pressed.connect(_toggle_grid)

	_apply_styles()
	build_sliders()
	update_toggle_labels()


func _apply_styles():
	# Panel/card styleboxes
	var card_sb = UITheme.make_card(UITheme.BG_CARD, UITheme.LINE, UITheme.R_MD)
	toggle_card.add_theme_stylebox_override("panel", card_sb)
	audio_card.add_theme_stylebox_override("panel", card_sb.duplicate())

	# Action buttons
	_style_action(resume_btn, UITheme.LIME, true)
	_style_action(restart_btn, UITheme.TEXT_MUTE, false)
	_style_action(menu_btn, UITheme.ROSE, false)
	_style_action(close_btn, UITheme.TEXT_MUTE, false)


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


func build_sliders():
	for child in slider_container.get_children():
		child.queue_free()
	sliders.clear()

	var y = 0.0
	var names = {
		"master": "Master",
		"launch": "Ball Shoot",
		"hit": "Brick Impact",
		"destroy": "Brick Break",
		"multi_destroy": "Multi Break",
		"explode": "Explosion",
		"nuke": "Nuke",
		"railgun": "Railgun",
		"orb_collect": "Orb Collect",
		"reload": "Reload",
		"bounce": "Wall Bounce",
		"combo": "Combo",
		"music": "Music",
	}

	for key in volumes:
		var row = Control.new()
		row.position = Vector2(0, y)
		row.size = Vector2(330, 30)
		slider_container.add_child(row)

		var label = Label.new()
		label.text = names.get(key, key)
		label.position = Vector2(0, 7)
		label.size = Vector2(96, 18)
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", UITheme.TEXT)
		row.add_child(label)

		var slider = HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = volumes[key]
		slider.position = Vector2(98, 10)
		slider.size = Vector2(190, 12)
		# Slider styles — pill track + lime fill
		_style_slider(slider)
		row.add_child(slider)

		var val_label = Label.new()
		val_label.text = "%d" % int(volumes[key] * 100)
		val_label.position = Vector2(298, 7)
		val_label.size = Vector2(36, 18)
		val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_label.add_theme_font_size_override("font_size", 11)
		val_label.add_theme_color_override("font_color", UITheme.TEXT_MUTE)
		row.add_child(val_label)

		var divider = ColorRect.new()
		divider.color = UITheme.LINE
		divider.position = Vector2(0, 28)
		divider.size = Vector2(330, 1)
		row.add_child(divider)

		var k = key
		var vl = val_label
		slider.value_changed.connect(func(val):
			volumes[k] = val
			vl.text = "%d" % int(val * 100)
			vl.add_theme_color_override("font_color", UITheme.TEXT_DIM if val == 0 else UITheme.TEXT_MUTE)
			apply_volumes()
			save_settings()
		)

		sliders[key] = slider
		y += 30.0


func _style_slider(slider: HSlider):
	var track = StyleBoxFlat.new()
	track.bg_color = UITheme.BG_INSET
	track.set_corner_radius_all(999)
	track.set_border_width_all(1)
	track.border_color = UITheme.LINE
	track.set_content_margin_all(2)

	var fill = StyleBoxFlat.new()
	fill.bg_color = UITheme.LIME
	fill.set_corner_radius_all(999)

	var grabber = StyleBoxFlat.new()
	grabber.bg_color = UITheme.TEXT
	grabber.set_corner_radius_all(999)
	grabber.set_border_width_all(2)
	grabber.border_color = UITheme.BG_BASE

	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)


func apply_volumes():
	var manager = get_tree().get_first_node_in_group("game_manager")
	if manager and manager.sound_manager:
		var sm = manager.sound_manager
		var master = volumes.get("master", 0.8)
		for key in sm.players:
			var vol_key = key
			if key == "destroy_alt": vol_key = "destroy"
			if key == "launch_alt": vol_key = "launch"
			if key == "bounce_alt": vol_key = "bounce"
			var sound_vol = volumes.get(vol_key, 0.8)
			var final_vol = master * sound_vol
			if final_vol <= 0:
				sm.players[key].volume_db = -80
			else:
				sm.players[key].volume_db = linear_to_db(final_vol)
		var music_vol = volumes.get("music", 0.6)
		MusicManager.set_volume(music_vol * master)


func get_volume(sound_key: String) -> float:
	var master = volumes.get("master", 0.8)
	var sound_vol = volumes.get(sound_key, 0.8)
	return master * sound_vol


func get_volume_db(sound_key: String) -> float:
	var vol = get_volume(sound_key)
	if vol <= 0:
		return -80
	return linear_to_db(vol)


func toggle_menu():
	if is_open:
		close_menu()
	else:
		open_menu()


func open_menu():
	is_open = true
	panel.visible = true
	get_tree().paused = true


func close_menu():
	is_open = false
	panel.visible = false
	get_tree().paused = false
	var mgr = get_tree().get_first_node_in_group("game_manager")
	if mgr:
		if mgr.has_method("refresh_draw"):
			mgr.refresh_draw()
		else:
			mgr.queue_redraw()


func _on_restart():
	close_menu()
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


func _on_menu():
	close_menu()
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _toggle_shake():
	screen_shake_enabled = !screen_shake_enabled
	update_toggle_labels()
	save_settings()


func _toggle_grid():
	grid_enabled = !grid_enabled
	save_settings()
	update_toggle_labels()
	var mgr = get_tree().get_first_node_in_group("game_manager")
	if mgr:
		if mgr.has_method("refresh_draw"):
			mgr.refresh_draw()
		else:
			mgr.queue_redraw()


func _toggle_music():
	music_enabled = !music_enabled
	MusicManager.set_music_enabled(music_enabled)
	update_toggle_labels()
	save_settings()


func update_toggle_labels():
	_set_toggle_visual(shake_toggle, screen_shake_enabled)
	_set_toggle_visual(grid_toggle, grid_enabled)


func _set_toggle_visual(btn: Button, on: bool):
	if not btn: return
	btn.text = ""
	var sb = StyleBoxFlat.new()
	sb.set_corner_radius_all(999)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(2)
	if on:
		sb.bg_color = Color(UITheme.LIME.r, UITheme.LIME.g, UITheme.LIME.b, 0.18)
		sb.border_color = UITheme.LIME
	else:
		sb.bg_color = UITheme.BG_INSET
		sb.border_color = UITheme.LINE
	btn.add_theme_stylebox_override("normal",  sb)
	btn.add_theme_stylebox_override("hover",   sb)
	btn.add_theme_stylebox_override("pressed", sb)

	# Inline thumb — replace existing
	var thumb = btn.get_node_or_null("Thumb")
	if thumb:
		thumb.queue_free()
	thumb = ColorRect.new()
	thumb.name = "Thumb"
	thumb.size = Vector2(16, 16)
	thumb.color = UITheme.LIME if on else UITheme.TEXT_MUTE
	thumb.position = Vector2(34 if on else 2, 2)
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Round the thumb via canvas item modulate; ColorRect can't be circular cheaply.
	# Use a Panel instead so we can give it a round stylebox.
	thumb.queue_free()
	var thumb_panel = Panel.new()
	thumb_panel.name = "Thumb"
	thumb_panel.size = Vector2(16, 16)
	thumb_panel.position = Vector2(34 if on else 2, 2)
	thumb_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tb = StyleBoxFlat.new()
	tb.bg_color = UITheme.LIME if on else UITheme.TEXT_MUTE
	tb.set_corner_radius_all(999)
	thumb_panel.add_theme_stylebox_override("panel", tb)
	btn.add_child(thumb_panel)


func save_settings():
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_var({
			"shake": screen_shake_enabled,
			"grid": grid_enabled,
			"volumes": volumes,
		})
		file.close()


func load_settings():
	if FileAccess.file_exists(SETTINGS_PATH):
		var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if file:
			var data = file.get_var()
			if data is Dictionary:
				screen_shake_enabled = data.get("shake", true)
				grid_enabled = data.get("grid", true)
				var saved_vols = data.get("volumes", {})
				for key in saved_vols:
					if volumes.has(key):
						volumes[key] = saved_vols[key]
			file.close()
