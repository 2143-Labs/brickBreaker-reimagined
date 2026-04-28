extends Control

@onready var address_input = $Panel/VBoxContainer/AddressInput
@onready var host_button = $Panel/VBoxContainer/HostButton
@onready var join_button = $Panel/VBoxContainer/JoinButton
@onready var status_label = $Panel/VBoxContainer/StatusLabel
@onready var back_button = $Panel/BackButton
@onready var title_label = $Panel/VBoxContainer/Title

func _ready():
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	back_button.pressed.connect(_on_back_pressed)
	
	MultiplayerManager.connection_failed.connect(_on_connection_failed)
	MultiplayerManager.connection_succeeded.connect(_on_connection_succeeded)
	
	_style_ui()
	_detect_local_ip()

func _detect_local_ip():
	var ips = IP.get_local_addresses()
	var valid_ips = []
	for ip in ips:
		# Filter for standard local IPv4 addresses
		if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
			valid_ips.append(ip)
	
	if valid_ips.size() > 0:
		title_label.text = "MULTIPLAYER\nYour IP: " + valid_ips[0]
	else:
		title_label.text = "MULTIPLAYER"

func _style_ui():
	var panel_sb = UITheme.make_card(UITheme.BG_CARD, UITheme.LINE, UITheme.R_LG)
	$Panel.add_theme_stylebox_override("panel", panel_sb)
	
	_style_button(host_button, UITheme.LIME)
	_style_button(join_button, UITheme.CYAN)
	_style_button(back_button, UITheme.TEXT_MUTE)
	
	var input_sb = UITheme.make_card(UITheme.BG_INSET, UITheme.LINE, UITheme.R_SM)
	address_input.add_theme_stylebox_override("normal", input_sb)
	address_input.add_theme_stylebox_override("focus", input_sb)

func _style_button(btn: Button, accent: Color):
	var sb_n = UITheme.make_card(UITheme.BG_CARDHI, UITheme.LINE_2, UITheme.R_MD)
	var sb_h = sb_n.duplicate()
	sb_h.border_color = accent
	btn.add_theme_stylebox_override("normal", sb_n)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_color_override("font_color", accent)

func _on_host_pressed():
	status_label.text = "HOSTING... WAITING FOR P2"
	MultiplayerManager.host_game()

func _on_join_pressed():
	var addr = address_input.text.strip_edges()
	if addr == "": 
		addr = "127.0.0.1"
	status_label.text = "JOINING " + addr + "..."
	MultiplayerManager.join_game(addr)

func _on_connection_failed():
	status_label.text = "CONNECTION FAILED OR TIMED OUT"

func _on_connection_succeeded():
	if multiplayer.is_server():
		status_label.text = "HOSTING... WAITING FOR P2"
	else:
		status_label.text = "CONNECTED! WAITING FOR SYNC..."

func _on_back_pressed():
	# Cleanly abort any hung connection attempts when backing out
	MultiplayerManager.close_connection()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")