extends Node

# Sound effects loader
# Drop .wav or .ogg files into assets/audio/ with these names.
# If a file is missing, that sound simply won't play.

var sounds: Dictionary = {}
var players: Dictionary = {}

var sound_list = [
    "bounce",       # Ball hits wall
    "hit",          # Ball hits brick (doesn't destroy)
    "destroy",      # Brick destroyed
    "orb_collect",  # Ammo orb collected
    "explode",      # Explosive shot detonates
    "powerup",      # Powerup activated
    "launch",       # Ball stream starts firing
    "game_over",    # Game over triggered
    "round_end",    # Round completed
    "dust_land",    # Brick lands on another (dust effect)
]

func _ready():
    for snd in sound_list:
        var player = AudioStreamPlayer.new()
        player.volume_db = -6
        add_child(player)
        players[snd] = player

        # Try loading .wav then .ogg
        for ext in ["wav", "ogg"]:
            var path = "res://assets/audio/%s.%s" % [snd, ext]
            if ResourceLoader.exists(path):
                player.stream = load(path)
                break

func play(sound_name: String):
    if players.has(sound_name) and players[sound_name].stream:
        players[sound_name].play()

func play_bounce():
    play("bounce")

func play_hit():
    play("hit")

func play_destroy():
    play("destroy")
func play_orb():
    play("orb_collect")

func play_explode():
    play("explode")

func play_powerup():
    play("powerup")

func play_launch():
    play("launch")

func play_game_over():
    play("game_over")
func play_round_end():
    play("round_end")

func play_dust():
    play("dust_land")