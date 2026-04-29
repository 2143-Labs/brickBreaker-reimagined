extends Node
const SAVE_PATH = "user://progression.save"

var xp: int = 0
var level: int = 1
var skill_points: int = 0
var total_skill_points_earned: int = 0

# Talents: name -> current rank
var talents: Dictionary = {
	"reinforced_balls": 0,
	"quick_loader": 0,
	"bigger_blasts": 0,
	"burn_mastery": 0,
	"railgun_pierce": 0,
	"ammo_magnet": 0,
	"stacking_damage": 0,
	"recall": 0,
	"railgun_armor_break": 0,
}

# Talent definitions
var talent_defs: Dictionary = {
	"reinforced_balls": {"name": "Reinforced Balls", "desc": "+10% ball damage per rank", "max": 5, "row": 0, "col": 0},
	"quick_loader": {"name": "Quick Loader", "desc": "-1 powerup cooldown per rank", "max": 3, "row": 0, "col": 1},
	"bigger_blasts": {"name": "Bigger Blasts", "desc": "+15% explosion radius per rank", "max": 3, "row": 1, "col": 0},
	"burn_mastery": {"name": "Burn Mastery", "desc": "+1 burn tick per rank", "max": 3, "row": 1, "col": 1},
	"railgun_pierce": {"name": "Railgun Pierce", "desc": "+1 railgun wall bounce per rank", "max": 3, "row": 2, "col": 0},
	"ammo_magnet": {"name": "Ammo Magnet", "desc": "+5% extra orb chance per rank", "max": 5, "row": 4, "col": 0},
	"stacking_damage": {"name": "Stacking Hits", "desc": "+1 dmg per same-brick hit (max +rank)", "max": 5, "row": 3, "col": 0},
	"recall": {"name": "Recall", "desc": "End turn early (unlocks at rank 1)", "max": 1, "row": 3, "col": 1},
	"railgun_armor_break": {"name": "Armor Piercing", "desc": "Railgun strips armor on hit", "max": 1, "row": 2, "col": 1},
}
func _ready():
	load_data()

func xp_for_level(lvl: int) -> int:
	if lvl <= 10:
		return 50 + lvl * 20  # 70, 90, 110, 130... 250
	elif lvl <= 25:
		return int(250 * pow(1.3, lvl - 10))  # gentler curve through 25
	else:
		return int(250 * pow(1.3, 15) * pow(1.8, lvl - 25))  # steep after 25

func xp_for_current_level() -> int:
	return xp_for_level(level)

func xp_progress() -> float:
	return float(xp) / max(xp_for_current_level(), 1)

func add_xp(amount: int):
	xp += amount
	while xp >= xp_for_current_level():
		xp -= xp_for_current_level()
		level += 1
		skill_points += 1
		total_skill_points_earned += 1
	save_data()

func get_talent_cost(talent_key: String) -> int:
	return talents.get(talent_key, 0) + 1

func spend_skill_point(talent_key: String) -> bool:
	var cost = get_talent_cost(talent_key)
	if skill_points < cost:
		return false
	if not talent_defs.has(talent_key):
		return false
	var max_rank = talent_defs[talent_key]["max"]
	if talents[talent_key] >= max_rank:
		return false
	talents[talent_key] += 1
	skill_points -= cost
	save_data()
	return true

func get_talent_rank(key: String) -> int:
	return talents.get(key, 0)

# Gameplay getters
func get_damage_multiplier() -> float:
	return 1.0 + get_talent_rank("reinforced_balls") * 0.1

func get_cooldown_reduction() -> int:
	return get_talent_rank("quick_loader")
func get_explosion_radius_mult() -> float:
	return 1.0 + get_talent_rank("bigger_blasts") * 0.15

func get_burn_extra_ticks() -> int:
	return get_talent_rank("burn_mastery")

func get_railgun_bounces() -> int:
	return get_talent_rank("railgun_pierce")

func get_extra_orb_chance() -> float:
	return get_talent_rank("ammo_magnet") * 0.05

func get_stacking_damage_max() -> int:
	return get_talent_rank("stacking_damage")
func has_recall() -> bool:
	return get_talent_rank("recall") >= 1

func has_railgun_armor_break() -> bool:
	return get_talent_rank("railgun_armor_break") >= 1

func save_data():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var({
			"xp": xp,
			"level": level,
			"skill_points": skill_points,
			"total_sp": total_skill_points_earned,
			"talents": talents,
		})
		file.close()
func load_data():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var data = file.get_var()
			if data is Dictionary:
				xp = data.get("xp", 0)
				level = data.get("level", 1)
				skill_points = data.get("skill_points", 0)
				total_skill_points_earned = data.get("total_sp", 0)
				var saved_talents = data.get("talents", {})
				for key in saved_talents:
					if talents.has(key):
						talents[key] = saved_talents[key]
			file.close()
