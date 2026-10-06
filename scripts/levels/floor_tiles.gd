class_name FloorTiles
## The TileSet used on dungeon floors: the Kenney dungeon tiles (source 0, from dungeon_tileset.tres) plus
## the procedural nature tiles (source 1, NatureArt). Nature tiles that block movement (trees, deep
## water) get a full-square collision, like the dungeon walls.

const DUNGEON_TILESET: TileSet = preload("res://resources/tilesets/dungeon_tileset.tres")
const NATURE_SOURCE: int = 1

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
	for type: int in Terrain.ART:
		var first: int = Terrain.ART[type][0]
		for variant in Terrain.ART[type][1]:
			var coords: Vector2i = NatureArt.atlas_coords(first + variant)
			source.create_tile(coords)
			if not Terrain.walkable(type):
				var tile: TileData = source.get_tile_data(coords, 0)
				tile.add_collision_polygon(0)
				tile.set_collision_polygon_points(0, 0, square)
	return _tile_set
