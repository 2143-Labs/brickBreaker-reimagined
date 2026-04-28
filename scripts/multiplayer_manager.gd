extends Node

signal connection_failed
signal connection_succeeded
signal player_connected(id)
signal player_disconnected(id)
signal game_started

var peer = ENetMultiplayerPeer.new()
const DEFAULT_PORT = 7777
const DEFAULT_IP = "127.0.0.1"

var is_multiplayer: bool = false

func host_game(port = DEFAULT_PORT):
	var error = peer.create_server(port, 2)
	if error != OK:
		print("Failed to host: ", error)
		connection_failed.emit()
		return error
	
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	
	is_multiplayer = true
	print("Hosting on port ", port)
	connection_succeeded.emit()
	return OK

func join_game(address = DEFAULT_IP, port = DEFAULT_PORT):
	var error = peer.create_client(address, port)
	if error != OK:
		print("Failed to join: ", error)
		connection_failed.emit()
		return error
	
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connection_succeeded)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	is_multiplayer = true
	print("Joining ", address, ":", port)
	return OK

func _on_player_connected(id):
	print("Player connected: ", id)
	player_connected.emit(id)
	# For a 2-player game, we can auto-start when someone joins
	if multiplayer.is_server():
		start_game.rpc()

func _on_player_disconnected(id):
	print("Player disconnected: ", id)
	player_disconnected.emit(id)
	is_multiplayer = false

func _on_connection_succeeded():
	print("Connected to server")
	connection_succeeded.emit()

func _on_connection_failed():
	print("Connection failed")
	is_multiplayer = false
	connection_failed.emit()

func _on_server_disconnected():
	print("Server disconnected")
	is_multiplayer = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

@rpc("authority", "call_local")
func start_game():
	game_started.emit()
	get_tree().change_scene_to_file("res://scenes/main.tscn")
