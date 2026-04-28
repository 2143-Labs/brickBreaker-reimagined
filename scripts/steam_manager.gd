extends Node

# Signal for UI to update lobby lists
signal lobby_match_list(lobbies)

var peer = SteamMultiplayerPeer.new()
var is_on_steam: bool = false
var lobby_id: int = 0

func _ready():
	_initialize_steam()

func _initialize_steam():
	var response: Dictionary = Steam.steamInitEx()
	print("Steam Init: %s" % response)
	
	if response['status'] == 0:
		is_on_steam = true
		# Connect Steam signals
		
		Steam.lobby_match_list.connect(_on_lobby_match_list)
		Steam.lobby_created.connect(_on_lobby_created)
		Steam.join_requested.connect(_on_lobby_join_requested) # Steam "Join Game" from friend list
	else:
		is_on_steam = false
		print("Steam failed to initialize. Is Steam client open?")

func _process(_delta):
	if is_on_steam:
		Steam.run_callbacks()

# --- Lobby Logic ---

func create_steam_lobby():
	# Type 2 is "Public", Type 1 is "Friends Only"
	Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, 2)

func _on_lobby_created(connect_id: int, lobby_id_node: int):
	if connect_id == 1:
		self.lobby_id = lobby_id_node
		print("Lobby created: %s" % lobby_id)
		
		# Set metadata so others can find this game
		Steam.setLobbyData(lobby_id, "name", Steam.getPersonaName() + "'s Brick Breaker")
		Steam.setLobbyData(lobby_id, "version", "1.0")
		
		# Initialize the Multiplayer Peer
		var error = peer.create_host(lobby_id)
		if error == OK:
			multiplayer.multiplayer_peer = peer
			MultiplayerManager.is_multiplayer = true
			print("Steam Host Started")
		else:
			print("Failed to create Steam Host: %s" % error)

func find_lobbies():
	# Clear previous filters
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	Steam.requestLobbyList()

func _on_lobby_match_list(lobbies: Array):
	lobby_match_list.emit(lobbies)

func join_lobby(lobby_id_to_join: int):
	print("Joining lobby: %s" % lobby_id_to_join)
	var error = peer.create_client(lobby_id_to_join)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		MultiplayerManager.is_multiplayer = true
	else:
		print("Failed to join Steam Client: %s" % error)

func _on_lobby_join_requested(lobby_id_node: int, friend_id: int):
	join_lobby(lobby_id_node)
