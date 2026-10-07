class_name EquipmentData
extends Resource
## One wearable piece (or hair style): which slot it goes in and which LPC item draws it.
## The LPC item (assets/lpc/catalog.json) holds the piece's layer sheets for every animation and body type.
## Stats (armor, weapon damage...) come later; the look already works.

enum Slot { HAIR, TORSO, LEGS, FEET, HELMET, WEAPON }

## Slot names as used by the LPC catalog / import tool.
const SLOT_NAMES: Array[String] = ["hair", "torso", "legs", "feet", "helmet", "weapon"]

## Unique id of the piece (e.g. "weapon_spear"): stats, drops and saves refer to it.
@export var id: StringName = &""
@export var display_name: String = ""
@export var slot: Slot = Slot.TORSO
## Item id in the LPC catalog, e.g. "torso_leather".
@export var lpc_item: String = ""


static func slot_from_name(slot_name: String) -> int:
	return SLOT_NAMES.find(slot_name)
