class_name CaveVisualChecks
extends RefCounted
## Regression checks for cave material selection, complete borders and collision footprints.

const TEST_CELL: Vector2i = Vector2i(1, 1)
const TEST_SIZE: Vector2i = Vector2i(3, 3)
const MASK_CHECK: String = "cave rock: all 256 neighbor masks, opaque tiles and exposed borders"
const COLLISION_CHECK: String = "cave art: full-cell wall collision, no floor collision, unchanged test-room tileset"
const MATERIAL_CHECK: String = "cave materials: natural rock/floor in Galleries, masonry only on reinforced rock"
const GEOMETRY_CHECK: String = "cave material marks never change movement, terrain or sight"
const VOLUME_CHECK: String = "cave volume: dark top, lit front brow, shaded face/sides and stronger base contact"
const FLOOR_CHECK: String = "cave floor: all contact shadow masks and variants stay walkable"
const REINFORCEMENT_CHECK: String = "Galleries reinforcement stays on existing rock near the built hall"
const FACE_CHECK: String = "cave rock handles isolated pillars, thin walls and diagonal corners"


static func run() -> Dictionary:
	var results: Dictionary = {}
	var layout := FloorLayout.new()
	layout.setup(TEST_SIZE, 1, 1)
	layout.hub_slot = 0
	var walls: Image = CaveArt.walls_texture().get_image()
	var masks_ok: bool = true
	for mask in CaveArt.WALL_TILES:
		for y in TEST_SIZE.y:
			for x in TEST_SIZE.x:
				layout.set_slot(x, y, 0)
				layout.paint(x, y, Terrain.Type.ROCK)
		for bit_index in CaveArt.OFFSETS.size():
			if mask & CaveArt.BITS[bit_index]:
				var cell: Vector2i = TEST_CELL + CaveArt.OFFSETS[bit_index]
				layout.paint(cell.x, cell.y, Terrain.Type.CAVE)
		masks_ok = masks_ok and CaveArt.open_mask(layout.is_rock, TEST_CELL.x, TEST_CELL.y) == mask
		var at: Vector2i = CaveArt.atlas_coords(mask) * CaveArt.TILE
		for y in CaveArt.TILE:
			for x in CaveArt.TILE:
				masks_ok = masks_ok and walls.get_pixel(at.x + x, at.y + y).a == 1.0
		var last: int = CaveArt.TILE - 1
		if mask & CaveArt.NORTH:
			for x in CaveArt.TILE:
				masks_ok = masks_ok and walls.get_pixel(at.x + x, at.y).is_equal_approx(CaveArt.ROCK_OUTLINE)
		if mask & CaveArt.SOUTH:
			for x in CaveArt.TILE:
				masks_ok = masks_ok and walls.get_pixel(at.x + x, at.y + last).is_equal_approx(CaveArt.ROCK_OUTLINE)
		if mask & CaveArt.EAST:
			for y in CaveArt.TILE:
				masks_ok = masks_ok and walls.get_pixel(at.x + last, at.y + y).is_equal_approx(CaveArt.ROCK_OUTLINE)
		if mask & CaveArt.WEST:
			for y in CaveArt.TILE:
				masks_ok = masks_ok and walls.get_pixel(at.x, at.y + y).is_equal_approx(CaveArt.ROCK_OUTLINE)
	results[MASK_CHECK] = masks_ok
	var lip: int = CaveArt.TILE - 1 - CaveArt.FACE_DEPTH
	var middle: int = CaveArt.TILE / 2
	var top: Color = CaveArt._wall_pixel(CaveArt.SOUTH, middle, lip - 2)
	var brow: Color = CaveArt._wall_pixel(CaveArt.SOUTH, middle, lip)
	var face: Color = CaveArt._wall_pixel(CaveArt.SOUTH, middle, lip + 3)
	var foot: Color = CaveArt._wall_pixel(CaveArt.SOUTH, middle, CaveArt.TILE - 2)
	var west: Color = CaveArt._wall_pixel(CaveArt.WEST, 1, 3)
	var east: Color = CaveArt._wall_pixel(CaveArt.EAST, CaveArt.TILE - 2, 3)
	var contact: Color = CaveArt._floor_pixel(CaveArt.NORTH * CaveArt.FLOOR_VARIANTS, middle, 0)
	var away: Color = CaveArt._floor_pixel(CaveArt.NORTH * CaveArt.FLOOR_VARIANTS, middle, CaveArt.FLOOR_FRONT_SHADOW_DEPTH)
	var rear: Color = CaveArt._floor_pixel(CaveArt.SOUTH * CaveArt.FLOOR_VARIANTS, middle, CaveArt.TILE - 1)
	var volume_ok: bool = brow.v > face.v and face.v > top.v and face.v > foot.v \
		and west.v > east.v and contact.v < away.v and contact.v < rear.v
	for mask in CaveArt.WALL_TILES:
		if (mask & CaveArt.SOUTH) != 0:
			for x in range(CaveArt.SIDE_FACE_DEPTH, CaveArt.TILE - CaveArt.SIDE_FACE_DEPTH):
				volume_ok = volume_ok and CaveArt._wall_pixel(mask, x, lip) == CaveArt.ROCK_LIGHT
	results[VOLUME_CHECK] = volume_ok
	var floor_ok: bool = true
	for mask in CaveArt.FLOOR_MASKS:
		for bit_index in range(4):
			var cell: Vector2i = TEST_CELL + CaveArt.OFFSETS[bit_index]
			layout.paint(cell.x, cell.y, Terrain.Type.ROCK if mask & CaveArt.BITS[bit_index] else Terrain.Type.CAVE)
		for variant in CaveArt.FLOOR_VARIANTS:
			var roll: float = (variant + 0.5) / CaveArt.FLOOR_VARIANTS
			floor_ok = floor_ok and CaveArt.floor_index(layout.is_rock, TEST_CELL.x, TEST_CELL.y, roll) == mask * CaveArt.FLOOR_VARIANTS + variant
	results[FLOOR_CHECK] = floor_ok
	# Test representative single-cell and diagonal shapes independently of the mask loop.
	results[FACE_CHECK] = CaveArt._wall_pixel(CaveArt.NORTH | CaveArt.EAST | CaveArt.SOUTH | CaveArt.WEST, 0, 0) == CaveArt.ROCK_OUTLINE \
		and CaveArt._wall_pixel(CaveArt.EAST | CaveArt.WEST, 0, CaveArt.TILE / 2) == CaveArt.ROCK_OUTLINE \
		and CaveArt._wall_pixel(CaveArt.NORTH_EAST, CaveArt.TILE - 1, 0) == CaveArt.ROCK_OUTLINE \
		and CaveArt._wall_pixel(0, CaveArt.TILE - 1, 0) != CaveArt.ROCK_OUTLINE
	var tile_set: TileSet = FloorTiles.tile_set()
	var walls_source := tile_set.get_source(FloorTiles.CAVE_WALL_SOURCE) as TileSetAtlasSource
	var floors_source := tile_set.get_source(FloorTiles.CAVE_FLOOR_SOURCE) as TileSetAtlasSource
	var collision_ok: bool = walls_source.get_tiles_count() == CaveArt.WALL_TILES \
		and floors_source.get_tiles_count() == CaveArt.FLOOR_MASKS * CaveArt.FLOOR_VARIANTS
	var half: float = GameScale.TILE_SIZE / 2.0
	var square := PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)])
	for index in CaveArt.WALL_TILES:
		var tile: TileData = walls_source.get_tile_data(CaveArt.atlas_coords(index), 0)
		collision_ok = collision_ok and tile.get_collision_polygons_count(0) == 1 \
			and tile.get_collision_polygon_points(0, 0) == square
	for index in CaveArt.FLOOR_MASKS * CaveArt.FLOOR_VARIANTS:
		var tile: TileData = floors_source.get_tile_data(CaveArt.atlas_coords(index), 0)
		collision_ok = collision_ok and tile.get_collision_polygons_count(0) == 0
	results[COLLISION_CHECK] = collision_ok and not FloorTiles.dungeon_tile_set().has_source(FloorTiles.CAVE_WALL_SOURCE)
	var cells_before: PackedByteArray = layout.cells_raw().duplicate()
	var terrain_before: PackedByteArray = layout.terrain_raw().duplicate()
	var sight_before: bool = layout.blocks_sight(TEST_CELL.x, TEST_CELL.y)
	layout.mark_masonry(TEST_CELL.x, TEST_CELL.y)
	results[GEOMETRY_CHECK] = layout.is_masonry(TEST_CELL.x, TEST_CELL.y) \
		and cells_before == layout.cells_raw() and terrain_before == layout.terrain_raw() \
		and sight_before == layout.blocks_sight(TEST_CELL.x, TEST_CELL.y)
	return results


static func streamed_materials_ok(level: FloorLevel) -> bool:
	var layout: FloorLayout = level.layout
	var region := level.get_node("Tiles/Region%d" % layout.hub_slot) as TileMapLayer
	var checked: int = 0
	for cell in region.get_used_cells():
		var type: int = layout.terrain_at(cell.x, cell.y)
		var source: int = region.get_cell_source_id(cell)
		if type == Terrain.Type.ROCK:
			var expected: int = 0 if layout.is_masonry(cell.x, cell.y) else FloorTiles.CAVE_WALL_SOURCE
			if source != expected:
				return false
			if expected == FloorTiles.CAVE_WALL_SOURCE and region.get_cell_atlas_coords(cell) \
					!= CaveArt.atlas_coords(CaveArt.open_mask(layout.is_rock, cell.x, cell.y)):
				return false
		elif type == Terrain.Type.CAVE:
			if source != FloorTiles.CAVE_FLOOR_SOURCE:
				return false
		checked += 1
	return checked > 0


static func reinforcement_ok(layout: FloorLayout) -> bool:
	var hall: Vector2i = Vector2i.ZERO
	var found: bool = false
	for feature in layout.features:
		if feature.kind == &"chieftain_hall":
			hall = feature.cell
			found = true
	if not found:
		return false
	var reach: int = ceili(GalleriesBuilder.HALL_RADIUS.y * GalleriesBuilder.REINFORCEMENT_REACH)
	var marked: int = 0
	for y in range(hall.y - reach, hall.y + reach + 1):
		for x in range(hall.x - reach, hall.x + reach + 1):
			if layout.is_masonry(x, y):
				if not layout.is_rock(x, y) or layout.is_floor(x, y) or layout.slot_at(x, y) != layout.hub_slot:
					return false
				marked += 1
	# Also reject any mark outside the hall's bounded reinforcement area.
	return marked > 0 and marked == layout._masonry.count(1)
