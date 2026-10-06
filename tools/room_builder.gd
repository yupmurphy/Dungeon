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

# Tile indices in tilemap_packed.png (see TileAtlas).
const WALL_FILL: int = 0
const WALL_FACE: int = 40
const WALL_FACE_GRATE: int = 28
const FLOOR: int = 48
const FLOOR_PEBBLES: int = 49
const FLOOR_PEBBLES_SMALL: int = 53
const FLOOR_RUBBLE: int = 42
## Sand with a darker band on top, used as a soft shadow right under wall faces.
const FLOOR_UNDER_WALL: int = 50
## Tiles that get a full-square collision.
const SOLID_TILES: Array[int] = [0, 1, 2, 3, 4, 5, 13, 14, 15, 16, 17, 25, 26, 27, 28, 40, 57, 58, 59]
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
	tile_set.tile_size = Vector2i(TileAtlas.TILE_SIZE, TileAtlas.TILE_SIZE)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)
	tile_set.set_physics_layer_collision_mask(0, 0)

	var source := TileSetAtlasSource.new()
	source.texture = load(TileAtlas.TEXTURE_PATH)
	source.texture_region_size = tile_set.tile_size
	tile_set.add_source(source, 0)

	var half: float = TileAtlas.TILE_SIZE / 2.0
	var square := PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)])
	for index in TERRAIN_TILE_COUNT:
		var cell: Vector2i = TileAtlas.coords(index)
		source.create_tile(cell)
		if index in SOLID_TILES:
			var data: TileData = source.get_tile_data(cell, 0)
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, square)
	return tile_set


func _paint(layer: TileMapLayer) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in ROOM_HEIGHT:
		for x in ROOM_WIDTH:
			var index: int
			if _is_face(x, y):
				index = WALL_FACE_GRATE if rng.randf() < 0.12 else WALL_FACE
			elif _is_wall(x, y):
				index = _wall_top_tile(x, y)
			elif _is_face(x, y - 1):
				index = FLOOR_UNDER_WALL
			else:
				index = _floor_tile(rng.randf())
			layer.set_cell(Vector2i(x, y), 0, TileAtlas.coords(index))


## Mostly plain sand, a few pebbles, rare rubble.
func _floor_tile(roll: float) -> int:
	if roll < 0.02:
		return FLOOR_RUBBLE
	if roll < 0.06:
		return FLOOR_PEBBLES_SMALL
	if roll < 0.12:
		return FLOOR_PEBBLES
	return FLOOR


func _is_wall(x: int, y: int) -> bool:
	if x <= 1 or y <= 2 or x >= ROOM_WIDTH - 2 or y >= ROOM_HEIGHT - 2:
		return true  # Outer walls; out-of-bounds also counts as wall.
	for pillar in PILLARS:
		if x >= pillar.x and x <= pillar.x + 1 and y >= pillar.y and y <= pillar.y + 2:
			return true
	return false


## The visible brick side of a wall: a wall cell with open floor right below it.
func _is_face(x: int, y: int) -> bool:
	return _is_wall(x, y) and not _is_wall(x, y + 1)


## True if the cell is NOT part of a wall top (so a wall top next to it needs a border there).
func _is_open(x: int, y: int) -> bool:
	return not _is_wall(x, y) or _is_face(x, y)


## Picks the stone ledge piece around wall tops. In this pack the ledge runs through the middle of
## the tile, on the side that faces the open area:
##   straight edges: 2 (open below), 26 (open above), 13 (open right), 15 (open left)
##   convex corners (wall sticks out): 4, 5, 16, 17 / concave corners (room corners): 1, 3, 25, 27
func _wall_top_tile(x: int, y: int) -> int:
	var up: bool = _is_open(x, y - 1)
	var down: bool = _is_open(x, y + 1)
	var left: bool = _is_open(x - 1, y)
	var right: bool = _is_open(x + 1, y)
	if up and left: return 4
	if up and right: return 5
	if down and left: return 16
	if down and right: return 17
	if down: return 2
	if up: return 26
	if right: return 13
	if left: return 15
	if _is_open(x + 1, y + 1): return 1
	if _is_open(x - 1, y + 1): return 3
	if _is_open(x + 1, y - 1): return 25
	if _is_open(x - 1, y - 1): return 27
	return WALL_FILL
