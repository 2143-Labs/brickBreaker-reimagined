extends Area2D

var collected: bool = false
var ball_type: int = BallType.NORMAL

func _ready():
	ball_type = BallType.roll()
	queue_redraw()
	body_entered.connect(_on_body_entered)
	if has_node("MultiplayerSynchronizer"):
		$MultiplayerSynchronizer.synchronized.connect(queue_redraw)

func _draw():
	var c = BallType.color(ball_type) if ball_type != BallType.NORMAL else Color(0.3, 0.8, 0.4)
	var halo = Color(c.r, c.g, c.b, 0.3)
	var fill = Color(c.r, c.g, c.b, 0.9)
	draw_circle(Vector2.ZERO, 11, halo)
	draw_circle(Vector2.ZERO, 9, fill)
	draw_arc(Vector2.ZERO, 11, 0, TAU, 32, Color(1, 1, 1, 0.5), 1.5)

func _on_body_entered(body):
	if collected:
		return
	if not is_multiplayer_authority():
		return
	if body.is_in_group("balls"):
		collected = true
		var manager = get_tree().get_first_node_in_group("game_manager")
		if manager:
			manager.collect_ammo_orb(ball_type)
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2.ZERO, 0.15)
		tween.tween_callback(queue_free)
