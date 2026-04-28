extends Node

signal connection_failed
signal connection_succeeded
signal player_connected(id)
signal player_disconnected(id)
signal game_started
signal lobby_list_received(lobbies)

var enet_peer: ENetMultiplayerPeer
var steam_peer: SteamMultiplayerPeer

var is_multiplayer: bool = false
var is_on_steam: bool = false
var lobby_id: int = 0
var using_steam: bool = false

const DEFAULT_PORT = 7777

func _ready():
	_initialize_steam()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _initialize_steam():
	# Check if the Steam object exists (GDExtension loaded)
	if not Engine.has_singleton("Steam"):
		is_on_steam = false
		print("Steam GDExtension not found!")
		return

	var response = Steam.steamInitEx()
	if response['status'] == 0:
		is_on_steam = true
		print("Steam Initialized: ", Steam.getPersonaName())
		Steam.lobby_created.connect(_on_lobby_created)
		Steam.lobby_match_list.connect(_on_lobby_match_list)
		Steam.join_requested.connect(_on_lobby_join_requested)
	else:
		is_on_steam = false
		print("Steam Failed to Initialize.")
func _process(_delta):
	if is_on_steam:
		Steam.run_callbacks()

# --- STEAM LOGIC ---

func host_steam():
	if not is_on_steam: return
	close_connection()
	using_steam = true
	Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, 2)

func _on_lobby_created(result: int, new_lobby_id: int):
	if result == 1: # k_EResultOK
		lobby_id = new_lobby_id
		
		# 1. Set the metadata so others can find us
		Steam.setLobbyData(lobby_id, "name", Steam.getPersonaName() + "'s Lofi Room")
		Steam.setLobbyData(lobby_id, "game", "lofi_brick_breaker")
		
		# 2. IMPORTANT: Store the Host's Steam ID in the lobby
		# Clients need to know WHICH Steam User to connect to, not just the Lobby ID
		var host_steam_id = Steam.getSteamID()
		Steam.setLobbyData(lobby_id, "host_steam_id", str(host_steam_id))
		
		steam_peer = SteamMultiplayerPeer.new()
		
		# 3. FIX: create_host(virtual_port)
		# We use 0 as the virtual port. Do NOT pass lobby_id here.
		var error = steam_peer.create_host(0)
		
		if error == OK:
			multiplayer.multiplayer_peer = steam_peer
			is_multiplayer = true
			connection_succeeded.emit()
			print("Steam Host set on virtual port 0")
		else:
			print("Steam Host Error: ", error)
			connection_failed.emit()
	else:
		connection_failed.emit()

func join_steam_lobby(id: int):
	close_connection()
	using_steam = true
	
	# 1. Get the Host's Steam ID from the lobby metadata
	# We need the user's ID to establish the P2P connection
	Steam.requestLobbyData(id)
	# We wait a tiny bit for data or just pull it if it's already there from the search
	var host_steam_id = Steam.getLobbyData(id, "host_steam_id").to_int()
	
	if host_steam_id == 0:
		print("Failed to get host Steam ID from lobby")
		connection_failed.emit()
		return

	steam_peer = SteamMultiplayerPeer.new()
	
	# 2. FIX: create_client(host_id, virtual_port)
	var error = steam_peer.create_client(host_steam_id, 0)
	
	if error == OK:
		multiplayer.multiplayer_peer = steam_peer
		is_multiplayer = true
		lobby_id = id
		connection_succeeded.emit()
	else:
		print("Steam Join Error: ", error)
		connection_failed.emit()

# --- IP / ENET LOGIC ---

func host_ip():
	close_connection()
	using_steam = false
	enet_peer = ENetMultiplayerPeer.new()
	var error = enet_peer.create_server(DEFAULT_PORT, 2)
	if error == OK:
		multiplayer.multiplayer_peer = enet_peer
		is_multiplayer = true
		connection_succeeded.emit()
	else:
		connection_failed.emit()

func join_ip(address: String):
	close_connection()
	using_steam = false
	enet_peer = ENetMultiplayerPeer.new()
	if address == "": address = "127.0.0.1"
	var error = enet_peer.create_client(address, DEFAULT_PORT)
	if error == OK:
		multiplayer.multiplayer_peer = enet_peer
		is_multiplayer = true
		connection_succeeded.emit()
	else:
		connection_failed.emit()

# --- COMMON ---

func close_connection():
	if multiplayer.multiplayer_peer != null:
		if using_steam and lobby_id != 0: 
			Steam.leaveLobby(lobby_id)
		multiplayer.multiplayer_peer = null
	
	steam_peer = null
	enet_peer = null
	is_multiplayer = false
	lobby_id = 0

func open_invite_dialog():
	if is_on_steam and lobby_id != 0:
		Steam.activateGameOverlayInviteDialog(lobby_id)

func _on_peer_connected(id):
	if multiplayer.is_server():
		start_game.rpc()

func _on_peer_disconnected(id):
	player_disconnected.emit(id)

func _on_server_disconnected():
	close_connection()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func find_steam_lobbies():
	if not is_on_steam: return
	Steam.addRequestLobbyListStringFilter("game", "lofi_brick_breaker", Steam.LOBBY_COMPARISON_EQUAL)
	Steam.requestLobbyList()

func _on_lobby_match_list(lobbies: Array):
	lobby_list_received.emit(lobbies)

func _on_lobby_join_requested(id: int, _friend: int):
	join_steam_lobby(id)

@rpc("authority", "call_local", "reliable")
func start_game():
	get_tree().change_scene_to_file("res://scenes/main.tscn")