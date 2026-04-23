extends CanvasLayer

const SETTINGS_PATH = "user://settings.save"
@onready var panel = $Panel
@onready var resume_btn = $Panel/ResumeButton
@onready var restart_btn = $Panel/RestartButton
@onready var menu_btn = $Panel/MenuButton
@onready var shake_toggle = $Panel/ShakeToggle
@onready var music_toggle = $Panel/MusicToggle
@onready var sfx_toggle = $Panel/SFXToggle
@onready var shake_label = $Panel/ShakeLabel
@onready var music_label = $Panel/MusicLabel
@onready var sfx_label = $Panel/SFXLabel

var is_open: bool = false

# Settings
var screen_shake_enabled: bool = true
var music_enabled: bool = true
var sfx_enabled: bool = true

func _ready():
    panel.visible = false
    load_settings()

    resume_btn.pressed.connect(close_menu)
    restart_btn.pressed.connect(_on_restart)
    menu_btn.pressed.connect(_on_menu)
    shake_toggle.pressed.connect(_toggle_shake)
    music_toggle.pressed.connect(_toggle_music)
    sfx_toggle.pressed.connect(_toggle_sfx)
    update_toggle_labels()

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

func _toggle_music():
    music_enabled = !music_enabled
    update_toggle_labels()
    save_settings()
    # TODO: actually mute/unmute music bus

func _toggle_sfx():
    sfx_enabled = !sfx_enabled
    update_toggle_labels()
    save_settings()

func update_toggle_labels():
    shake_label.text = "Screen Shake: %s" % ("ON" if screen_shake_enabled else "OFF")
    shake_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4) if screen_shake_enabled else Color(0.8, 0.3, 0.3))
    music_label.text = "Music: %s" % ("ON" if music_enabled else "OFF")
    music_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4) if music_enabled else Color(0.8, 0.3, 0.3))
    sfx_label.text = "SFX: %s" % ("ON" if sfx_enabled else "OFF")
    sfx_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4) if sfx_enabled else Color(0.8, 0.3, 0.3))

func save_settings():
    var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
    if file:
        file.store_var({
            "shake": screen_shake_enabled,
            "music": music_enabled,
            "sfx": sfx_enabled,
        })
        file.close()

func load_settings():
    if FileAccess.file_exists(SETTINGS_PATH):
        var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
        if file:
            var data = file.get_var()
            if data is Dictionary:
                screen_shake_enabled = data.get("shake", true)
                music_enabled = data.get("music", true)
                sfx_enabled = data.get("sfx", true)
            file.close()