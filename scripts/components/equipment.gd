class_name Equipment
extends Node
## What a character wears: body type + one EquipmentData per slot (or nothing). Emits `changed` on every change;
## the owner rebuilds its look (LpcCharacter) from look_items().
## Items are generated from data/items/items.csv into resources/items/ (never edit them by hand); hair styles
## (looks) live in resources/equipment/ (made by tools/lpc_import.gd).

signal changed

const ITEMS_DIR: String = "res://resources/items/"
const LOOKS_DIR: String = "res://resources/equipment/"
const PIECE_DIRS: Array[String] = [ITEMS_DIR, LOOKS_DIR]
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
		# Jewelry (and gloves, for now) are not drawn.
		if not _worn[slot].lpc_item.is_empty():
			ids.append(_worn[slot].lpc_item)
	return ids


## Every piece made for one slot, sorted by name (for the debug lists).
static func all_pieces(slot: EquipmentData.Slot) -> Array[EquipmentData]:
	var pieces: Array[EquipmentData] = []
	for dir in PIECE_DIRS:
		for file in DirAccess.get_files_at(dir):
			var piece := load(dir + file.trim_suffix(".remap")) as EquipmentData
			if piece != null and piece.slot == slot:
				pieces.append(piece)
	pieces.sort_custom(func(a: EquipmentData, b: EquipmentData) -> bool: return a.display_name < b.display_name)
	return pieces


## The piece with this id (resources/items/<id>.tres or resources/equipment/<id>.tres), or null.
static func find(id: StringName) -> EquipmentData:
	for dir in PIECE_DIRS:
		var path: String = dir + String(id) + ".tres"
		if ResourceLoader.exists(path):
			return load(path) as EquipmentData
	return null
