extends Control

const SAVE_PATH = "user://highscore.save"
const STATS_PATH = "user://stats.save"

@onready var title_label = $TitleLabel
@onready var play_button = $PlayButton
@onready var resume_button = $ResumeButton
@onready var stats_button = $StatsButton
@onready var shop_button = $ShopButton
@onready var stats_panel = $StatsPanel
@onready var stats_text = $StatsPanel/StatsText
@onready var stats_close = $StatsPanel/CloseButton

var stats: Dictionary = {
    "high_score": 0,
    "best_round": 0,
    "total_bricks": 0,
    "total_rounds": 0,
    "total_games": 0,
    "bosses_killed": 0,
}

var has_save: bool = false
var anim_time: float = 0.0

func _ready():
    load_stats()
    load_high_score()
    check_save_game()

    play_button.pressed.connect(_on_play)
    resume_button.pressed.connect(_on_resume)
    stats_button.pressed.connect(_on_stats)
    shop_button.pressed.connect(_on_shop)
    stats_close.pressed.connect(func(): stats_panel.visible = false)

    resume_button.visible = has_save
    stats_panel.visible = false
func _process(delta):
    anim_time += delta
    # Subtle title color pulse
    if title_label:
        var hue_shift = sin(anim_time * 0.5) * 0.03
        title_label.add_theme_color_override("font_color", Color(0.95 + hue_shift, 0.95 + hue_shift, 0.97, 1))

func check_save_game():
    has_save = FileAccess.file_exists("user://game_save.save")

func _on_play():
    # New game
    if FileAccess.file_exists("user://game_save.save"):
        DirAccess.remove_absolute("user://game_save.save")
    increment_stat("total_games")
    get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_resume():
    get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_stats():
    update_stats_display()
    stats_panel.visible = true

func _on_shop():
    # Placeholder - shop not built yet
    pass

func update_stats_display():
    stats_text.text = """HIGH SCORE: %d
BEST ROUND: %d
TOTAL BRICKS: %d
TOTAL ROUNDS: %d
GAMES PLAYED: %d
BOSSES KILLED: %d""" % [
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