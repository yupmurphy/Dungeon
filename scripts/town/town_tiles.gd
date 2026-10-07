class_name TownTiles
extends RefCounted
## The town's ground TileSet (LPC base terrain sheets) and the corner autotiling used to paint it.
## One terrain set (match corners), so roads, water and soil can also be painted by hand in the editor's
## TileMap > Terrains tab. Every LPC terrain sheet has the same 3 x 6 layout (see LPC_LAYOUT).

const TILE_SET_PATH: String = "res://resources/tilesets/town_tileset.tres"

## Atlas sources (one per sheet) and terrains (inside terrain set 0).
enum Source { GRASS, WATER, DIRT, SOIL, FLAGSTONE, COBBLE }
enum TerrainId { GRASS, WATER, DIRT, SOIL }

const SHEETS: Dictionary = {
	Source.GRASS: "res://assets/town/base-assets/grass.png",
	Source.WATER: "res://assets/town/base-assets/water.png",
	Source.DIRT: "res://assets/town/base-assets/dirt.png",
	Source.SOIL: "res://assets/town/base-assets/dirt2.png",
	Source.FLAGSTONE: "res://assets/town/base-assets/castlefloors_outside.png",
	Source.COBBLE: "res://assets/town/walls/walls.png",
}
const TERRAIN_OF_SOURCE: Dictionary = {
	Source.GRASS: TerrainId.GRASS, Source.WATER: TerrainId.WATER, Source.DIRT: TerrainId.DIRT, Source.SOIL: TerrainId.SOIL,
}
const TERRAIN_COLORS: Array[Color] = [Color(0.3, 0.6, 0.25), Color(0.2, 0.4, 0.8), Color(0.6, 0.45, 0.3),
	Color(0.4, 0.3, 0.2)]

## Corner mask (bit set = terrain at that corner: 1 top-left, 2 top-right, 4 bottom-left, 8 bottom-right) ->
## atlas coordinates on an LPC terrain sheet. Masks 6 and 9 (diagonals) have no LPC tile: full tile instead.
const LPC_LAYOUT: Dictionary = {
	15: Vector2i(1, 3),
	8: Vector2i(0, 2), 12: Vector2i(1, 2), 4: Vector2i(2, 2),
	10: Vector2i(0, 3), 5: Vector2i(2, 3),
	2: Vector2i(0, 4), 3: Vector2i(1, 4), 1: Vector2i(2, 4),
	7: Vector2i(1, 0), 11: Vector2i(2, 0), 13: Vector2i(1, 1), 14: Vector2i(2, 1),
	6: Vector2i(1, 3), 9: Vector2i(1, 3),
}
## Plain variants of the full tile (row 5 of the sheet), picked per cell by a hash.
const FULL_VARIANTS: Array[Vector2i] = [Vector2i(1, 3), Vector2i(1, 3), Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 5)]
## Cobblestones for the square: the middle tile of the LPC Walls cobble block (its edges have mortar lines).
const COBBLE_TILE: Vector2i = Vector2i(9, 30)
## Flagstone tiles for the square (cream stones), picked per cell by a hash.
const FLAGSTONES: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2)]

const TILE: int = 32
const WORLD_LAYER: int = 1


static func tile_set() -> TileSet:
	if ResourceLoader.exists(TILE_SET_PATH):
		return load(TILE_SET_PATH)
	return build_tile_set()


## Builds the TileSet from the sheets (the town builder saves it to TILE_SET_PATH).
static func build_tile_set() -> TileSet:
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(TILE, TILE)
	tiles.add_physics_layer()
	tiles.set_physics_layer_collision_layer(0, WORLD_LAYER)
	tiles.add_terrain_set()
	tiles.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS)
	for terrain: int in TerrainId.values():
		tiles.add_terrain(0)
		tiles.set_terrain_name(0, terrain, TerrainId.keys()[terrain].capitalize())
		tiles.set_terrain_color(0, terrain, TERRAIN_COLORS[terrain])
	for source: int in Source.values():
		var atlas := TileSetAtlasSource.new()
		atlas.texture = load(SHEETS[source])
		atlas.texture_region_size = Vector2i(TILE, TILE)
		tiles.add_source(atlas, source)
		var grid: Vector2i = atlas.texture.get_size() / TILE
		if source == Source.FLAGSTONE:
			for coords in FLAGSTONES:
				atlas.create_tile(coords)
			continue
		if source == Source.COBBLE:
			atlas.create_tile(COBBLE_TILE)
			continue
		var terrain: int = TERRAIN_OF_SOURCE[source]
		var made: Dictionary = {}
		for mask: int in LPC_LAYOUT:
			var coords: Vector2i = LPC_LAYOUT[mask]
			if made.has(coords) or coords.x >= grid.x or coords.y >= grid.y:
				continue
			made[coords] = true
			atlas.create_tile(coords)
			_set_corners(atlas.get_tile_data(coords, 0), terrain, 15 if mask in [6, 9] else mask)
		for coords in FULL_VARIANTS:
			if made.has(coords):
				continue
			made[coords] = true
			atlas.create_tile(coords)
			_set_corners(atlas.get_tile_data(coords, 0), terrain, 15)
		if source == Source.WATER:
			_add_water_collision(atlas)
	return tiles


static func _set_corners(data: TileData, terrain: int, mask: int) -> void:
	data.terrain_set = 0
	data.terrain = terrain if mask == 15 else -1
	var corners: Array = [TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER, TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
		TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER, TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER]
	for bit in 4:
		data.set_terrain_peering_bit(corners[bit], terrain if mask & (1 << bit) else -1)


## Open water blocks movement; a bridge cell uses alternative tile 1 (same picture, no collision).
static func _add_water_collision(atlas: TileSetAtlasSource) -> void:
	var half: float = TILE / 2.0
	var square := PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)])
	for coords in FULL_VARIANTS:
		if not atlas.has_tile(coords):
			continue
		var data: TileData = atlas.get_tile_data(coords, 0)
		data.add_collision_polygon(0)
		data.set_collision_polygon_points(0, 0, square)
		if not atlas.has_alternative_tile(coords, 1):
			atlas.create_alternative_tile(coords, 1)
			var alt: TileData = atlas.get_tile_data(coords, 1)
			alt.terrain_set = 0
			alt.terrain = TerrainId.WATER


## Paints `cells` (Dictionary of Vector2i -> true) on `layer` with LPC corner autotiling.
## `grow`: a corner counts as terrain if ANY touching cell is terrain (roads look wider, thin lanes show);
## otherwise only if ALL four are (water, soil: the edge tiles stay inside the area).
static func paint(layer: TileMapLayer, source: int, cells: Dictionary, grow: bool, no_collision: Dictionary = {}) -> void:
	var corners: Dictionary = {}
	for cell: Vector2i in cells:
		for dy in 2:
			for dx in 2:
				var corner := Vector2i(cell.x + dx, cell.y + dy)
				if corners.has(corner):
					continue
				var count: int = 0
				for oy in 2:
					for ox in 2:
						if cells.has(Vector2i(corner.x - 1 + ox, corner.y - 1 + oy)):
							count += 1
				corners[corner] = count > 0 if grow else count == 4
	var targets: Dictionary = {}
	for corner: Vector2i in corners:
		if not corners[corner]:
			continue
		for oy in 2:
			for ox in 2:
				targets[Vector2i(corner.x - 1 + ox, corner.y - 1 + oy)] = true
	for cell: Vector2i in targets:
		var mask: int = 0
		if corners.get(cell, false):
			mask |= 1
		if corners.get(cell + Vector2i(1, 0), false):
			mask |= 2
		if corners.get(cell + Vector2i(0, 1), false):
			mask |= 4
		if corners.get(cell + Vector2i(1, 1), false):
			mask |= 8
		if mask == 0:
			continue
		var coords: Vector2i = LPC_LAYOUT[mask]
		if mask == 15:
			coords = FULL_VARIANTS[_hash(cell) % FULL_VARIANTS.size()]
		var alternative: int = 1 if source == Source.WATER and mask == 15 and no_collision.has(cell) else 0
		layer.set_cell(cell, source, coords, alternative)


static func paint_flagstones(layer: TileMapLayer, cells: Dictionary) -> void:
	for cell: Vector2i in cells:
		layer.set_cell(cell, Source.FLAGSTONE, FLAGSTONES[_hash(cell) % FLAGSTONES.size()])


static func paint_cobbles(layer: TileMapLayer, cells: Dictionary) -> void:
	for cell: Vector2i in cells:
		layer.set_cell(cell, Source.COBBLE, COBBLE_TILE)


static func fill_grass(layer: TileMapLayer, size: Vector2i) -> void:
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			layer.set_cell(cell, Source.GRASS, FULL_VARIANTS[_hash(cell) % FULL_VARIANTS.size()])


static func _hash(cell: Vector2i) -> int:
	return absi((cell.x * 73856093) ^ (cell.y * 19349663)) % 1000003
