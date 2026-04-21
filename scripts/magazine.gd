extends Node2D

var tube_points: PackedVector2Array = PackedVector2Array()
var ball_positions: Array = []
var total_ammo: int = 0
var balls_in_tube: int = 0
var tube_color = Color(0.72, 0.72, 0.75, 1.0)
var tube_inner_color = Color(0.82, 0.82, 0.85, 1.0)
var ball_color = Color(0.3, 0.55, 0.95)
var tube_width: float = 22.0
var ball_spacing_in_tube: float = 15.0

var entrance_x: float = 195.0
var target_entrance_x: float = 195.0

var pipe_left: float = 13.0
var pipe_right: float = 377.0
var row_height: float = 24.0
var num_rows: int = 7
var entrance_drop: float = 12.0
var is_shifting: bool = false
var shift_duration: float = 0.4
var shift_progress: float = 0.0
var shift_from_x: float = 195.0

var marker_offset: float = 0.0
var marker_speed: float = 30.0

var plop_balls: Array = []

func _ready():
	build_tube_path()
	queue_redraw()
func build_tube_path():
	tube_points.clear()
	var x = entrance_x
	var y = 0.0

	tube_points.append(Vector2(x, y))
	tube_points.append(Vector2(x, y + entrance_drop))
	y += entrance_drop

	for row in range(num_rows):
		if row % 2 == 0:
			tube_points.append(Vector2(pipe_right, y))
			y += row_height
			tube_points.append(Vector2(pipe_right, y))
		else:
			tube_points.append(Vector2(pipe_left, y))
			y += row_height
			tube_points.append(Vector2(pipe_left, y))

	recalculate_ball_positions()

func get_tube_length() -> float:
	var length = 0.0
	for i in range(tube_points.size() - 1):
		length += tube_points[i].distance_to(tube_points[i + 1])
	return length

func get_point_at_distance(dist: float) -> Vector2:
	var accumulated = 0.0
	for i in range(tube_points.size() - 1):
		var seg_len = tube_points[i].distance_to(tube_points[i + 1])
		if accumulated + seg_len >= dist:
			var t = (dist - accumulated) / seg_len
			return tube_points[i].lerp(tube_points[i + 1], t)
		accumulated += seg_len
	return tube_points[tube_points.size() - 1]

func get_direction_at_distance(dist: float) -> Vector2:
	var accumulated = 0.0
	for i in range(tube_points.size() - 1):
		var seg_len = tube_points[i].distance_to(tube_points[i + 1])
		if accumulated + seg_len >= dist:
			return (tube_points[i + 1] - tube_points[i]).normalized()
		accumulated += seg_len
	return Vector2.DOWN
func recalculate_ball_positions():
	ball_positions.clear()
	for i in range(total_ammo):
		var dist = 6.0 + i * ball_spacing_in_tube
		ball_positions.append(dist)

func set_ammo(count: int):
	total_ammo = count
	balls_in_tube = count
	recalculate_ball_positions()
	queue_redraw()

func fire_ball():
	if balls_in_tube > 0:
		balls_in_tube -= 1
		queue_redraw()

func return_ball():
	balls_in_tube += 1
	if balls_in_tube > total_ammo:
		balls_in_tube = total_ammo
	queue_redraw()

func add_ball_plop():
	var new_idx = total_ammo
	total_ammo += 1
	balls_in_tube += 1
	recalculate_ball_positions()
	if new_idx < ball_positions.size():
		plop_balls.append({
			"dist": ball_positions[new_idx],
			"progress": 0.0,
			"duration": 0.5
		})
	queue_redraw()

func set_all_returned():
	balls_in_tube = total_ammo
	queue_redraw()

func shift_entrance_to(new_x: float):
	if abs(new_x - entrance_x) < 2.0:
		return
	shift_from_x = entrance_x
	target_entrance_x = new_x
	is_shifting = true
	shift_progress = 0.0

func _process(delta):
	# Flow toward entrance (reversed)
	marker_offset -= marker_speed * delta
	if marker_offset < 0.0:
		marker_offset += 25.0

	if is_shifting:
		shift_progress += delta / shift_duration
		if shift_progress >= 1.0:
			shift_progress = 1.0
			is_shifting = false
		var t = 1.0 - pow(1.0 - shift_progress, 3)
		entrance_x = lerp(shift_from_x, target_entrance_x, t)
		build_tube_path()

	var finished = []
	for i in range(plop_balls.size()):
		plop_balls[i]["progress"] += delta / plop_balls[i]["duration"]
		if plop_balls[i]["progress"] >= 1.0:
			finished.append(i)
	for i in range(finished.size() - 1, -1, -1):
		plop_balls.remove_at(finished[i])

	queue_redraw()

func _draw():
	if tube_points.size() < 2:
		return

	for i in range(tube_points.size() - 1):
		draw_line(tube_points[i], tube_points[i + 1], tube_color, tube_width, true)
	for i in range(tube_points.size() - 1):
		draw_line(tube_points[i], tube_points[i + 1], tube_inner_color, tube_width - 6, true)
	for i in range(tube_points.size()):
		draw_circle(tube_points[i], tube_width / 2.0, tube_color)
		draw_circle(tube_points[i], (tube_width - 6) / 2.0, tube_inner_color)

	var entrance_pos = tube_points[0]
	draw_circle(entrance_pos, tube_width / 2.0 + 3, Color(0.65, 0.65, 0.68, 1.0))
	draw_circle(entrance_pos, tube_width / 2.0, tube_inner_color)
	var bolt_color = Color(0.55, 0.55, 0.58, 1.0)
	draw_circle(entrance_pos + Vector2(-tube_width/2 - 1, 0), 3, bolt_color)
	draw_circle(entrance_pos + Vector2(tube_width/2 + 1, 0), 3, bolt_color)

	var tube_len = get_tube_length()
	var marker_spacing = 25.0
	var marker_color = Color(0.6, 0.6, 0.63, 0.4)
	var d = marker_offset
	while d < tube_len:
		var pos = get_point_at_distance(d)
		var dir = get_direction_at_distance(d)
		var perp = Vector2(-dir.y, dir.x)
		var tip = pos - dir * 4
		var left_pt = pos + dir * 2 + perp * 3
		var right_pt = pos + dir * 2 - perp * 3
		draw_line(left_pt, tip, marker_color, 1.5)
		draw_line(right_pt, tip, marker_color, 1.5)
		d += marker_spacing

	for i in range(balls_in_tube):
		if i < ball_positions.size():
			var pos = get_point_at_distance(ball_positions[i])
			var is_plop = false
			for pb in plop_balls:
				if abs(pb["dist"] - ball_positions[i]) < 1.0:
					is_plop = true
					var t = pb["progress"]
					var scale_t = 1.0
					if t < 0.4:
						scale_t = (t / 0.4) * 1.3
					elif t < 0.6:
						scale_t = lerp(1.3, 0.9, (t - 0.4) / 0.2)
					else:
						scale_t = lerp(0.9, 1.0, (t - 0.6) / 0.4)
					var r = 7.0 * scale_t
					var c = Color(0.3, 0.8, 0.4).lerp(ball_color, t)
					draw_circle(pos, r, c)
					if t < 0.5:
						draw_circle(pos, r + 4, Color(0.3, 0.8, 0.4, 0.3 * (1.0 - t * 2)))
					break
			if not is_plop:
				draw_circle(pos, 7, ball_color)
				draw_circle(pos + Vector2(-2, -2), 2.5, Color(0.5, 0.7, 1.0, 0.3))
