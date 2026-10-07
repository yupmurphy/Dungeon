extends Node
## Copies the LPC pieces the game uses from a clone of the official Universal LPC generator
## (https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator) into assets/lpc/,
## keeping the folder structure, and writes:
##   - assets/lpc/catalog.json : per item, its layers (z order) and the sheet of each animation per body type
##   - assets/CREDITS.csv      : the license rows of every copied file (taken from the clone's CREDITS.csv)
## Run:  <godot.exe> --headless --path . -- --lpc-import=<path to the clone>
## To add a piece: add a line to ITEMS (definition json under sheet_definitions/) and run it again.

const OUTPUT: String = "res://assets/lpc/"
const CATALOG: String = "res://assets/lpc/catalog.json"
const CREDITS: String = "res://assets/CREDITS.csv"
## Human-readable credits: every source and author, and which pieces are free to use and how.
const CREDITS_PAGE: String = "res://CREDITS.md"
## One EquipmentData .tres per wearable item (made once; later edits to the .tres are kept).
const EQUIPMENT_DIR: String = "res://resources/equipment/"
const BODY_TYPES: Array[String] = ["male", "female"]
const ANIMATIONS: Array[String] = ["idle", "walk", "slash", "thrust", "hurt"]
## Oversized attack layers (weapons): which of our animations they replace.
const CUSTOM_ANIMATIONS: Dictionary = {"slash_128": "slash", "slash_oversize": "slash", "thrust_oversize": "thrust"}

## id: [slot, definition json, variant file name for pieces that come in several (weapons), display name]
const ITEMS: Dictionary = {
	"body": ["body", "body/body.json", "", "Body"],
	"head_human_male": ["head", "head/heads/human/heads_human_male.json", "", "Human head (male)"],
	"head_human_female": ["head", "head/heads/human/heads_human_female.json", "", "Human head (female)"],
	"hair_plain": ["hair", "hair/short/hair_plain.json", "", "Short hair"],
	"hair_buzzcut": ["hair", "hair/bald/hair_buzzcut.json", "", "Buzzcut"],
	"hair_bob": ["hair", "hair/bob/hair_bob.json", "", "Bob"],
	"hair_ponytail": ["hair", "hair/braids/hair_ponytail.json", "", "Ponytail"],
	"hair_long": ["hair", "hair/long/hair_long.json", "", "Long hair"],
	"torso_longsleeve": ["torso", "torso/shirts/longsleeve/torso_clothes_longsleeve.json", "", "Shirt"],
	"torso_sleeveless": ["torso", "torso/shirts/sleeveless/torso_clothes_sleeveless.json", "forest", "Sleeveless shirt"],
	"torso_leather": ["torso", "torso/armour/torso_armour_leather.json", "", "Leather armor"],
	"legs_pants": ["legs", "legs/pants/legs_pants.json", "", "Pants"],
	"legs_pantaloons": ["legs", "legs/pants/legs_pantaloons.json", "", "Pantaloons"],
	"legs_leggings": ["legs", "legs/leggings/legs_leggings.json", "", "Leggings"],
	"feet_shoes": ["feet", "feet/shoes/feet_shoes_basic.json", "", "Shoes"],
	"feet_boots": ["feet", "feet/boots/feet_boots_basic.json", "", "Boots"],
	"feet_boots_rim": ["feet", "feet/boots/feet_boots_rim.json", "", "Rimmed boots"],
	"helmet_nasal": ["helmet", "headwear/helmets/helmets/hat_helmet_nasal.json", "", "Nasal helmet"],
	"helmet_kettle": ["helmet", "headwear/helmets/helmets/hat_helmet_kettle.json", "", "Kettle helmet"],
	"weapon_dagger": ["weapon", "weapons/sword/weapon_sword_dagger.json", "dagger", "Dagger"],
	"weapon_sword": ["weapon", "weapons/sword/weapon_sword_arming.json", "steel", "Arming sword"],
	"weapon_spear": ["weapon", "weapons/polearm/weapon_polearm_spear.json", "steel", "Spear"],
	"weapon_axe": ["weapon", "weapons/blunt/weapon_blunt_waraxe.json", "waraxe", "War axe"],
}

var _copied: Array[String] = []
## Copied file -> names its credits may be listed under (the clone lists folder + animation, not the color file).
var _credit_keys: Dictionary = {}
## Item id -> files it uses; file -> its credits row (filled by _write_credits).
var _item_files: Dictionary = {}
var _file_rows: Dictionary = {}
var _missing: Array[String] = []


func run(options: Dictionary) -> void:
	var clone: String = String(options.get("--lpc-import", "")).trim_suffix("/")
	if clone.is_empty() or not DirAccess.dir_exists_absolute(clone + "/spritesheets"):
		push_error("--lpc-import=<path to the LPC generator clone> (folder with spritesheets/)")
		get_tree().quit(1)
		return
	var catalog: Dictionary = {}
	for id: String in ITEMS:
		var spec: Array = ITEMS[id]
		var definition: Variant = JSON.parse_string(FileAccess.get_file_as_string(clone + "/sheet_definitions/" + spec[1]))
		if definition == null:
			_missing.append("%s: definition %s" % [id, spec[1]])
			continue
		catalog[id] = {"slot": spec[0], "name": spec[3], "layers": _import_layers(clone, id, definition, spec[2])}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var file := FileAccess.open(CATALOG, FileAccess.WRITE)
	file.store_string(JSON.stringify(catalog, "\t"))
	file.close()
	var credited: int = _write_credits(clone)
	_write_credits_page(catalog)
	var created: int = _write_equipment(catalog)
	print("LPC import: %d items, %d files copied, %d credited, %d new equipment resources" % [catalog.size(),
		_copied.size(), credited, created])
	for line in _missing:
		print("  missing: ", line)
	get_tree().quit(0)


## Every layer of the definition: z order + for each body type, the sheet of each animation we use.
func _import_layers(clone: String, id: String, definition: Dictionary, variant: String) -> Array:
	var layers: Array = []
	var index: int = 1
	while definition.has("layer_%d" % index):
		var layer: Dictionary = definition["layer_%d" % index]
		index += 1
		var custom: String = layer.get("custom_animation", "")
		if not custom.is_empty() and not CUSTOM_ANIMATIONS.has(custom):
			continue  # backslash, halfslash...: not used
		var bodies: Dictionary = {}
		for body in BODY_TYPES:
			if not layer.has(body):
				continue
			var folder: String = layer[body]
			var sheets: Dictionary = {}
			var animations: Array = [CUSTOM_ANIMATIONS[custom]] if not custom.is_empty() else ANIMATIONS
			for animation: String in animations:
				var source: String = _find_sheet(clone, folder, animation, variant, not custom.is_empty())
				if source.is_empty():
					continue
				_copy(clone, source)
				_credit_keys[source] = [source, folder + animation + ".png", folder]
				if source not in _item_files.get(id, []):
					_item_files[id] = _item_files.get(id, []) + [source]
				sheets[animation] = {"file": "lpc/" + source, "frame": _frame_size(clone, source, custom)}
			if not sheets.is_empty():
				bodies[body] = sheets
		if bodies.is_empty():
			_missing.append("%s: layer %d has no sheets" % [id, index - 1])
			continue
		layers.append({"z": int(layer.get("zPos", 0)), "bodies": bodies})
	return layers


## Two layouts exist: <folder><animation>.png, or <folder><animation>/<variant>.png (pieces with variants).
## Oversized attack layers: <folder><variant>.png or <folder minus slash>.png.
func _find_sheet(clone: String, folder: String, animation: String, variant: String, custom: bool) -> String:
	var candidates: Array[String] = []
	if custom:
		candidates = [folder + variant + ".png", folder.trim_suffix("/") + ".png"]
	else:
		candidates = [folder + animation + ".png", folder + animation + "/" + variant + ".png"]
	for candidate in candidates:
		if FileAccess.file_exists(clone + "/spritesheets/" + candidate):
			return candidate
	return ""


## Rows are the 4 directions (hurt: one row), so an oversized sheet's frame = height / 4.
func _frame_size(clone: String, source: String, custom: String) -> int:
	if custom.is_empty():
		return 64
	var image := Image.load_from_file(clone + "/spritesheets/" + source)
	return image.get_height() / 4 if image != null else 64


func _copy(clone: String, source: String) -> void:
	if source in _copied:
		return
	var target: String = ProjectSettings.globalize_path(OUTPUT + source)
	DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	if DirAccess.copy_absolute(clone + "/spritesheets/" + source, target) == OK:
		_copied.append(source)
	else:
		_missing.append("copy failed: " + source)


## The clone's CREDITS.csv has one row per file ("path",notes,authors,licenses,urls). Pieces with color
## variants are listed by folder + animation, so look a copied file up by its candidate names.
func _write_credits(clone: String) -> int:
	var rows: Dictionary = {}
	var by_folder: Dictionary = {}
	var header: String = ""
	var source := FileAccess.open(clone + "/CREDITS.csv", FileAccess.READ)
	while not source.eof_reached():
		var line: String = source.get_line()
		if header.is_empty():
			header = line
			continue
		var path: String = line.get_slice(",", 0).trim_prefix("\"").trim_suffix("\"")
		rows[path] = line
		var folder: String = path.get_base_dir() + "/"
		if not by_folder.has(folder):
			by_folder[folder] = line
	var output := FileAccess.open(CREDITS, FileAccess.WRITE)
	output.store_line("# Credits for the LPC art in assets/lpc/ (copied from the Universal LPC generator's CREDITS.csv).")
	output.store_line("# These licenses require crediting every author listed here, e.g. on a Credits screen.")
	output.store_line(header)
	var credited: int = 0
	for path in _copied:
		var keys: Array = _credit_keys.get(path, [path])
		var row: String = ""
		for key: String in keys.slice(0, 2):
			if rows.has(key):
				row = rows[key]
				break
		if row.is_empty() and by_folder.has(keys[-1]):
			row = by_folder[keys[-1]]
		if row.is_empty():
			_missing.append("no credits row: " + path)
			continue
		# Our file name first, then the original row's notes, authors, licenses and urls.
		output.store_line("\"%s\",%s" % [path, row.substr(row.find(",") + 1)])
		_file_rows[path] = row
		credited += 1
	return credited


# --- CREDITS.md ---

## Every LPC file offers several licenses to pick from; a piece can use a license only if all its files
## offer it. Families, from most to least permissive.
const FREE_NO_CONDITIONS: String = "Free, no conditions"
const FREE_WITH_CREDIT: String = "Free, credit the authors (fine for commercial games, Steam, consoles)"
const FREE_SHARE_ALIKE: String = "Free, credit + share-alike (edits of this art must stay CC-BY-SA/GPL; " \
	+ "the DRM clause makes it risky for Steam/consoles)"


func _write_credits_page(catalog: Dictionary) -> void:
	var page := PackedStringArray()
	page.append("# Credits")
	page.append("")
	page.append("Generated by `tools/lpc_import.gd` (run it again after adding pieces). Per-file rows: `assets/CREDITS.csv`.")
	page.append("")
	page.append("## Can I use it for free?")
	page.append("")
	page.append("All art below costs nothing. What differs is what the license asks in return:")
	page.append("")
	page.append("- **%s** - CC0." % FREE_NO_CONDITIONS)
	page.append("- **%s** - OGA-BY or CC-BY: show the authors on a Credits screen." % FREE_WITH_CREDIT)
	page.append("- **%s** - only CC-BY-SA or GPL available." % FREE_SHARE_ALIKE)
	page.append("")
	page.append("| Piece | Slot | Licenses to pick from | Use for free? |")
	page.append("|---|---|---|---|")
	var details := PackedStringArray()
	for id: String in catalog:
		var files: Array = _item_files.get(id, [])
		var licenses: Array = []
		var authors: Array[String] = []
		var urls: Array[String] = []
		var notes: Array[String] = []
		for file: String in files:
			var fields: PackedStringArray = _csv_fields(_file_rows.get(file, ""))
			if fields.size() < 5:
				continue
			var offered: Array = []
			for license in fields[3].split(","):
				var family: String = _license_family(license.strip_edges())
				if family not in offered:
					offered.append(family)
			licenses = offered if licenses.is_empty() and file == files[0] else licenses.filter(func(l: String) -> bool:
				return l in offered)
			_add_unique(authors, fields[2].split(","))
			_add_unique(urls, fields[4].split(","))
			_add_unique(notes, [fields[1]])
		var verdict: String = FREE_SHARE_ALIKE
		if "CC0" in licenses:
			verdict = FREE_NO_CONDITIONS
		elif "OGA-BY" in licenses or "CC-BY" in licenses:
			verdict = FREE_WITH_CREDIT
		page.append("| %s | %s | %s | %s |" % [catalog[id]["name"], catalog[id]["slot"], ", ".join(licenses), verdict])
		details.append("### %s (`%s`)" % [catalog[id]["name"], id])
		details.append("")
		details.append("- Authors: " + ", ".join(authors))
		details.append("- Licenses (pick one valid for every file): " + ", ".join(licenses))
		for note in notes:
			if not note.is_empty():
				details.append("- Notes: " + note)
		details.append("- Sources:")
		for url in urls:
			details.append("  - " + url)
		details.append("")
	page.append("")
	page.append("Other art:")
	page.append("")
	page.append("| Piece | Source | License | Use for free? |")
	page.append("|---|---|---|---|")
	page.append("| Dungeon tiles, props, monsters (`assets/Tilemap`) | Kenney, Tiny Dungeon - https://kenney.nl/assets/tiny-dungeon | CC0 | %s |" % FREE_NO_CONDITIONS)
	page.append("| Nature tiles, trees, props (`NatureArt`) | Drawn by code in this project | ours | yes |")
	page.append("| Engine | Godot Engine - https://godotengine.org/license | MIT | Free, keep the Godot license text with the game |")
	page.append("")
	page.append("## LPC pieces: authors and sources")
	page.append("")
	page.append("The LPC art comes from the Universal LPC Spritesheet Character Generator")
	page.append("(https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator).")
	page.append("")
	page.append_array(details)
	var file := FileAccess.open(CREDITS_PAGE, FileAccess.WRITE)
	file.store_string("\n".join(page))
	file.close()


static func _license_family(license: String) -> String:
	for family: String in ["CC-BY-SA", "OGA-BY", "CC-BY", "CC0", "GPL"]:
		if license.begins_with(family):
			return family
	return license


static func _add_unique(target: Array[String], values: Array) -> void:
	for value: String in values:
		var clean: String = value.strip_edges()
		if not clean.is_empty() and clean not in target:
			target.append(clean)


## Fields of one CREDITS.csv row: quoted fields, commas inside quotes, spaces around separators.
static func _csv_fields(line: String) -> PackedStringArray:
	var fields := PackedStringArray()
	var current: String = ""
	var quoted: bool = false
	for c in line:
		if c == "\"":
			quoted = not quoted
		elif c == "," and not quoted:
			fields.append(current.strip_edges())
			current = ""
		else:
			current += c
	fields.append(current.strip_edges())
	return fields


## EquipmentData for every item whose slot is an equipment slot (not body / head). Existing files are kept.
func _write_equipment(catalog: Dictionary) -> int:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EQUIPMENT_DIR))
	var created: int = 0
	for id: String in catalog:
		var slot: int = EquipmentData.slot_from_name(catalog[id]["slot"])
		var path: String = EQUIPMENT_DIR + id + ".tres"
		if slot < 0 or FileAccess.file_exists(path):
			continue
		var piece := EquipmentData.new()
		piece.id = StringName(id)
		piece.display_name = catalog[id]["name"]
		piece.slot = slot
		piece.lpc_item = id
		if ResourceSaver.save(piece, path) == OK:
			created += 1
	return created
