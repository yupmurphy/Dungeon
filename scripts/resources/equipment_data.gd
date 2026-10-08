class_name EquipmentData
extends Resource
## One wearable piece (or hair style): which slot it goes in and which LPC item draws it.
## The LPC item (assets/lpc/catalog.json) holds the piece's layer sheets for every animation and body type.
## Items (every slot but hair) are GENERATED from data/items/items.csv into resources/items/ by
## tools/items/item_generator.gd: never edit those .tres by hand. Hair styles are looks, not items
## (resources/equipment/, made by tools/lpc_import.gd).

enum Slot { HAIR, TORSO, LEGS, FEET, HELMET, WEAPON }

## Slot names as used by the LPC catalog / import tool and the items table.
const SLOT_NAMES: Array[String] = ["hair", "torso", "legs", "feet", "helmet", "weapon"]
## Slots that are looks, not items (no table row, no stats).
const LOOK_SLOTS: Array[Slot] = [Slot.HAIR]

## Unique id of the piece (e.g. "weapon_spear"): stats, drops and saves refer to it.
@export var id: StringName = &""
@export var display_name: String = ""
@export var slot: Slot = Slot.TORSO
## Item id in the LPC catalog, e.g. "torso_leather" (the items table's "sprite" column).
@export var lpc_item: String = ""

@export_group("Item")
## Power step: 1 = starting gear, higher = better (its stats come from the tier rules, stage 2).
@export var tier: int = 0
## Kind of piece inside its slot (e.g. cloth / leather / plate, light / balanced / heavy / reach weapons).
@export var role: StringName = &""
## The set this piece belongs to (sets table), empty = none.
@export var set_id: StringName = &""
## Where it comes from: start, shop_smithy, drop_goblin...
@export var source: StringName = &""


static func slot_from_name(slot_name: String) -> int:
	return SLOT_NAMES.find(slot_name)


func is_item() -> bool:
	return slot not in LOOK_SLOTS
