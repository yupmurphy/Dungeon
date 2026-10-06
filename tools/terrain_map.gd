extends Node
## Debug tool: generates floors and saves their terrain as pictures (one pixel per tile, Terrain colors,
## notable places marked). Works headless.
## Run:  <godot.exe> --headless --path . -- --terrain-map=<folder> [--seeds=<first>:<count>]

const FLOOR_DATA: FloorData = preload("res://resources/floors/floor_1.tres")


func run(options: Dictionary) -> void:
	var folder: String = options.get("--terrain-map", "user://")
	var first: int = 1
	var count: int = 3
	var seeds: String = options.get("--seeds", "")
	if seeds.contains(":"):
		first = int(seeds.get_slice(":", 0))
		count = int(seeds.get_slice(":", 1))
	for seed_value in range(first, first + count):
		var layout: FloorLayout = FloorGenerator.generate(FLOOR_DATA, seed_value)
		var image: Image = picture(layout)
		var path: String = folder.path_join("terrain_%d.png" % seed_value)
		image.save_png(path)
		print("Saved ", path)
	get_tree().quit()


## Terrain colors, with the notable places drawn as small symbols.
static func picture(layout: FloorLayout) -> Image:
	var w: int = layout.size.x
	var h: int = layout.size.y
	var colors := PackedColorArray()
	for type in Terrain.Type.size():
		colors.append(Terrain.map_color(type))
	var terrain: PackedByteArray = layout.terrain_raw()
	var cells: PackedByteArray = layout.cells_raw()
	var data := PackedByteArray()
	data.resize(w * h * 3)
	for i in w * h:
		var color: Color = colors[terrain[i]]
		if cells[i] == 0 and Terrain.walkable(terrain[i]):
			color = Color(0.25, 0.2, 0.15)  # under a solid prop
		data[i * 3] = color.r8
		data[i * 3 + 1] = color.g8
		data[i * 3 + 2] = color.b8
	var image := Image.create_from_data(w, h, false, Image.FORMAT_RGB8, data)
	for feature in layout.features:
		_mark(image, feature.cell, feature.kind)
	_mark(image, layout.start_cell, &"start")
	_mark(image, layout.portal_cell, &"portal")
	return image


const MARKS: Dictionary = {
	&"start": Color.WHITE, &"portal": Color(0.8, 0.4, 1.0), &"gate": Color(1.0, 0.95, 0.5),
	&"goblin_camp": Color(1.0, 0.5, 0.1), &"mine": Color(0.4, 0.9, 1.0), &"chieftain_hall": Color(0.9, 0.1, 0.1),
	&"spider_nest": Color(0.95, 0.95, 0.95), &"bridge": Color(0.6, 0.4, 0.2), &"ford": Color(0.6, 0.85, 1.0),
	&"oasis": Color(0.2, 1.0, 0.4), &"giant_bones": Color(1.0, 1.0, 0.85), &"old_tree": Color(0.0, 0.2, 0.0),
	&"lake": Color(0.0, 0.1, 0.5), &"boss_arena": Color(0.9, 0.2, 0.3),
}


static func _mark(image: Image, cell: Vector2i, kind: StringName) -> void:
	var color: Color = MARKS.get(kind, Color.MAGENTA)
	var radius: int = 1 if kind == &"old_tree" else 3
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var p: Vector2i = cell + Vector2i(dx, dy)
			if p.x >= 0 and p.y >= 0 and p.x < image.get_width() and p.y < image.get_height():
				var edge: bool = maxi(absi(dx), absi(dy)) == radius
				image.set_pixelv(p, Color.BLACK if edge and radius > 1 else color)
