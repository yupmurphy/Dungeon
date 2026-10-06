class_name TileAtlas
## Helpers for assets/Tilemap/tilemap_packed.png (Kenney "Tiny Dungeon": 12 x 11 tiles of 16 px, no spacing).
## A tile "index" is row * 12 + column, counting from the top-left.

const TEXTURE_PATH: String = "res://assets/Tilemap/tilemap_packed.png"
const TILE_SIZE: int = 16
const COLUMNS: int = 12


static func coords(index: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(index % COLUMNS, index / COLUMNS)


static func region(index: int) -> Rect2:
	var cell: Vector2i = coords(index)
	return Rect2(Vector2(cell * TILE_SIZE), Vector2(TILE_SIZE, TILE_SIZE))
