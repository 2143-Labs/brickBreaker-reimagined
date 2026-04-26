extends Node

var players: Dictionary = {}
var multi_break_threshold: int = 3  # how many quick breaks to trigger multi sound
# Map our game events to your audio files
var sound_map: Dictionary = {
	"bounce": "brickcollision.wav",
	"bounce_alt": "brickcollision2.mp3",
	"hit": "brickimpact.wav",
	"destroy": "brickbreak1.wav",
	"destroy_alt": "brickbreak2.wav",
	"multi_destroy": "multibrickbreak.wav",
	"orb_collect": "ammoOrbActivate.wav",
	"explode": "bomb.wav",
	"nuke": "nuke.wav",
	"powerup": "ammoOrbActivate.mp3",
	"launch": "ballshoot.wav",
	"railgun": "railgunshot.mp3",
	"reload": "reload.wav",
	"menu_select": "menuselect.wav",
	"toggle": "toggle.wav",
	# combo escalation sounds (5..10)
	"combo5": "combo5.wav",
	"combo6": "combo6.wav",
	"combo7": "combo7.wav",
	"combo8": "combo8.wav",
	"combo9": "combo9.wav",
	"combo10": "combo10.wav",
}

var destroy_count: int = 0
var destroy_timer: float = 0.0
var destroy_window: float = 0.3  # seconds to count as "multi"
var use_alt_destroy: bool = false
var use_alt_bounce: bool = false

func _ready():
	for key in sound_map:
		var player = AudioStreamPlayer.new()
		player.volume_db = -8
		add_child(player)
		players[key] = player

		var filename = sound_map[key]
		var path = "res://assets/audio/%s" % filename
		if ResourceLoader.exists(path):
			player.stream = load(path)

	# Report loaded/missing streams for debugging
	var loaded = []
	var missing = []
	for k in players.keys():
		if players[k].stream:
			loaded.append(k)
		else:
			missing.append(k)
	print("SoundManager: loaded=", loaded, " missing=", missing)

func _process(delta):
	if destroy_timer > 0:
		destroy_timer -= delta
		if destroy_timer <= 0:
			destroy_count = 0
func play(sound_name: String):
	var mgr = get_tree().get_first_node_in_group("game_manager")
	if mgr and mgr.settings_menu:
		if not mgr.settings_menu.sfx_enabled:
			return
	if players.has(sound_name) and players[sound_name].stream:
		var temp = AudioStreamPlayer.new()
		temp.stream = players[sound_name].stream
		if mgr and mgr.settings_menu:
			var vol_key = sound_name
			if sound_name == "destroy_alt": vol_key = "destroy"
			if sound_name == "launch_alt": vol_key = "launch"
			if sound_name == "bounce_alt": vol_key = "bounce"
			temp.volume_db = mgr.settings_menu.get_volume_db(vol_key)
		else:
			temp.volume_db = 0
		add_child(temp)
		temp.play()
		temp.finished.connect(temp.queue_free)
func play_bounce():
	play("hit")

func play_hit():
	play("hit")
func play_destroy():
	use_alt_destroy = !use_alt_destroy
	var key = "destroy_alt" if use_alt_destroy else "destroy"
	print("play_destroy: key=%s, has_player=%s, has_stream=%s" % [key, players.has(key), players[key].stream if players.has(key) else "N/A"])
	play(key)

func play_orb():
	play("orb_collect")
func play_explode():
	play("explode")
	
func play_multi_destroy():
	play("multi_destroy")
	
func play_nuke():
	play("nuke")

func play_powerup():
	play("powerup")

func play_launch():
	# Alternate launch sounds
	if randi() % 2 == 0:
		play("launch")
	else:
		play("launch")
func play_railgun():
	play("railgun")

func play_reload():
	print("SoundManager.play_reload() called")
	play("reload")

func play_menu_select():
	play("menu_select")

func play_toggle():
	play("toggle")


func play_combo(combo_count: int) -> void:
	# Only play escalating combo sounds for 5 or more
	if combo_count < 5:
		return
	var key: String
	if combo_count >= 10:
		# For 10+, play combo10 on even counts to avoid spamming on every destroy
		if combo_count % 2 == 0:
			key = "combo10"
		else:
			return
	else:
		# 5..9 map directly to combo5..combo9
		key = "combo%d" % combo_count
	# Fallback safety: only play if mapping exists
	if sound_map.has(key):
		play(key)
	else:
		print("SoundManager: missing combo sound mapping for", key)


# stop_launch removed: we no longer use a looping launch sound
