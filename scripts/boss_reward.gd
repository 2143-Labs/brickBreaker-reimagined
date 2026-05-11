extends CanvasLayer
# Boss reward popup â€” shown after a full boss kill (round 50, 100, 150, â€¦, final boss).
# Presents 3 randomized options from a gated pool. Awards on tap, auto-closes.

signal reward_chosen(reward_id: String)

enum Reward {
    AMMO_15,
    NUKE_CHARGE,
    TRIPLE_SHOT,
    SEEING_DOUBLE,
    SUPER_BOMB,
    SUPER_RAILGUN,
    SUPER_BURN,
    SUPER_NUKE,
}

const REWARD_DATA := {
    Reward.AMMO_15:      {"id": "ammo_15",       "name": "+15 MAX AMMO",   "desc": "Permanent ammo bonus.",     "color_key": "LIME"},
    Reward.NUKE_CHARGE:  {"id": "nuke_charge",   "name": "+1 NUKE CHARGE", "desc": "Stockpile a nuke.",         "color_key": "ROSE"},
    Reward.TRIPLE_SHOT:  {"id": "triple_shot",   "name": "TRIPLE SHOT",    "desc": "Fire 3 balls per ammo.",    "color_key": "CYAN"},
    Reward.SEEING_DOUBLE:{"id": "seeing_double", "name": "SEEING DOUBLE",  "desc": "Hits split balls (50%).",   "color_key": "AMBER"},
    Reward.SUPER_BOMB:   {"id": "super_bomb",    "name": "SUPER BOMB",     "desc": "Cluster munitions.",        "color_key": "LIME"},
    Reward.SUPER_RAILGUN:{"id": "super_railgun", "name": "SUPER RAILGUN",  "desc": "Adjacent chain kills.",     "color_key": "CYAN"},
    Reward.SUPER_BURN:   {"id": "super_burn",    "name": "SUPER BURN",     "desc": "Spreads to neighbors.",     "color_key": "AMBER"},
    Reward.SUPER_NUKE:   {"id": "super_nuke",    "name": "SUPER NUKE",     "desc": "Radioactive winter.",       "color_key": "ROSE"},
}

var _options: Array = []  # Array of Reward enum values
var _manager: Node = null
func _ready():
    layer = 100
    process_mode = Node.PROCESS_MODE_ALWAYS  # operate while game is paused

func show_for_manager(manager: Node) -> void:
    _manager = manager
    _options = _build_pool(manager)
    _build_ui()
    if _manager:
        _manager.boss_reward_open = true

func _build_pool(manager: Node) -> Array:
    # Eligibility checks. Triple/Seeing/Super-X only offered if not already owned.
    # Weapon supers gated to weapons the player has (currently all 4 â€” no equip system yet).
    var eligible: Array = []
    if not manager.has_triple_shot:
        eligible.append(Reward.TRIPLE_SHOT)
    if not manager.has_seeing_double:
        eligible.append(Reward.SEEING_DOUBLE)
    if not manager.super_bomb:
        eligible.append(Reward.SUPER_BOMB)
    if not manager.super_railgun:
        eligible.append(Reward.SUPER_RAILGUN)
    if not manager.super_burn:
        eligible.append(Reward.SUPER_BURN)
    if not manager.super_nuke:
        eligible.append(Reward.SUPER_NUKE)
    # Always-valid filler
    eligible.append(Reward.AMMO_15)
    eligible.append(Reward.NUKE_CHARGE)
    eligible.shuffle()
    var picked: Array = []
    for r in eligible:
        if r in picked:
            continue
        picked.append(r)
        if picked.size() >= 3:
            break
    # If somehow under 3 (impossible since AMMO_15/NUKE_CHARGE are always added), pad with NUKE_CHARGE
    while picked.size() < 3:
        picked.append(Reward.NUKE_CHARGE)
    return picked

func _color_for(key: String) -> Color:
    match key:
        "LIME":  return UITheme.LIME
        "CYAN":  return UITheme.CYAN
        "AMBER": return UITheme.AMBER
        "ROSE":  return UITheme.ROSE
    return UITheme.TEXT

func _line_for(key: String) -> Color:
    match key:
        "LIME":  return UITheme.LIME_LINE
        "CYAN":  return UITheme.CYAN_LINE
        "AMBER": return UITheme.AMBER_LINE
        "ROSE":  return UITheme.ROSE_LINE
    return UITheme.LINE_STRONG
func _build_ui() -> void:
    # Fullscreen overlay
    var overlay := ColorRect.new()
    overlay.name = "Overlay"
    overlay.color = Color(UITheme.BG_DEEP.r, UITheme.BG_DEEP.g, UITheme.BG_DEEP.b, 0.78)
    overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # eat clicks behind
    add_child(overlay)

    # Title
    var title := Label.new()
    title.text = "BOSS DEFEATED"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_color_override("font_color", UITheme.TEXT)
    title.add_theme_font_size_override("font_size", 22)
    title.set_anchors_preset(Control.PRESET_TOP_WIDE)
    title.offset_top = 200
    title.offset_left = 0
    title.offset_right = 0
    overlay.add_child(title)

    var subtitle := Label.new()
    subtitle.text = "CHOOSE YOUR REWARD"
    subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle.add_theme_color_override("font_color", UITheme.TEXT_MUTE)
    subtitle.add_theme_font_size_override("font_size", 12)
    subtitle.set_anchors_preset(Control.PRESET_TOP_WIDE)
    subtitle.offset_top = 232
    overlay.add_child(subtitle)
    # 3 cards horizontally centered. Viewport = 390 wide. Card 110, gap 12 â†’ 110*3+12*2 = 354. Margin (390-354)/2 = 18.
    var card_w := 86
    var card_h := 130
    var gap := 22
    var total_w := card_w * 3 + gap * 2
    var start_x := (390 - total_w) / 2
    var y := 290

    for i in range(3):
        var reward_id: int = _options[i]
        var data: Dictionary = REWARD_DATA[reward_id]
        var col_key: String = data["color_key"]
        var col: Color = _color_for(col_key)
        var line: Color = _line_for(col_key)
        var btn := Button.new()
        btn.text = ""
        btn.flat = true
        btn.position = Vector2(start_x + i * (card_w + gap), y)
        btn.size = Vector2(card_w, card_h)
        btn.focus_mode = Control.FOCUS_NONE

        # Card stylebox using UITheme helper
        var sb := UITheme.make_card(UITheme.BG_CARD, line, UITheme.R_LG)
        var sb_h := sb.duplicate()
        sb_h.bg_color = UITheme.BG_CARDHI
        sb_h.border_color = col
        var sb_p := sb_h.duplicate()
        sb_p.bg_color = UITheme.BG_CARDHI.lightened(0.05)
        btn.add_theme_stylebox_override("normal", sb)
        btn.add_theme_stylebox_override("hover", sb_h)
        btn.add_theme_stylebox_override("pressed", sb_p)
        btn.add_theme_stylebox_override("focus", sb)
        overlay.add_child(btn)

        # Accent ring (decorative circle near top of card)
        var ring := Control.new()
        ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
        ring.set_anchors_preset(Control.PRESET_FULL_RECT)
        var ring_color := col
        ring.draw.connect(func():
            var center := Vector2(card_w / 2.0, 38)
            ring.draw_arc(center, 22, 0, TAU, 48, ring_color, 2.0)
            ring.draw_circle(center, 18, Color(ring_color.r, ring_color.g, ring_color.b, 0.18))
        )
        btn.add_child(ring)

        # Name label
        var name_lbl := Label.new()
        name_lbl.text = data["name"]
        name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
        name_lbl.add_theme_color_override("font_color", UITheme.TEXT)
        name_lbl.add_theme_font_size_override("font_size", 12)
        name_lbl.position = Vector2(6, 70)
        name_lbl.size = Vector2(card_w - 12, 30)
        name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
        btn.add_child(name_lbl)

        # Desc label
        var desc_lbl := Label.new()
        desc_lbl.text = data["desc"]
        desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
        desc_lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTE)
        desc_lbl.add_theme_font_size_override("font_size", 10)
        desc_lbl.position = Vector2(6, 98)
        desc_lbl.size = Vector2(card_w - 12, 36)
        desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
        btn.add_child(desc_lbl)

        # Corner brackets for that lofi look
        UITheme.make_corner_brackets(btn, col, 8)

        btn.pressed.connect(func(): _on_card_pressed(reward_id))
var _selected: bool = false

func _on_card_pressed(reward_id: int) -> void:
    if _selected:
        return
    _selected = true
    _apply_reward(reward_id)
    var data: Dictionary = REWARD_DATA[reward_id]
    emit_signal("reward_chosen", data["id"])
    if _manager and _manager.has_method("resume_round_after_reward"):
        _manager.resume_round_after_reward()
    queue_free()

func _apply_reward(reward_id: int) -> void:
    if _manager == null:
        return
    match reward_id:
        Reward.AMMO_15:
            _manager.bonus_ammo += 15
        Reward.NUKE_CHARGE:
            _manager.nuke_charges += 1
        Reward.TRIPLE_SHOT:
            _manager.has_triple_shot = true
        Reward.SEEING_DOUBLE:
            _manager.has_seeing_double = true
        Reward.SUPER_BOMB:
            _manager.super_bomb = true
        Reward.SUPER_RAILGUN:
            _manager.super_railgun = true
        Reward.SUPER_BURN:
            _manager.super_burn = true
        Reward.SUPER_NUKE:
            _manager.super_nuke = true
    # HUD refresh hooks if available
    if _manager.has_method("update_hud"):
        _manager.update_hud()
    if _manager.has_method("update_all_powerup_ui"):
        _manager.update_all_powerup_ui()