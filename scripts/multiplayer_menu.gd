extends Control

@onready var lobby_list = $Panel/VBox/HBox/SteamSection/Scroll/LobbyList
@onready var status_label = $Panel/VBox/StatusLabel
@onready var ip_input = $Panel/VBox/HBox/DirectSection/IPInput

@onready var host_steam_btn = $Panel/VBox/HBox/SteamSection/HostSteamBtn
@onready var invite_btn = $Panel/VBox/HBox/SteamSection/InviteBtn
@onready var refresh_steam_btn = $Panel/VBox/HBox/SteamSection/RefreshSteamBtn

func _ready():
	# Connect Buttons
	host_steam_btn.pressed.connect(_on_host_steam)
	invite_btn.pressed.connect(_on_invite_pressed)
	refresh_steam_btn.pressed.connect(_on_refresh_steam)
	
	$Panel/VBox/HBox/DirectSection/HostIPBtn.pressed.connect(_on_host_ip)
	$Panel/VBox/HBox/DirectSection/JoinIPBtn.pressed.connect(_on_join_ip)
	$Panel/BackButton.pressed.connect(_on_back)

	# Connect Manager Signals
	MultiplayerManager.lobby_list_received.connect(_on_lobbies_found)
	MultiplayerManager.connection_failed.connect(_on_connection_failed)
	MultiplayerManager.connection_succeeded.connect(_on_connected_ui_update)
	
	_style_ui()
	
	# Initial Steam Check
	if MultiplayerManager.is_on_steam:
		status_label.text = "STEAM ACTIVE: " + Steam.getPersonaName()
		invite_btn.visible = false
	else:
		status_label.text = "STEAM OFFLINE - DIRECT IP ONLY"
		$Panel/VBox/HBox/SteamSection.modulate.a = 0.5
		host_steam_btn.disabled = true
		refresh_steam_btn.disabled = true

func _style_ui():
	var panel_sb = UITheme.make_card(UITheme.BG_CARD, UITheme.LINE, UITheme.R_LG)
	$Panel.add_theme_stylebox_override("panel", panel_sb)
	
	# Style buttons using your UITheme logic
	_style_btn(host_steam_btn, UITheme.LIME)
	_style_btn(invite_btn, UITheme.AMBER)
	_style_btn(refresh_steam_btn, UITheme.CYAN)
	_style_btn($Panel/VBox/HBox/DirectSection/HostIPBtn, UITheme.LIME)
	_style_btn($Panel/VBox/HBox/DirectSection/JoinIPBtn, UITheme.CYAN)
	_style_btn($Panel/BackButton, UITheme.TEXT_MUTE)

func _style_btn(btn: Button, accent: Color):
	var sb_n = UITheme.make_card(UITheme.BG_CARDHI, UITheme.LINE_2, UITheme.R_MD)
	var sb_h = sb_n.duplicate()
	sb_h.border_color = accent
	btn.add_theme_stylebox_override("normal", sb_n)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_color_override("font_color", accent)

func _on_host_steam():
	MultiplayerManager.host_steam()
	status_label.text = "CREATING STEAM LOBBY..."

func _on_invite_pressed():
	MultiplayerManager.open_invite_dialog()

func _on_refresh_steam():
	for child in lobby_list.get_children(): child.queue_free()
	MultiplayerManager.find_steam_lobbies()
	status_label.text = "SEARCHING STEAM..."


func _on_lobbies_found(lobbies):
	status_label.text = "FOUND %d LOBBIES" % lobbies.size()
	for id in lobbies:
		var lobby_name = Steam.getLobbyData(id, "name")
		var ping = MultiplayerManager.get_ping_to_lobby(id)
		
		# Create the button container
		var h_box = HBoxContainer.new()
		var btn = Button.new()
		var ping_label = Label.new()
		
		# Format Ping Text
		var ping_text = ""
		var ping_color = Color(1, 1, 1) # Default White
		
		if ping == -1:
			ping_text = "[??? ms]"
			ping_color = UITheme.TEXT_DIM
		else:
			ping_text = "[%d ms]" % ping
			# Color coding based on latency
			if ping < 80: ping_color = UITheme.LIME
			elif ping < 150: ping_color = UITheme.AMBER
			else: ping_color = UITheme.ROSE
			
		ping_label.text = ping_text
		ping_label.add_theme_color_override("font_color", ping_color)
		ping_label.add_theme_font_size_override("font_size", 9)
		
		btn.text = lobby_name if lobby_name != "" else "Unnamed Lobby"
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 10)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		# Connect button
		btn.pressed.connect(func(): MultiplayerManager.join_steam_lobby(id))
		
		# Add to list
		h_box.add_child(ping_label)
		h_box.add_child(btn)
		lobby_list.add_child(h_box)

func _on_host_ip():
	MultiplayerManager.host_ip()
	status_label.text = "IP HOST STARTED"

func _on_join_ip():
	MultiplayerManager.join_ip(ip_input.text)
	status_label.text = "JOINING IP..."

func _on_connected_ui_update():
	status_label.text = "CONNECTED"
	# Show invite button if we are hosting a steam lobby
	if MultiplayerManager.using_steam and multiplayer.is_server():
		invite_btn.visible = true
		host_steam_btn.visible = false
	else:
		invite_btn.visible = false
		host_steam_btn.visible = true

func _on_connection_failed():
	status_label.text = "CONNECTION FAILED"
	invite_btn.visible = false
	host_steam_btn.visible = true

func _on_back():
	MultiplayerManager.close_connection()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
