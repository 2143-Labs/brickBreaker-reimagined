extends Node2D

enum LauncherType { DEFAULT, BOMB, RAILGUN, BURN, NUKE }

@export var launcher_type: int = LauncherType.DEFAULT
@export var aim_angle: float = -PI / 2.0  # pointing up by default
var is_aiming: bool = false
var anim_time: float = 0.0
var player_id: int = 1

# Railgun charge
var railgun_charge: float = 0.0
var railgun_charging: bool = false

# Burn pilot flame
var flame_time: float = 0.0

# Colors
var metal_dark = Color(0.35, 0.35, 0.38)
var metal_mid = Color(0.5, 0.5, 0.53)
var metal_light = Color(0.65, 0.65, 0.68)
var metal_highlight = Color(0.75, 0.75, 0.78)

func _process(delta):
	anim_time += delta
	flame_time += delta

	if railgun_charging:
		railgun_charge = min(railgun_charge + delta * 2.0, 1.0)
	else:
		railgun_charge = max(railgun_charge - delta * 4.0, 0.0)

	queue_redraw()

func set_type(type: int):
	launcher_type = type
	railgun_charging = (type == LauncherType.RAILGUN)
	queue_redraw()

func set_aim(angle: float):
	aim_angle = angle
	is_aiming = true

func clear_aim():
	is_aiming = false
	aim_angle = -PI / 2.0
	railgun_charging = false

func _draw():
	# Save transform, rotate to aim direction
	draw_set_transform(Vector2.ZERO, aim_angle + PI / 2.0, Vector2.ONE)
	match launcher_type:
		LauncherType.DEFAULT:
			_draw_default()
		LauncherType.BOMB:
			_draw_bomb()
		LauncherType.RAILGUN:
			_draw_railgun()
		LauncherType.BURN:
			_draw_burn()
		LauncherType.NUKE:
			_draw_nuke()

	# Reset transform
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func _draw_default():
	# Simple tube launcher
	# Base mount
	draw_circle(Vector2.ZERO, 12, metal_dark)
	draw_circle(Vector2.ZERO, 10, metal_mid)
	draw_circle(Vector2.ZERO, 6, metal_light)

	# Barrel
	var barrel_length = 22.0
	var barrel_width = 7.0
	draw_rect(Rect2(-barrel_width, -barrel_length, barrel_width * 2, barrel_length), metal_mid)
	# Barrel highlight (left edge)
	draw_line(Vector2(-barrel_width, -barrel_length), Vector2(-barrel_width, 0), metal_highlight, 1.5)
	# Barrel shadow (right edge)
	draw_line(Vector2(barrel_width, -barrel_length), Vector2(barrel_width, 0), metal_dark, 1.5)
	# Muzzle ring
	draw_line(Vector2(-barrel_width - 1, -barrel_length), Vector2(barrel_width + 1, -barrel_length), metal_light, 2.0)

	# Ball visible inside
	var col = Color(0.3, 0.55, 0.95, 0.7) if player_id == 1 else Color(0.95, 0.35, 0.4, 0.7)
	draw_circle(Vector2(0, -8), 5, col)

func _draw_bomb():
	# Wide cannon barrel
	# Base mount - larger
	draw_circle(Vector2.ZERO, 14, metal_dark)
	draw_circle(Vector2.ZERO, 12, Color(0.4, 0.35, 0.3))
	draw_circle(Vector2.ZERO, 7, Color(0.5, 0.45, 0.38))

	# Barrel - short and wide, tapers
	var points = PackedVector2Array([
		Vector2(-10, 0),
		Vector2(-8, -10),
		Vector2(-6, -20),
		Vector2(-9, -24),  # muzzle flare
		Vector2(9, -24),
		Vector2(6, -20),
		Vector2(8, -10),
		Vector2(10, 0),
	])
	draw_colored_polygon(points, Color(0.45, 0.4, 0.35))

	# Barrel bands
	draw_line(Vector2(-9, -8), Vector2(9, -8), metal_dark, 2.0)
	draw_line(Vector2(-7, -16), Vector2(7, -16), metal_dark, 2.0)
	# Muzzle ring
	draw_line(Vector2(-9, -24), Vector2(9, -24), Color(0.55, 0.5, 0.4), 2.5)

	# Fuse spark at tip
	var spark_offset = sin(anim_time * 10) * 2
	draw_circle(Vector2(spark_offset, -26), 3, Color(1.0, 0.7, 0.2, 0.6 + sin(anim_time * 15) * 0.3))
	draw_circle(Vector2(spark_offset, -26), 1.5, Color(1.0, 0.95, 0.7))

	# Cannonball visible
	draw_circle(Vector2(0, -10), 6, Color(0.25, 0.25, 0.25))
	draw_circle(Vector2(-2, -12), 2, Color(0.4, 0.4, 0.4, 0.5))  # highlight

func _draw_railgun():
	# Long thin barrel with energy rings
	# Base mount - techy
	draw_circle(Vector2.ZERO, 11, Color(0.25, 0.3, 0.35))
	draw_circle(Vector2.ZERO, 9, Color(0.3, 0.35, 0.4))
	# Tech lines on base
	draw_line(Vector2(-8, -2), Vector2(-8, 2), Color(0.2, 0.7, 0.9, 0.5), 1)
	draw_line(Vector2(8, -2), Vector2(8, 2), Color(0.2, 0.7, 0.9, 0.5), 1)

	# Long barrel
	var barrel_length = 32.0
	var barrel_width = 4.0
	draw_rect(Rect2(-barrel_width, -barrel_length, barrel_width * 2, barrel_length), Color(0.3, 0.33, 0.38))

	# Side rails
	draw_line(Vector2(-6, 0), Vector2(-6, -barrel_length + 2), Color(0.25, 0.28, 0.32), 2.0)
	draw_line(Vector2(6, 0), Vector2(6, -barrel_length + 2), Color(0.25, 0.28, 0.32), 2.0)
	# Coil wraps along barrel
	for i in range(4):
		var y = -6 - i * 7
		draw_line(Vector2(-5, y), Vector2(5, y), Color(0.35, 0.38, 0.42), 1.5)

	# Energy rings - 3 rings that charge up
	var ring_positions = [-10.0, -18.0, -26.0]
	var base_ring_col = Color(0.2, 0.5, 0.7, 0.3) if player_id == 1 else Color(0.7, 0.2, 0.4, 0.3)
	for i in range(3):
		var ring_y = ring_positions[i]
		var charge_threshold = (i + 1) / 3.0
		var is_charged = railgun_charge >= charge_threshold
		var ring_color = base_ring_col
		if is_charged:
			var pulse = 0.7 + 0.3 * sin(anim_time * 6 + i * 2)
			if player_id == 1:
				ring_color = Color(0.2, 0.8, 1.0, pulse)
				# Glow
				draw_circle(Vector2(0, ring_y), 8, Color(0.2, 0.8, 1.0, 0.15 * pulse))
			else:
				ring_color = Color(0.9, 0.3, 0.6, pulse)
				# Glow
				draw_circle(Vector2(0, ring_y), 8, Color(0.9, 0.3, 0.6, 0.15 * pulse))

		draw_arc(Vector2(0, ring_y), 7, 0, TAU, 16, ring_color, 2.0)

	# Muzzle glow when charged
	if railgun_charge > 0.8:
		var glow_pulse = 0.5 + 0.5 * sin(anim_time * 8)
		if player_id == 1:
			draw_circle(Vector2(0, -barrel_length), 4, Color(0.3, 0.9, 1.0, 0.3 * glow_pulse))
			draw_circle(Vector2(0, -barrel_length), 2, Color(0.8, 0.95, 1.0, 0.5 * glow_pulse))
		else:
			draw_circle(Vector2(0, -barrel_length), 4, Color(0.9, 0.4, 0.6, 0.3 * glow_pulse))
			draw_circle(Vector2(0, -barrel_length), 2, Color(1.0, 0.8, 0.9, 0.5 * glow_pulse))

	# Projectile visible inside
	var col = Color(0.3, 0.85, 1.0, 0.6) if player_id == 1 else Color(0.95, 0.35, 0.5, 0.6)
	draw_circle(Vector2(0, -8), 3, col)

func _draw_burn():
	# Flamethrower nozzle
	# Base mount
	draw_circle(Vector2.ZERO, 13, Color(0.4, 0.3, 0.25))
	draw_circle(Vector2.ZERO, 11, Color(0.5, 0.38, 0.3))

	# Tank on back (below pivot)
	draw_rect(Rect2(-8, 2, 16, 12), Color(0.45, 0.35, 0.28))
	draw_rect(Rect2(-6, 4, 12, 8), Color(0.55, 0.42, 0.3))
	# Pressure gauge
	draw_circle(Vector2(0, 8), 3, Color(0.6, 0.5, 0.4))
	draw_circle(Vector2(0, 8), 2, Color(0.8, 0.7, 0.5))
	
	# Wide nozzle barrel
	var nozzle_points = PackedVector2Array([
		Vector2(-6, 0),
		Vector2(-5, -12),
		Vector2(-8, -18),
		Vector2(-10, -22),
		Vector2(10, -22),
		Vector2(8, -18),
		Vector2(5, -12),
		Vector2(6, 0),
	])
	draw_colored_polygon(nozzle_points, Color(0.45, 0.35, 0.3))

	# Nozzle inner
	draw_rect(Rect2(-7, -22, 14, 4), Color(0.3, 0.22, 0.18))
	# Fuel lines on sides
	draw_line(Vector2(-7, 0), Vector2(-9, -18), Color(0.6, 0.45, 0.3), 1.5)
	draw_line(Vector2(7, 0), Vector2(9, -18), Color(0.6, 0.45, 0.3), 1.5)

	# Pilot flame at tip - always flickering
	var f1 = sin(flame_time * 12) * 2
	var f2 = cos(flame_time * 9) * 1.5
	var flame_base_y = -22.0

	# Outer flame (red)
	draw_circle(Vector2(f1 * 0.5, flame_base_y - 8 + f2), 5, Color(1.0, 0.3, 0.1, 0.3))
	# Mid flame (orange)
	draw_circle(Vector2(f1 * 0.3, flame_base_y - 6 + f2 * 0.5), 4, Color(1.0, 0.55, 0.15, 0.5))
	# Inner flame (yellow)
	draw_circle(Vector2(0, flame_base_y - 4), 3, Color(1.0, 0.8, 0.3, 0.6))
	# Core
	draw_circle(Vector2(0, flame_base_y - 3), 1.5, Color(1.0, 0.95, 0.7, 0.8))

func _draw_nuke():
	# Catapult arm
	# Base platform
	draw_rect(Rect2(-14, 0, 28, 8), Color(0.45, 0.35, 0.25))
	draw_rect(Rect2(-12, 2, 24, 4), Color(0.55, 0.42, 0.3))

	# Pivot post
	draw_rect(Rect2(-3, -6, 6, 10), Color(0.4, 0.32, 0.25))

	# Arm
	var arm_length = 28.0
	draw_line(Vector2(0, -6), Vector2(0, -arm_length), Color(0.5, 0.4, 0.3), 4.0)
	draw_line(Vector2(-1, -6), Vector2(-1, -arm_length), Color(0.55, 0.45, 0.35), 2.0)  # highlight

	# Bucket/sling at top
	var bucket_y = -arm_length
	draw_arc(Vector2(0, bucket_y), 8, PI * 0.1, PI * 0.9, 12, Color(0.4, 0.32, 0.25), 2.5)

	# Rope/sling lines
	draw_line(Vector2(-6, bucket_y + 2), Vector2(0, bucket_y + 6), Color(0.6, 0.5, 0.35), 1.5)
	draw_line(Vector2(6, bucket_y + 2), Vector2(0, bucket_y + 6), Color(0.6, 0.5, 0.35), 1.5)

	# Glowing nuke orb in bucket
	var pulse = 0.5 + 0.5 * sin(anim_time * 3)
	draw_circle(Vector2(0, bucket_y + 2), 7, Color(1.0, 0.9, 0.2, 0.2 + pulse * 0.15))
	draw_circle(Vector2(0, bucket_y + 2), 5, Color(0.95, 0.85, 0.15))
	draw_circle(Vector2(0, bucket_y + 2), 3, Color(1.0, 0.95, 0.5))
	# Radiation symbol hint
	draw_circle(Vector2(0, bucket_y + 2), 1.5, Color(0.3, 0.2, 0.0, 0.6))

	# Cross brace on base
	draw_line(Vector2(-10, 0), Vector2(-6, -6), Color(0.4, 0.32, 0.25), 2.0)
	draw_line(Vector2(10, 0), Vector2(6, -6), Color(0.4, 0.32, 0.25), 2.0)
