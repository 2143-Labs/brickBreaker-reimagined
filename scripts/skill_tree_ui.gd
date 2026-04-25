extends Control

@onready var back_button = $BackButton
@onready var sp_label = $SPLabel
@onready var level_label = $LevelLabel
@onready var xp_bar = $XPBar
@onready var xp_label = $XPLabel
@onready var talent_container = $TalentContainer

var talent_buttons: Dictionary = {}
func _ready():
    back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
    build_talent_grid()
    update_display()

func build_talent_grid():
    for child in talent_container.get_children():
        child.queue_free()
    talent_buttons.clear()

    var prog = get_node("/root/Progression")
    var cell_w = 175.0
    var cell_h = 90.0
    for key in prog.talent_defs:
        var def = prog.talent_defs[key]
        var rank = prog.talents[key]
        var max_rank = def["max"]

        var panel = Panel.new()
        panel.position = Vector2(def["col"] * cell_w + 10, def["row"] * cell_h + 10)
        panel.size = Vector2(cell_w - 15, cell_h - 10)
        talent_container.add_child(panel)

        var name_label = Label.new()
        name_label.text = def["name"]
        name_label.position = Vector2(8, 5)
        name_label.add_theme_font_size_override("font_size", 12)
        name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.92))
        panel.add_child(name_label)

        var rank_label = Label.new()
        rank_label.text = "%d / %d" % [rank, max_rank]
        rank_label.position = Vector2(8, 22)
        rank_label.add_theme_font_size_override("font_size", 10)
        if rank >= max_rank:
            rank_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.2))
        else:
            rank_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
        panel.add_child(rank_label)

        var desc_label = Label.new()
        desc_label.text = def["desc"]
        desc_label.position = Vector2(8, 38)
        desc_label.size = Vector2(cell_w - 30, 25)
        desc_label.add_theme_font_size_override("font_size", 8)
        desc_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
        desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
        panel.add_child(desc_label)

        if rank < max_rank:
            var btn = Button.new()
            btn.text = "+"
            btn.position = Vector2(cell_w - 45, 5)
            btn.size = Vector2(25, 25)
            btn.add_theme_font_size_override("font_size", 14)
            var k = key  # capture
            btn.pressed.connect(func():
                if prog.spend_skill_point(k):
                    build_talent_grid()
                    update_display()
            )
            panel.add_child(btn)
            talent_buttons[key] = btn

func update_display():
    var prog = get_node("/root/Progression")
    sp_label.text = "Skill Points: %d" % prog.skill_points
    level_label.text = "Level %d" % prog.level
    xp_label.text = "%d / %d XP" % [prog.xp, prog.xp_for_current_level()]
    xp_bar.value = prog.xp_progress() * 100