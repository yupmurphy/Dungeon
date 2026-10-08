class_name FloorPaths
## Ways around walls for monsters: A* over the floor grid (FloorLayout.active), in a window of cells around the
## player (every chasing monster is near the player). The window is rebuilt only when the player gets near its
## edge or the floor changes. Without an active floor (town, test rooms) there is no path: monsters walk straight.
## Only the grid (rock, trees, deep water) is known; small solid props are left to CornerSlide.

## Cells on each side of the player (the chase gives up at about 18 tiles).
const WINDOW_RADIUS: int = 40
## Rebuilt when the player is this many cells from the window's center.
const REBUILD_DISTANCE: int = 16

static var _grid: AStarGrid2D
static var _layout: FloorLayout
static var _center: Vector2i


## World points to walk through, from `from` to `to` (both world positions), without the start cell.
## Empty when there is no floor grid or no way (then the caller walks straight).
## When `to` can't be reached (a wall cell), the path goes as close as it can.
static func find(from: Vector2, to: Vector2, around: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var layout: FloorLayout = FloorLayout.active
	if layout == null:
		return points
	_ensure(layout, _cell(around))
	var start: Vector2i = _cell(from)
	var goal: Vector2i = _cell(to)
	if not _grid.region.has_point(start) or not _grid.region.has_point(goal):
		return points
	# A monster pushed into a wall cell's edge still starts from its own cell.
	var start_was_solid: bool = _grid.is_point_solid(start)
	_grid.set_point_solid(start, false)
	var cells: Array[Vector2i] = _grid.get_id_path(start, goal, true)
	_grid.set_point_solid(start, start_was_solid)
	for i in range(1, cells.size()):
		points.append((Vector2(cells[i]) + Vector2(0.5, 0.5)) * GameScale.TILE_SIZE)
	return points


## Forgets the window (a new floor, tests).
static func reset() -> void:
	_grid = null
	_layout = null


static func _cell(world_position: Vector2) -> Vector2i:
	return Vector2i((world_position / GameScale.TILE_SIZE).floor())


static func _ensure(layout: FloorLayout, center: Vector2i) -> void:
	if _grid != null and _layout == layout and absi(center.x - _center.x) < REBUILD_DISTANCE \
			and absi(center.y - _center.y) < REBUILD_DISTANCE:
		return
	_layout = layout
	_center = center
	_grid = AStarGrid2D.new()
	_grid.region = Rect2i(center - Vector2i.ONE * WINDOW_RADIUS, Vector2i.ONE * (WINDOW_RADIUS * 2 + 1))
	_grid.cell_size = Vector2.ONE
	# Diagonal steps only past open corners, so bodies don't snag on a wall's corner.
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.update()
	var region: Rect2i = _grid.region
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if not layout.is_floor(x, y):
				_grid.set_point_solid(Vector2i(x, y))
