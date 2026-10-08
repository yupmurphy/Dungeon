class_name EquipmentData
extends Resource
## One wearable piece (or hair style): which slot it goes in, which LPC item draws it and what it gives.
## The LPC item (assets/lpc/catalog.json) holds the piece's layer sheets for every animation and body type.
## Items (every slot but hair) are GENERATED from the tables in data/items/ into resources/items/ by
## tools/items/item_generator.gd: never edit those .tres by hand. Hair styles are looks, not items
## (resources/equipment/, made by tools/lpc_import.gd).

## New slots go at the end (generated files and saves store the number).
enum Slot { HAIR, BODY, PANTS, BOOTS, HELMET, WEAPON, GLOVES, AMULET, RING }

## Slot names as used in the item tables (and by the LPC import tool for hair).
const SLOT_NAMES: Array[String] = ["hair", "body", "pants", "boots", "helmet", "weapon", "gloves", "amulet", "ring"]
## Slots that are looks, not items (no table row, no stats).
const LOOK_SLOTS: Array[Slot] = [Slot.HAIR]
## Tiers from worst to best; `tier` is the index (0 = F).
const TIER_NAMES: Array[String] = ["F", "D", "C", "B", "A", "S"]

## Unique id of the piece (e.g. "weapon_spear"): stats, drops and saves refer to it.
@export var id: StringName = &""
@export var display_name: String = ""
@export var slot: Slot = Slot.BODY
## Item id in the LPC catalog, e.g. "torso_leather" (the items table's "sprite" column). Empty = not drawn on the
## character (jewelry).
@export var lpc_item: String = ""

@export_group("Item")
## Index in TIER_NAMES: 0 = F (starting gear) ... 5 = S.
@export var tier: int = 0
## Kind of piece (roles.csv): cloth, plate, dagger, bow, might...
@export var role: StringName = &""
## The set this piece belongs to (sets table), empty = none.
@export var set_id: StringName = &""
## Where it comes from: start, shop_smithy, drop_goblin...
@export var source: StringName = &""
## Stat -> value added to whoever wears it (e.g. defense: 4, attack_speed: 0.15 = +15%). Only stats of kind
## "bonus" in data/items/stats.csv; zeros are left out. A flexible list, not fixed fields.
@export var bonuses: Dictionary = {}
## What the piece itself is (stats of kind "item"): weight, price.
@export var weight: float = 0.0
@export var price: float = 0.0

@export_group("Weapon")
## From its role (roles.csv): hits up close (true) or from afar (bow, staff).
@export var melee: bool = true
## Hits everything in an area, not just one target.
@export var splash: bool = false
## Reference pixels (16 = one tile).
@export var attack_range: float = 0.0


static func slot_from_name(slot_name: String) -> int:
	return SLOT_NAMES.find(slot_name)


func is_item() -> bool:
	return slot not in LOOK_SLOTS


func tier_name() -> String:
	return TIER_NAMES[clampi(tier, 0, TIER_NAMES.size() - 1)]
