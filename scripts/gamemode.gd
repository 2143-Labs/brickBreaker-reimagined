# game_mode.gd (autoload as GameMode)
extends Node

enum Mode { CLASSIC, INVASION, VERSUS }

var current: Mode = Mode.CLASSIC

var configs = {
    Mode.CLASSIC: {
        "label": "CLASSIC",
        "desc": "Break blocks. Chill vibes.",
        "color": UITheme.LIME,
        "scene": "res://scenes/main.tscn"
    },
    Mode.INVASION: {
        "label": "INVASION",
        "desc": "They're coming for you.",
        "color": UITheme.ROSE,
        "scene": "res://scenes/main.tscn"  # same scene, different behavior
    },
    Mode.VERSUS: {
        "label": "VERSUS",
        "desc": "Two launchers. One winner.",
        "color": UITheme.CYAN,
        "scene": "res://scenes/main.tscn"
    },
}

func set_mode(m: Mode):
    current = m

func get_config() -> Dictionary:
    return configs[current]

func is_classic() -> bool: return current == Mode.CLASSIC
func is_invasion() -> bool: return current == Mode.INVASION
func is_versus() -> bool:   return current == Mode.VERSUS
