class_name WallTiler
## Picks which Tiny Dungeon tile a map cell shows, from a wall/floor grid.
## `is_wall` is a Callable(x: int, y: int) -> bool; out-of-bounds cells should count as wall.
##
## Wall tops are dark dirt framed by a stone ledge. In this pack the ledge runs through the middle
## of the tile, on the side that faces the open area:
##   straight edges: 2 (open below), 26 (open above), 13 (open right), 15 (open left)
##   convex corners (wall sticks out): 4, 5, 16, 17 / concave corners (room corners): 1, 3, 25, 27
## A wall cell with floor right below it is a brick face (40, sometimes 28 with a grate).

const WALL_FILL: int = 0
const WALL_FACE: int = 40
const WALL_FACE_GRATE: int = 28
const FLOOR: int = 48
const FLOOR_PEBBLES: int = 49
const FLOOR_PEBBLES_SMALL: int = 53
const FLOOR_RUBBLE: int = 42
## Sand with a darker band on top, used as a soft shadow right under wall faces.
const FLOOR_UNDER_WALL: int = 50
## Tiles that get a full-square collision in the tileset.
const SOLID_TILES: Array[int] = [0, 1, 2, 3, 4, 5, 13, 14, 15, 16, 17, 25, 26, 27, 28, 40, 57, 58, 59]


## Full decision for one cell. `roll` is a random number in [0, 1) used for variations.
static func tile_for(is_wall: Callable, x: int, y: int, roll: float) -> int:
	if is_face(is_wall, x, y):
		return WALL_FACE_GRATE if roll < 0.12 else WALL_FACE
	if is_wall.call(x, y):
		return wall_top_tile(is_wall, x, y)
	if is_face(is_wall, x, y - 1):
		return FLOOR_UNDER_WALL
	return floor_tile(roll)


## Mostly plain sand, a few pebbles, rare rubble.
static func floor_tile(roll: float) -> int:
	if roll < 0.02:
		return FLOOR_RUBBLE
	if roll < 0.06:
		return FLOOR_PEBBLES_SMALL
	if roll < 0.12:
		return FLOOR_PEBBLES
	return FLOOR


## The visible brick side of a wall: a wall cell with open floor right below it.
static func is_face(is_wall: Callable, x: int, y: int) -> bool:
	return is_wall.call(x, y) and not is_wall.call(x, y + 1)


## True if the cell is NOT part of a wall top (so a wall top next to it needs a ledge there).
static func is_open(is_wall: Callable, x: int, y: int) -> bool:
	return not is_wall.call(x, y) or is_face(is_wall, x, y)


static func wall_top_tile(is_wall: Callable, x: int, y: int) -> int:
	var up: bool = is_open(is_wall, x, y - 1)
	var down: bool = is_open(is_wall, x, y + 1)
	var left: bool = is_open(is_wall, x - 1, y)
	var right: bool = is_open(is_wall, x + 1, y)
	if up and left: return 4
	if up and right: return 5
	if down and left: return 16
	if down and right: return 17
	if down: return 2
	if up: return 26
	if right: return 13
	if left: return 15
	if is_open(is_wall, x + 1, y + 1): return 1
	if is_open(is_wall, x - 1, y + 1): return 3
	if is_open(is_wall, x + 1, y - 1): return 25
	if is_open(is_wall, x - 1, y - 1): return 27
	return WALL_FILL
