extends CanvasLayer

const SETTINGS_PATH = "user://settings.save"
@onready var panel = $Panel
@onready var resume_btn = $Panel/ResumeButton
@onready var restart_btn = $Panel/RestartButton
@onready var menu_btn = $Panel/MenuButton
@onready var shake_toggle = $Panel/ShakeToggle
@onready var shake_label = $Panel/ShakeLabel
@onready var slider_container = $Panel/SliderContainer

var is_open: bool = false
var screen_shake_enabled: bool = true
var music_enabled: bool = true
var sfx_enabled: bool = true

# Per-sound volume (0.0 to 1.0)
var volumes: Dictionary = {
    "master": 0.8,
    "launch": 0.7,
    "hit": 0.5,
    "destroy": 0.8,
    "multi_destroy": 0.8,
    "explode": 0.8,
    "nuke": 0.7,
    "railgun": 0.7,
    "orb_collect": 0.6,
    "reload": 0.5,
    "bounce": 0.4,
}

var sliders: Dictionary = {}
func _ready():
    panel.visible = false
    load_settings()

    resume_btn.pressed.connect(close_menu)
    restart_btn.pressed.connect(_on_restart)
    menu_btn.pressed.connect(_on_menu)
    shake_toggle.pressed.connect(_toggle_shake)

    build_sliders()
    update_toggle_labels()

func build_sliders():
    for child in slider_container.get_children():
        child.queue_free()
    sliders.clear()

    var y = 0.0
    var names = {
        "master": "Master",
        "launch": "Ball Shoot",
        "hit": "Brick Impact",
        "destroy": "Brick Break",
        "multi_destroy": "Multi Break",
        "explode": "Explosion",
        "nuke": "Nuke",
        "railgun": "Railgun",
        "orb_collect": "Orb Collect",
        "reload": "Reload",
        "bounce": "Wall Bounce",
    }

    for key in volumes:
        var row = HBoxContainer.new()
        row.position = Vector2(0, y)
        row.size = Vector2(280, 25)
        slider_container.add_child(row)

        var label = Label.new()
        label.text = names.get(key, key)
        label.custom_minimum_size = Vector2(90, 20)
        label.add_theme_font_size_override("font_size", 10)
        label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
        row.add_child(label)
        var slider = HSlider.new()
        slider.min_value = 0.0
        slider.max_value = 1.0
        slider.step = 0.05
        slider.value = volumes[key]
        slider.custom_minimum_size = Vector2(140, 20)
        row.add_child(slider)

        var val_label = Label.new()
        val_label.text = "%d%%" % int(volumes[key] * 100)
        val_label.custom_minimum_size = Vector2(40, 20)
        val_label.add_theme_font_size_override("font_size", 10)
        val_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
        row.add_child(val_label)
        var k = key
        var vl = val_label
        slider.value_changed.connect(func(val):
            volumes[k] = val
            vl.text = "%d%%" % int(val * 100)
            apply_volumes()
            save_settings()
        )

        sliders[key] = slider
        y += 28.0

func apply_volumes():
    var manager = get_tree().get_first_node_in_group("game_manager")
    if manager and manager.sound_manager:
        var sm = manager.sound_manager
        var master = volumes.get("master", 0.8)
        for key in sm.players:
            var vol_key = key
            # Map alt sounds to their base
            if key == "destroy_alt": vol_key = "destroy"
            if key == "launch_alt": vol_key = "launch"
            if key == "bounce_alt": vol_key = "bounce"
            var sound_vol = volumes.get(vol_key, 0.8)
            var final_vol = master * sound_vol
            # Convert 0-1 to dB (-80 to 0)
            if final_vol <= 0:
                sm.players[key].volume_db = -80
            else:
                sm.players[key].volume_db = linear_to_db(final_vol)
func get_volume(sound_key: String) -> float:
    var master = volumes.get("master", 0.8)
    var sound_vol = volumes.get(sound_key, 0.8)
    return master * sound_vol

func get_volume_db(sound_key: String) -> float:
    var vol = get_volume(sound_key)
    if vol <= 0:
        return -80
    return linear_to_db(vol)

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

func update_toggle_labels():
    shake_label.text = "Screen Shake: %s" % ("ON" if screen_shake_enabled else "OFF")
    shake_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4) if screen_shake_enabled else Color(0.8, 0.3, 0.3))

func save_settings():
    var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
    if file:
        file.store_var({
            "shake": screen_shake_enabled,
            "volumes": volumes,
        })
        file.close()

func load_settings():
    if FileAccess.file_exists(SETTINGS_PATH):
        var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
        if file:
            var data = file.get_var()
            if data is Dictionary:
                screen_shake_enabled = data.get("shake", true)
                var saved_vols = data.get("volumes", {})
                for key in saved_vols:
                    if volumes.has(key):
                        volumes[key] = saved_vols[key]
            file.close()