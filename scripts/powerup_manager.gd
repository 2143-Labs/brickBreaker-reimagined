extends Node

enum PowerUp {
	PORTAL_SHOT,
	EXPLOSIVE_SHOT,
	SHUFFLE,
	NUKE,
	BURN_SHOT,
	REWIND
}

var unlocked_powerups: Dictionary = {}
var cooldowns: Dictionary = {}
var cooldown_durations: Dictionary = {
	PowerUp.PORTAL_SHOT: 8,
	PowerUp.EXPLOSIVE_SHOT: 4,
	PowerUp.SHUFFLE: 5,
	PowerUp.NUKE: 999,
	PowerUp.BURN_SHOT: 3,
	PowerUp.REWIND: 6,
}

var unlock_levels: Dictionary = {
	PowerUp.EXPLOSIVE_SHOT: 5,
	PowerUp.SHUFFLE: 10,
	PowerUp.BURN_SHOT: 15,
	PowerUp.PORTAL_SHOT: 25,
	PowerUp.REWIND: 35,
	PowerUp.NUKE: 50,
}

func check_unlocks(highest_level: int):
	for power in unlock_levels:
		if highest_level >= unlock_levels[power]:
			if power not in unlocked_powerups:
				unlocked_powerups[power] = true
				cooldowns[power] = 0

func use_powerup(power: PowerUp) -> bool:
	if power not in unlocked_powerups:
		return false
	if cooldowns.get(power, 0) > 0:
		return false
	cooldowns[power] = cooldown_durations[power]
	return true

func tick_cooldowns():
	for power in cooldowns:
		if cooldowns[power] > 0:
			cooldowns[power] -= 1

func is_available(power: PowerUp) -> bool:
	return power in unlocked_powerups and cooldowns.get(power, 0) <= 0

func get_cooldown(power: PowerUp) -> int:
	return cooldowns.get(power, 0)
