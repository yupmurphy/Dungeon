class_name Progression
extends Resource
## Character level and experience. XP needed for the next level grows by XP_GROWTH each level.
## (Where XP comes from - the bestiary - is a later stage; for now only the debug button gives XP.)

signal leveled_up(new_level: int)

const XP_FIRST_LEVEL: int = 100
const XP_GROWTH: float = 1.5
## Debug button on the character sheet.
const DEBUG_XP: int = 50

@export var level: int = 1
## XP collected towards the next level.
@export var xp: int = 0


func xp_needed() -> int:
	return roundi(XP_FIRST_LEVEL * pow(XP_GROWTH, level - 1))


func add_xp(amount: int) -> void:
	xp += maxi(amount, 0)
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		leveled_up.emit(level)
	emit_changed()
