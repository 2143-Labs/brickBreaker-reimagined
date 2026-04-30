class_name BallType
extends RefCounted

enum {
	NORMAL,
	IRON,
	PHYS,
	DENSE,
	NEGATIVE,
	UNPRED,
	PIERCING,
	SHOTGUN,
	FIRE,
}

const SPECIALS: Array[int] = [IRON, PHYS, DENSE, NEGATIVE, UNPRED, PIERCING, SHOTGUN, FIRE]
const NORMAL_CHANCE: float = 0.8

static func roll() -> int:
	if randf() < NORMAL_CHANCE:
		return NORMAL
	return SPECIALS[randi() % SPECIALS.size()]

static func color(t: int) -> Color:
	match t:
		IRON:     return Color(0.65, 0.68, 0.72)
		PHYS:     return Color(0.55, 0.85, 0.95)
		DENSE:    return Color(0.45, 0.30, 0.85)
		NEGATIVE: return Color(0.95, 0.45, 0.85)
		UNPRED:   return Color(0.95, 0.85, 0.20)
		PIERCING: return Color(0.30, 0.95, 0.55)
		SHOTGUN:  return Color(0.95, 0.55, 0.20)
		FIRE:     return Color(0.95, 0.30, 0.15)
		_:        return Color(0.30, 0.55, 0.95)

static func is_physics(t: int) -> bool:
	return t == PHYS or t == DENSE or t == NEGATIVE
