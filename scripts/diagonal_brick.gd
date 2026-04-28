extends StaticBody2D

var health: int = 1
var max_health: int = 1
var burn_stacks: int = 0
# 0 = no top-left corner, 1 = no top-right, 2 = no bottom-right, 3 = no bottom-left
var orientation: int = 0

@onready var collision_polygon: CollisionPolygon2D = $CollisionPolygon2D
@onready var health_label = $HealthLabel

var is_dying: bool = false
var last_hit_direction: Vector2 = Vector2.DOWN
var hit_flash: float = 0.0

const HW: float = 25.0
const HH: float = 18.0

func get_color_for_hp(hp: int) -> Color:
	if hp >= 100: return Color(0.55, 0.2, 0.7)
	elif hp >= 50: return Color(0.4, 0.55, 0.9)
	elif hp >= 20: return Color(0.95, 0.65, 0.3)
	elif hp >= 10: return Color(0.93, 0.5, 0.45)
	elif hp >= 5: return Color(0.95, 0.85, 0.4)
	else: return Color(0.6, 0.85, 0.55)

func get_brick_color(ratio: float) -> Color:
	return get_color_for_hp(max_health).lightened((1.0 - ratio) * 0.25)

func _get_polygon() -> PackedVector2Array:
	var tl = Vector2(-HW, -HH)
	var tr = Vector2(HW, -HH)
	var br = Vector2(HW, HH)
	var bl = Vector2(-HW, HH)
	match orientation:
		0: return PackedVector2Array([tr, br, bl])  # missing top-left
		1: return PackedVector2Array([tl, br, bl])  # missing top-right
		2: return PackedVector2Array([tl, tr, bl])  # missing bottom-right
		3: return PackedVector2Array([tl, tr, br])  # missing bottom-left
	return PackedVector2Array([tl, tr, br])

func _get_label_offset() -> Vector2:
	# Place HP counter in the meaty part of the triangle, away from the hypotenuse
	match orientation:
		0: return Vector2(6, 4)    # mass toward bottom-right
		1: return Vector2(-6, 4)   # mass toward bottom-left
		2: return Vector2(-6, -4)  # mass toward top-left
		3: return Vector2(6, -4)   # mass toward top-right
	return Vector2.ZERO
func _ready():
	add_to_group("diagonal_bricks")
	_init_shape()
	
	if has_node("MultiplayerSynchronizer"):
		$MultiplayerSynchronizer.synchronized.connect(func():
			_init_shape()
			update_display()
			queue_redraw()
		)

func _init_shape():
	if collision_polygon:
		collision_polygon.polygon = _get_polygon()
	if health_label:
		var off = _get_label_offset()
		health_label.offset_left = off.x - 14
		health_label.offset_top = off.y - 10
		health_label.offset_right = off.x + 14
		health_label.offset_bottom = off.y + 10
	update_display()
	queue_redraw()



func _process(delta):
	if hit_flash > 0.0:
		hit_flash = max(0.0, hit_flash - delta * 4.0)
		queue_redraw()

func _draw():
	var pts = _get_polygon()
	var ratio = clamp(float(health) / max(max_health, 1), 0.0, 1.0)
	var base = get_brick_color(ratio)
	if hit_flash > 0.0:
		base = base.lerp(Color(1, 1, 1), hit_flash * 0.6)
	draw_polygon(pts, PackedColorArray([base, base, base]))
	var outline = pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(0.15, 0.12, 0.1, 0.8), 1.5, true)

func take_damage(amount: int, hit_dir: Vector2 = Vector2.DOWN, _is_special: bool = false):
	if not is_multiplayer_authority():
		return
	last_hit_direction = hit_dir
	health -= amount
	hit_flash = 1.0
	update_display()
	queue_redraw()
	if health <= 0:
		destroy()

func add_burn_stack():
	burn_stacks += 1

func process_burn():
	if burn_stacks > 0:
		take_damage(burn_stacks)
		burn_stacks = int(burn_stacks / 2.0)

func apply_explosion_crack(_ring: int):
	take_damage(1)

func update_display():
	if health_label:
		health_label.text = str(max(health, 0))
		health_label.add_theme_color_override("font_color", Color(1, 1, 1))
		health_label.add_theme_font_size_override("font_size", 14)

func destroy():
	if is_dying: return
	is_dying = true
	var manager = get_tree().get_first_node_in_group("game_manager")
	if manager:
		manager.add_score(get_brick_value())
		var ratio = clamp(float(health) / max(max_health, 1), 0.0, 1.0)
		var col = get_brick_color(ratio)
		manager.spawn_brick_particles_directional(global_position, col, last_hit_direction)
		manager.spawn_score_popup(global_position, get_brick_value())
		manager.on_brick_destroyed()
	queue_free()

func get_brick_value() -> int:
	if max_health < 10: return 1
	elif max_health < 50: return 2
	elif max_health < 100: return 3
	elif max_health < 150: return 4
	elif max_health < 200: return 5
	else: return 10
