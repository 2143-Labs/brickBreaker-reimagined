extends Area2D
enum PickupType { DOUBLE_AMMO, DOUBLE_DAMAGE, NUKE_CHARGE }

var pickup_type: int = PickupType.DOUBLE_AMMO
var collected: bool = false

func _ready():
	queue_redraw()
	body_entered.connect(_on_body_entered)
	if has_node("MultiplayerSynchronizer"):
		$MultiplayerSynchronizer.synchronized.connect(queue_redraw)

func _draw():
	match pickup_type:
		PickupType.DOUBLE_AMMO:
			draw_circle(Vector2.ZERO, 13, Color(0.9, 0.7, 0.2, 0.25))
			draw_circle(Vector2.ZERO, 11, Color(0.9, 0.65, 0.15))
			draw_string(ThemeDB.fallback_font, Vector2(-8, 5), "2x", HORIZONTAL_ALIGNMENT_CENTER, 16, 9, Color(1, 1, 1))
		PickupType.DOUBLE_DAMAGE:
			draw_circle(Vector2.ZERO, 13, Color(0.9, 0.2, 0.15, 0.25))
			draw_circle(Vector2.ZERO, 11, Color(0.85, 0.25, 0.2))
			draw_string(ThemeDB.fallback_font, Vector2(-8, 5), "2x", HORIZONTAL_ALIGNMENT_CENTER, 16, 9, Color(1, 1, 1))
		PickupType.NUKE_CHARGE:
			draw_circle(Vector2.ZERO, 13, Color(1.0, 0.9, 0.2, 0.3))
			draw_circle(Vector2.ZERO, 11, Color(0.95, 0.85, 0.15))
			draw_string(ThemeDB.fallback_font, Vector2(-7, 5), "N", HORIZONTAL_ALIGNMENT_CENTER, 14, 12, Color(0.3, 0.1, 0.0))

func _on_body_entered(body):
	if collected:
		return
	if not is_multiplayer_authority():
		return
	if body.is_in_group("balls"):
		collected = true
		var manager = get_tree().get_first_node_in_group("game_manager")
		if manager:
			manager.collect_pickup(pickup_type)
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
		tween.tween_property(self, "scale", Vector2.ZERO, 0.15)
		tween.tween_callback(queue_free)
