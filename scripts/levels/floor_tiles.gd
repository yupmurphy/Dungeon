class_name FloorTiles
## The TileSet used on dungeon floors: the Kenney dungeon tiles (source 0, from dungeon_tileset.tres) plus
## the procedural nature tiles (source 1, NatureArt). Nature tiles that block movement (trees, deep
## water) get a full-square collision, like the dungeon walls.

const DUNGEON_TILESET: TileSet = preload("res://resources/tilesets/dungeon_tileset.tres")
const NATURE_SOURCE: int = 1
const CANOPY_SOURCE: int = 2

static var _tile_set: TileSet


static func tile_set() -> TileSet:
	if _tile_set != null:
		return _tile_set
	_tile_set = DUNGEON_TILESET.duplicate(true)
	var source := TileSetAtlasSource.new()
	source.texture = NatureArt.atlas_texture()
	source.texture_region_size = Vector2i(NatureArt.TILE, NatureArt.TILE)
	_tile_set.add_source(source, NATURE_SOURCE)
	var half: float = NatureArt.TILE / 2.0
	var square := PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)])
	# A tree blocks only with its trunk, not the whole tile.
	var trunk := PackedVector2Array([Vector2(-4, -2), Vector2(4, -2), Vector2(4, 6), Vector2(-4, 6)])
	for type: int in Terrain.ART:
		var first: int = Terrain.ART[type][0]
		for variant in Terrain.ART[type][1]:
			var coords: Vector2i = NatureArt.atlas_coords(first + variant)
			source.create_tile(coords)
			if not Terrain.walkable(type):
				var tile: TileData = source.get_tile_data(coords, 0)
				tile.add_collision_polygon(0)
				tile.set_collision_polygon_points(0, 0, trunk if type == Terrain.Type.TREE else square)

	# Tree canopies: pictures bigger than a tile, drawn above their cell so the trunk stands on it.
	var canopies := TileSetAtlasSource.new()
	canopies.texture = NatureArt.canopy_texture()
	canopies.texture_region_size = NatureArt.CANOPY_SIZE
	_tile_set.add_source(canopies, CANOPY_SOURCE)
	for v in NatureArt.CANOPY_VARIANTS:
		canopies.create_tile(Vector2i(v, 0))
		var tile: TileData = canopies.get_tile_data(Vector2i(v, 0), 0)
		@warning_ignore("integer_division")
		tile.texture_origin = Vector2i(0, NatureArt.CANOPY_SIZE.y / 2 - NatureArt.TILE / 2 - 2)
	upscale(_tile_set)
	return _tile_set


## The dungeon TileSet alone (test room), scaled to the game's tile size.
static func dungeon_tile_set() -> TileSet:
	var tile_set: TileSet = DUNGEON_TILESET.duplicate(true)
	upscale(tile_set)
	return tile_set


## The tile art is 16 px; the game uses GameScale.TILE_SIZE (32). Every atlas is enlarged with sharp pixels
## (nearest neighbor), and tile sizes, collision shapes and origins follow. Gone once the art is 32 px itself.
static func upscale(tile_set: TileSet) -> void:
	@warning_ignore("integer_division")
	var factor: int = GameScale.TILE_SIZE / tile_set.tile_size.x
	if factor <= 1:
		return
	tile_set.tile_size *= factor
	for i in tile_set.get_source_count():
		var source := tile_set.get_source(tile_set.get_source_id(i)) as TileSetAtlasSource
		if source == null:
			continue
		var image: Image = source.texture.get_image()
		image.decompress()
		image.resize(image.get_width() * factor, image.get_height() * factor, Image.INTERPOLATE_NEAREST)
		source.texture = ImageTexture.create_from_image(image)
		source.margins *= factor
		source.separation *= factor
		source.texture_region_size *= factor
		for t in source.get_tiles_count():
			var tile: TileData = source.get_tile_data(source.get_tile_id(t), 0)
			tile.texture_origin *= factor
			for layer in tile_set.get_physics_layers_count():
				for p in tile.get_collision_polygons_count(layer):
					var points: PackedVector2Array = tile.get_collision_polygon_points(layer, p)
					for k in points.size():
						points[k] *= factor
					tile.set_collision_polygon_points(layer, p, points)
