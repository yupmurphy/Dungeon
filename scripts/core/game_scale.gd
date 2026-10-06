class_name GameScale
## One place for every size in the game.
##
## Gameplay numbers in scripts and .tres files (speeds, ranges, radii, offsets) are written in
## "reference pixels": pixels of a world built from 16 px tiles. world() turns them into real pixels.
## Moving to 32 px art later:
##   - 32 px tiles and characters: set TILE_SIZE = 32 (and TileAtlas to the new sheet). Everything scales.
##   - only 32 px character sprites: change nothing; sprites are fitted to their visual_size automatically.

## Size of one tile in the reference world. Do not change; it is what the numbers are written for.
const REFERENCE_TILE: int = 16
## Size of one map tile in actual pixels.
const TILE_SIZE: int = 16
## Default on-screen size of a character, in reference pixels (one tile).
const CHARACTER_SIZE: float = 16.0


## Reference pixels -> actual pixels.
static func world(reference_pixels: float) -> float:
	return reference_pixels * TILE_SIZE / REFERENCE_TILE


static func world_vector(reference: Vector2) -> Vector2:
	return reference * TILE_SIZE / REFERENCE_TILE


static func tiles_to_pixels(tiles: float) -> float:
	return tiles * TILE_SIZE


## Scale that makes a texture of `texture_size` appear `visual_size` reference pixels wide.
static func fit_scale(texture_size: Vector2, visual_size: float) -> Vector2:
	if texture_size.x <= 0.0:
		return Vector2.ONE
	var factor: float = world(visual_size) / texture_size.x
	return Vector2(factor, factor)
