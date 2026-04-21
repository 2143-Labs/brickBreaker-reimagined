extends Node

static func apply_explosion(center: Vector2, radius: float, base_damage: int, brick_container: Node2D):
    for brick in brick_container.get_children():
        var dist = center.distance_to(brick.position)
        if dist <= radius:
            if dist < 1.0:
                brick.take_damage(brick.health)
            else:
                var falloff = 1.0 - (dist / radius)
                var damage = max(1, int(base_damage * falloff))
                brick.take_damage(damage)