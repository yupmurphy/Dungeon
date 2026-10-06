extends Node
## Generator: builds the dungeon TileSet and paints the walls/floor of test_room.tscn.
## Run:  <godot.exe> --headless --path . -- --build-room
## WARNING: repaints the "Dungeon" TileMapLayer, overwriting tile edits made in the editor.
## Other nodes of the room (player, enemies, props, torches) are kept as they are.

const TILESET_PATH: String = "res://resources/tilesets/dungeon_tileset.tres"
const ROOM_PATH: String = "res://scenes/levels/test_room.tscn"

const ROOM_WIDTH: int = 48
const ROOM_HEIGHT: int = 30
## Top-left tile of each 2x3 pillar (2 rows of wall top + 1 row of wall face).
const PILLARS: Array[Vector2i] = [Vector2i(12, 9), Vector2i(33, 9), Vector2i(22, 19)]
## Terrain part of the sheet exposed in the TileSet (first 5 rows).
const TERRAIN_TILE_COUNT: int = 60


func run(_options: Dictionary) -> void:
	var tile_set: TileSet = _build_tile_set()
	var error: Error = ResourceSaver.save(tile_set, TILESET_PATH)
	if error != OK:
		push_error("Could not save tileset: %s" % error)
		get_tree().quit(1)
		return

	var packed: PackedScene = load(ROOM_PATH)
	var room: Node = packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	var layer: TileMapLayer = room.get_node("Dungeon")
	layer.tile_set = load(TILESET_PATH)
	layer.clear()
	_paint(layer)

	var out := PackedScene.new()
	out.pack(room)
	error = ResourceSaver.save(out, ROOM_PATH)
	print("Room saved: ", error == OK, " cells: ", layer.get_used_cells().size())
	room.free()
	get_tree().quit(0 if error == OK else 1)


func _build_tile_set() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(GameScale.TILE_SIZE, GameScale.TILE_SIZE)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)
	tile_set.set_physics_layer_collision_mask(0, 0)

	var source := TileSetAtlasSource.new()
	source.texture = load(TileAtlas.TEXTURE_PATH)
	source.texture_region_size = Vector2i(TileAtlas.TILE_SIZE, TileAtlas.TILE_SIZE)
	tile_set.add_source(source, 0)

	var half: float = GameScale.TILE_SIZE / 2.0
	var square := PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)])
	for index in TERRAIN_TILE_COUNT:
		var cell: Vector2i = TileAtlas.coords(index)
		source.create_tile(cell)
		if index in WallTiler.SOLID_TILES:
			var data: TileData = source.get_tile_data(cell, 0)
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, square)
	return tile_set


func _paint(layer: TileMapLayer) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in ROOM_HEIGHT:
		for x in ROOM_WIDTH:
			var index: int = WallTiler.tile_for(_is_wall, x, y, rng.randf())
			layer.set_cell(Vector2i(x, y), 0, TileAtlas.coords(index))


func _is_wall(x: int, y: int) -> bool:
	if x <= 1 or y <= 2 or x >= ROOM_WIDTH - 2 or y >= ROOM_HEIGHT - 2:
		return true  # Outer walls; out-of-bounds also counts as wall.
	for pillar in PILLARS:
		if x >= pillar.x and x <= pillar.x + 1 and y >= pillar.y and y <= pillar.y + 2:
			return true
	return false
