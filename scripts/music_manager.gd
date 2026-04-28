extends Node

var menu_player: AudioStreamPlayer
var game_player: AudioStreamPlayer

var menu_track: String = "res://assets/music/Chill.mp3"
var game_tracks: Array = [
	"res://assets/music/Chill Wave.mp3",
	"res://assets/music/Dub Eastern.mp3",
	"res://assets/music/Equatorial Complex.mp3",
	"res://assets/music/Impact Prelude.mp3",
]

var shuffle_queue: Array = []
var current_track_index: int = -1
var max_volume_db: float = -4.4  # roughly 60% volume

var is_playing_menu: bool = false
var is_playing_game: bool = false
var music_enabled: bool = true
func _ready():
	menu_player = AudioStreamPlayer.new()
	menu_player.bus = "Master"
	menu_player.volume_db = max_volume_db
	add_child(menu_player)

	game_player = AudioStreamPlayer.new()
	game_player.bus = "Master"
	game_player.volume_db = max_volume_db
	game_player.finished.connect(_on_track_finished)
	add_child(game_player)

	# Load menu track
	if ResourceLoader.exists(menu_track):
		var stream = load(menu_track)
		if stream is AudioStreamMP3:
			stream.loop = true
		menu_player.stream = stream

	reshuffle()

func reshuffle():
	shuffle_queue = game_tracks.duplicate()
	shuffle_queue.shuffle()
	current_track_index = 0

func _on_track_finished():
	if is_playing_game and music_enabled:
		play_next_game_track()
func play_next_game_track():
	# Only the server (or singleplayer) decides the next track
	if MP.is_client():
		return

	if shuffle_queue.size() == 0:
		reshuffle()
	if current_track_index >= shuffle_queue.size():
		reshuffle()

	var path = shuffle_queue[current_track_index]
	current_track_index += 1

	if MP.is_server():
		_play_specific_track_rpc.rpc(path, 0.0)
	else:
		_play_specific_track_rpc(path, 0.0)

@rpc("authority", "call_local", "reliable")
func _play_specific_track_rpc(path: String, playback_pos: float):
	if ResourceLoader.exists(path):
		var stream = load(path)
		if stream is AudioStreamMP3:
			stream.loop = false
		game_player.stream = stream
		game_player.volume_db = max_volume_db
		game_player.play(playback_pos)

func sync_current_track_to_clients():
	if is_playing_game and game_player.stream != null:
		var path = game_player.stream.resource_path
		var pos = game_player.get_playback_position()
		_play_specific_track_rpc.rpc(path, pos)

func start_menu_music():
	if not music_enabled:
		return
	stop_game_music()
	is_playing_menu = true
	is_playing_game = false
	if menu_player.stream:
		menu_player.volume_db = max_volume_db
		menu_player.play()

func stop_menu_music():
	is_playing_menu = false
	menu_player.stop()
func start_game_music():
	if not music_enabled:
		return
	stop_menu_music()
	is_playing_game = true
	is_playing_menu = false
	play_next_game_track()

func stop_game_music():
	is_playing_game = false
	game_player.stop()

func stop_all():
	stop_menu_music()
	stop_game_music()

func set_music_enabled(enabled: bool):
	music_enabled = enabled
	if not enabled:
		stop_all()
	else:
		# Resume whatever context we're in
		if is_playing_menu:
			start_menu_music()
		elif is_playing_game:
			start_game_music()

func set_volume(vol_percent: float):
	# vol_percent 0.0-1.0, capped at 60%
	var capped = min(vol_percent, 0.6)
	if capped <= 0:
		max_volume_db = -80
	else:
		max_volume_db = linear_to_db(capped)
	menu_player.volume_db = max_volume_db
	game_player.volume_db = max_volume_db

func pause_game_music():
	if is_playing_game and game_player.playing:
		var tween = create_tween()
		tween.tween_property(game_player, "volume_db", -40, 0.3)
		tween.tween_callback(func(): game_player.stream_paused = true)

func resume_game_music():
	if is_playing_game and game_player.stream_paused:
		game_player.stream_paused = false
		game_player.volume_db = -40
		var tween = create_tween()
		tween.tween_property(game_player, "volume_db", max_volume_db, 0.3)
