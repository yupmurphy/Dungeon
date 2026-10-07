class_name Equipment
extends Node
## What a character wears: body type + one EquipmentData per slot (or nothing). Emits `changed` on every change;
## the owner rebuilds its look (LpcCharacter) from look_items().
## All pieces live as .tres in resources/equipment/ (made by tools/lpc_import.gd).

signal changed

const EQUIPMENT_DIR: String = "res://resources/equipment/"
const BODY_TYPES: Array[String] = ["male", "female"]

@export var body_type: String = "male"
## Worn at start (one per slot).
@export var starting: Array[EquipmentData] = []

## Slot -> EquipmentData.
var _worn: Dictionary = {}


func _ready() -> void:
	for piece in starting:
		if piece != null:
			_worn[piece.slot] = piece


func get_piece(slot: EquipmentData.Slot) -> EquipmentData:
	return _worn.get(slot)


func equip(piece: EquipmentData) -> void:
	if piece == null or _worn.get(piece.slot) == piece:
		return
	_worn[piece.slot] = piece
	changed.emit()


func unequip(slot: EquipmentData.Slot) -> void:
	if _worn.erase(slot):
		changed.emit()


func set_body_type(new_type: String) -> void:
	if new_type != body_type and new_type in BODY_TYPES:
		body_type = new_type
		changed.emit()


## LPC item ids to draw: the body, the head matching the body type, then every worn piece.
func look_items() -> Array[String]:
	var ids: Array[String] = ["body", "head_human_" + body_type]
	for slot: int in _worn:
		ids.append(_worn[slot].lpc_item)
	return ids


## Every piece made for one slot, sorted by name (for the debug lists).
static func all_pieces(slot: EquipmentData.Slot) -> Array[EquipmentData]:
	var pieces: Array[EquipmentData] = []
	for file in DirAccess.get_files_at(EQUIPMENT_DIR):
		var piece := load(EQUIPMENT_DIR + file.trim_suffix(".remap")) as EquipmentData
		if piece != null and piece.slot == slot:
			pieces.append(piece)
	pieces.sort_custom(func(a: EquipmentData, b: EquipmentData) -> bool: return a.display_name < b.display_name)
	return pieces


## The piece with this id (resources/equipment/<id>.tres), or null.
static func find(id: StringName) -> EquipmentData:
	var path: String = EQUIPMENT_DIR + String(id) + ".tres"
	return load(path) as EquipmentData if ResourceLoader.exists(path) else null
