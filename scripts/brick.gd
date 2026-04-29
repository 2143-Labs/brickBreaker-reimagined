extends StaticBody2D
var health: int = 1
var max_health: int = 1
var burn_stacks: int = 0

@onready var sprite = $Sprite
@onready var health_label = $HealthLabel

var crack_level: int = 0
var crack_overlay: Node2D = null
var fire_overlay: ColorRect = null
var fire_material: ShaderMaterial = null
var last_hit_direction: Vector2 = Vector2.DOWN

const BURN_SHADER = preload("res://assets/shaders/burn.gdshader")

var is_dying: bool = false
var railgun_death: bool = false
var railgun_direction: Vector2 = Vector2.ZERO
var railgun_hit_offset: Vector2 = Vector2.ZERO

# Stacking damage tracking: how many times same ball stream hit this brick
var hit_count: int = 0

static var tier_thresholds = [5, 10, 20, 50, 100]

func get_color_for_hp(hp: int) -> Color:
	if hp >= 100: return Color(0.55, 0.2, 0.7)
	elif hp >= 50: return Color(0.4, 0.55, 0.9)
	elif hp >= 20: return Color(0.95, 0.65, 0.3)
	elif hp >= 10: return Color(0.93, 0.5, 0.45)
	elif hp >= 5: return Color(0.95, 0.85, 0.4)
	else: return Color(0.6, 0.85, 0.55)
func get_next_tier_color(hp: int) -> Color:
	if hp >= 100: return Color(0.4, 0.55, 0.9)
	elif hp >= 50: return Color(0.95, 0.65, 0.3)
	elif hp >= 20: return Color(0.93, 0.5, 0.45)
	elif hp >= 10: return Color(0.95, 0.85, 0.4)
	elif hp >= 5: return Color(0.6, 0.85, 0.55)
	else: return Color(0.8, 0.9, 0.8)

func get_brick_color(ratio: float) -> Color:
	var base = get_color_for_hp(max_health)
	return base.lightened((1.0 - ratio) * 0.25)
func _ready():
	update_display()
	crack_overlay = Node2D.new()
	crack_overlay.z_index = 1
	add_child(crack_overlay)
	crack_overlay.draw.connect(_draw_cracks)

	fire_overlay = ColorRect.new()
	fire_overlay.z_index = 2
	fire_overlay.visible = false
	fire_overlay.color = Color(1, 1, 1, 1)
	fire_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fire_overlay.offset_left = -30.0
	fire_overlay.offset_right = 30.0
	fire_overlay.offset_top = -50.0
	fire_overlay.offset_bottom = 18.0
	fire_material = ShaderMaterial.new()
	fire_material.shader = BURN_SHADER
	fire_material.set_shader_parameter("intensity", 0.0)
	fire_material.set_shader_parameter("seed", randf() * 100.0)
	fire_material.set_shader_parameter("source_y", 0.47)
	fire_overlay.material = fire_material
	add_child(fire_overlay)
	
	if has_node("MultiplayerSynchronizer"):
		$MultiplayerSynchronizer.synchronized.connect(update_display)

	if health_label:
		var mat = CanvasItemMaterial.new()
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		health_label.material = mat

func _process(_delta):
	if burn_stacks > 0:
		if fire_overlay:
			fire_overlay.visible = true
			var intensity = clamp(burn_stacks / 8.0, 0.15, 1.0)
			fire_material.set_shader_parameter("intensity", intensity)
	elif fire_overlay:
		fire_overlay.visible = false

func take_damage(amount: int, hit_dir: Vector2 = Vector2.DOWN, _is_special: bool = false):
	if not is_multiplayer_authority():
		return
	last_hit_direction = hit_dir

	# Stacking damage bonus
	hit_count += 1
	var stack_max = Progression.get_stacking_damage_max()
	if stack_max > 0:
		var stack_bonus = min(hit_count - 1, stack_max)
		amount += stack_bonus

	# Cracked bricks take 2x damage
	if crack_level > 0:
		amount *= 2

	health -= amount
	update_display()

	if sprite and health > 0:
		var next_color = get_next_tier_color(health)
		var tween = create_tween()
		tween.tween_property(sprite, "color", next_color, 0.06)
		tween.tween_property(sprite, "color", get_brick_color(clamp(float(health) / max(max_health, 1), 0.0, 1.0)), 0.12)

	if health <= 0:
		destroy()
func add_burn_stack():
	burn_stacks += 1
	if fire_overlay:
		fire_overlay.visible = true

func process_burn():
	if burn_stacks > 0:
		# Burn mastery adds extra ticks by making decay slower
		var extra = Progression.get_burn_extra_ticks()
		if extra > 0 and burn_stacks > 1:
			take_damage(burn_stacks)
			# Slower decay: divide by less
			burn_stacks = int(burn_stacks / max(2.0 - extra * 0.2, 1.2))
		else:
			take_damage(burn_stacks)
			burn_stacks = int(burn_stacks / 2.0)

func apply_explosion_crack(ring: int):
	if ring == 0: crack_level = 3
	elif ring == 1: crack_level = max(crack_level, 2)
	else: crack_level = max(crack_level, 1)
	if crack_overlay:
		crack_overlay.queue_redraw()

func _draw_cracks():
	if crack_level <= 0: return
	var hw = 24.0
	var hh = 17.0
	var crack_alpha = 0.3 + crack_level * 0.2
	var crack_width = 1.0 + crack_level * 0.4
	var crack_color = Color(0.1, 0.08, 0.05, crack_alpha)
	var rng = RandomNumberGenerator.new()
	rng.seed = int(position.x * 100 + position.y * 7)
	var num_cracks = crack_level * 2 + 1
	for i in range(num_cracks):
		var start = Vector2(rng.randf_range(-hw * 0.5, hw * 0.5), rng.randf_range(-hh * 0.5, hh * 0.5))
		var angle = rng.randf_range(0, TAU)
		var length = rng.randf_range(6, 8 + crack_level * 5)
		var end = start + Vector2(cos(angle), sin(angle)) * length
		end.x = clamp(end.x, -hw, hw)
		end.y = clamp(end.y, -hh, hh)
		crack_overlay.draw_line(start, end, crack_color, crack_width)
		if crack_level >= 2 and rng.randf() > 0.3:
			var b_angle = angle + rng.randf_range(-0.8, 0.8)
			var b_len = length * rng.randf_range(0.3, 0.6)
			var b_end = end + Vector2(cos(b_angle), sin(b_angle)) * b_len
			b_end.x = clamp(b_end.x, -hw, hw)
			b_end.y = clamp(b_end.y, -hh, hh)
			crack_overlay.draw_line(end, b_end, crack_color, crack_width * 0.7)
	if crack_level >= 3:
		for i in range(4):
			var angle = rng.randf_range(0, TAU)
			var length = rng.randf_range(12, 22)
			var end = Vector2(cos(angle), sin(angle)) * length
			end.x = clamp(end.x, -hw, hw)
			end.y = clamp(end.y, -hh, hh)
			crack_overlay.draw_line(Vector2.ZERO, end, crack_color, crack_width * 1.2)

func update_display():
	if health_label:
		health_label.text = str(health)
		health_label.add_theme_color_override("font_color", Color(1, 1, 1))
		health_label.add_theme_font_size_override("font_size", 16)
	if sprite:
		var ratio = clamp(float(health) / max(max_health, 1), 0.0, 1.0)
		sprite.color = get_brick_color(ratio)

func destroy():
	if is_dying: return
	is_dying = true
	var manager = get_tree().get_first_node_in_group("game_manager")
	if manager:
		var points = get_brick_value()
		manager.add_score(points)
	if railgun_death:
		collision_layer = 0
		collision_mask = 0
		if crack_overlay:
			crack_level = 0
			crack_overlay.queue_redraw()
		var tunnel = Node2D.new()
		tunnel.z_index = 3
		add_child(tunnel)
		var dir = railgun_direction
		var perp = Vector2(-dir.y, dir.x)
		var offset = railgun_hit_offset
		var hw = 25.0
		var hh = 18.0
		tunnel.draw.connect(func():
			var center = offset
			var channel_width = 3.0
			var glow_width = 7.0
			var step = dir * 1.0
			var start = center
			var end = center
			for i in range(40):
				var test = center - step * (i + 1)
				if abs(test.x) > hw or abs(test.y) > hh: break
				start = test
			for i in range(40):
				var test = center + step * (i + 1)
				if abs(test.x) > hw or abs(test.y) > hh: break
				end = test
			tunnel.draw_line(start, end, Color(1.0, 0.5, 0.1, 0.5 * tunnel.modulate.a), glow_width)
			tunnel.draw_line(start + perp * channel_width, end + perp * channel_width, Color(1.0, 0.7, 0.2, 0.8 * tunnel.modulate.a), 1.5)
			tunnel.draw_line(start - perp * channel_width, end - perp * channel_width, Color(1.0, 0.7, 0.2, 0.8 * tunnel.modulate.a), 1.5)
			tunnel.draw_line(start, end, Color(0.08, 0.04, 0.0, 0.9 * tunnel.modulate.a), channel_width)
		)
		tunnel.queue_redraw()
		if sprite:
			var tween = create_tween()
			tween.tween_property(sprite, "modulate", Color(2, 2, 2, 1), 0.08)
			tween.tween_property(sprite, "modulate", Color(0.5, 0.3, 0.5, 0.8), 0.15)
			tween.tween_interval(0.3)
			tween.tween_callback(func():
				var mgr = get_tree().get_first_node_in_group("game_manager")
				if mgr and sprite:
					mgr.spawn_brick_particles_directional(global_position, Color(0.6, 0.2, 0.9), railgun_direction)
					mgr.spawn_brick_particles_directional(global_position, Color(0.7, 0.3, 1.0), railgun_direction)
					mgr.add_shake(2.0)
				queue_free()
				if mgr:
					mgr.on_railgun_death_finished()
			)
	else:
		if manager and sprite:
			manager.spawn_brick_particles_directional(global_position, sprite.color, last_hit_direction)
			manager.spawn_score_popup(global_position, get_brick_value())
			manager.on_brick_destroyed()
		queue_free()

func get_brick_value() -> int:
	if max_health < 10: return 1
	elif max_health < 50: return 2
	elif max_health < 100: return 3
	elif max_health < 150: return 4
	elif max_health < 200: return 5
	else:
		var extra = int((max_health - 200) / 100)
		return 10 + extra * 5
