class_name TownLayout
extends RefCounted
## Top-down elevation is traversable only at stairs/ramp; ledges are real blocking cells, not painted shadows.
enum Ground { GRASS, ROAD, PAVING, RESERVED, LEDGE_FRONT, LEDGE_SIDE, LEDGE_BACK, STAIRS, RAMP, TERRACE_GRASS }
const NEIGHBORS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const FENCE_SIDE_OFFSET: int = 2
const DECOR_CLEARANCE: int = 1
const FENCE_STEP: int = 2
const MAX_FENCE_PIECES: int = 3
const FLOWER_OFFSET: Vector2i = Vector2i(-1, 1)
var data: TownData
var blocked: Dictionary = {}
var ledges: Dictionary = {}
var roads: Dictionary = {}
var props: Array[TownPropData] = []

func _init(source: TownData) -> void:
	data = source
	for building in data.buildings:
		_block(building.footprint)
	for cell in TownData.STALL_CELLS:
		_block(Rect2i(cell, TownData.STALL_SIZE))
	_build_ledge_data()
	for prop in data.props:
		props.append(prop)
		if prop.solid:
			_block(prop.footprint)
	for path in TownData.ROAD_PATHS:
		for index in range(path.size() - 1):
			_road_segment(Vector2i(path[index]), Vector2i(path[index + 1]))
	_connect_doors()
	_add_gardens()

func _block(rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			blocked[Vector2i(x, y)] = true

func on_terrace(cell: Vector2i) -> bool:
	for area in TownData.TERRACE_SHAPE:
		if area.has_point(cell):
			return true
	return false

func _build_ledge_data() -> void:
	for y in range(TownData.TERRACE.position.y, TownData.TERRACE.end.y):
		for x in range(TownData.TERRACE.position.x, TownData.TERRACE.end.x):
			var cell := Vector2i(x, y)
			if not on_terrace(cell) or TownData.STAIRS.has_point(cell) or TownData.RAMP.has_point(cell):
				continue
			var edge: bool = false
			for distance in range(1, TownData.LEDGE_WIDTH + 1):
				for direction in NEIGHBORS:
					edge = edge or not on_terrace(cell + direction * distance)
			if edge:
				ledges[cell] = Ground.LEDGE_FRONT if not on_terrace(cell + Vector2i.DOWN) else (Ground.LEDGE_BACK if not on_terrace(cell + Vector2i.UP) else Ground.LEDGE_SIDE)
				blocked[cell] = true

	for y in range(TownData.STAIRS.position.y, TownData.STAIRS.end.y):
		for width in TownData.STAIR_BORDER_TILES:
			for x in [TownData.STAIRS.position.x - width - 1, TownData.STAIRS.end.x + width]:
				var cell := Vector2i(x, y)
				ledges[cell] = Ground.LEDGE_SIDE
				blocked[cell] = true

func in_reserved(cell: Vector2i) -> bool:
	for plot in TownData.RESERVED_PLOTS:
		if plot.has_point(cell):
			return true
	return false

func _paint_road(cell: Vector2i) -> void:
	for dy in range(-TownData.ROAD_HALF_WIDTH, TownData.ROAD_HALF_WIDTH + 1):
		for dx in range(-TownData.ROAD_HALF_WIDTH, TownData.ROAD_HALF_WIDTH + 1):
			var next: Vector2i = cell + Vector2i(dx, dy)
			if walkable(next) and not in_reserved(next):
				roads[next] = true

func _road_segment(a: Vector2i, b: Vector2i) -> void:
	var length: int = maxi(absi(b.x - a.x), absi(b.y - a.y))
	for step in range(length + 1):
		var fraction: float = float(step) / maxi(length, 1)
		_paint_road(Vector2i(Vector2(a).lerp(Vector2(b), fraction).round()))

func _connect_doors() -> void:
	var paths := AStarGrid2D.new()
	paths.region = Rect2i(Vector2i.ZERO, TownData.MAP_SIZE)
	paths.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	paths.update()
	for y in TownData.MAP_SIZE.y:
		for x in TownData.MAP_SIZE.x:
			var cell := Vector2i(x, y)
			paths.set_point_solid(cell, not walkable(cell) or in_reserved(cell))
	for building in data.buildings:
		var door: Vector2i = building.door_cell()
		var goal: Vector2i = TownData.START_CELL
		var best: float = INF
		for road: Vector2i in roads:
			if walkable(road) and not in_reserved(road) and is_equal_approx(elevation(road), elevation(door)):
				var distance: float = Vector2(road).distance_squared_to(Vector2(door))
				if distance < best:
					goal = road
					best = distance
		for cell: Vector2i in paths.get_id_path(door, goal):
			_paint_road(cell)

func _decor_space(rect: Rect2i) -> bool:
	for y in range(rect.position.y - DECOR_CLEARANCE, rect.end.y + DECOR_CLEARANCE):
		for x in range(rect.position.x - DECOR_CLEARANCE, rect.end.x + DECOR_CLEARANCE):
			var cell := Vector2i(x, y)
			if not walkable(cell) or roads.has(cell) or in_reserved(cell) or TownData.STAIRS.has_point(cell) or TownData.RAMP.has_point(cell):
				return false
	return true

func _prop(id_value: StringName, kind_value: StringName, rect: Rect2i, solid_value: bool, variant: int = 0) -> void:
	if not _decor_space(rect):
		return
	var prop := TownPropData.new()
	prop.id = id_value
	prop.kind = kind_value
	prop.footprint = rect
	prop.solid = solid_value
	prop.style = variant
	props.append(prop)
	if prop.solid:
		_block(rect)

func _add_gardens() -> void:
	for building in data.buildings:
		if building.kind != &"house":
			continue
		for side in [-1, 1]:
			var x: int = building.footprint.position.x - FENCE_SIDE_OFFSET if side < 0 else building.footprint.end.x + FENCE_SIDE_OFFSET
			# Merge legal adjacent cells before adding collision, so clearance does not punch holes in a run.
			var run_start: int = -1
			var finish: int = building.footprint.end.y
			for y in range(building.footprint.position.y + 1, finish + 1):
				var allowed: bool = y < finish and _decor_space(Rect2i(Vector2i(x, y), Vector2i.ONE))
				if allowed and run_start < 0:
					run_start = y
				if not allowed and run_start >= 0:
					_prop(StringName("%s_fence_%s_%s" % [building.id, side, run_start]), &"fence_vertical",
						Rect2i(x, run_start, 1, y - run_start), true, building.style)
					run_start = -1
		var flower: Vector2i = Vector2i(building.footprint.position.x, building.footprint.end.y) + FLOWER_OFFSET
		_prop(StringName("%s_flowers" % building.id), &"flowers", Rect2i(flower, Vector2i(2, 1)), false, building.style)
	for index in TownData.TREE_CELLS.size():
		_prop(StringName("tree_%02d" % index), &"tree", Rect2i(TownData.TREE_CELLS[index], Vector2i.ONE), true)
	for index in TownData.STALL_CELLS.size():
		_prop(StringName("market_crate_%02d" % index), &"crate", Rect2i(TownData.STALL_CELLS[index] + Vector2i(TownData.STALL_SIZE.x + 1, 0), Vector2i.ONE), true, index)

func walkable(cell: Vector2i) -> bool:
	return cell.x >= TownData.BORDER_MARGIN and cell.y >= TownData.BORDER_MARGIN \
		and cell.x < TownData.MAP_SIZE.x - TownData.BORDER_MARGIN \
		and cell.y < TownData.MAP_SIZE.y - TownData.BORDER_MARGIN and not blocked.has(cell)

func elevation(cell: Vector2i) -> float:
	if TownData.STAIRS.has_point(cell):
		return clampf(float(TownData.STAIRS.end.y - 1 - cell.y) / (TownData.STAIRS.size.y - 1), 0.0, 1.0)
	if TownData.RAMP.has_point(cell):
		return clampf(float(TownData.RAMP.end.x - 1 - cell.x) / (TownData.RAMP.size.x - 1), 0.0, 1.0)
	return TownData.TERRACE_HEIGHT if on_terrace(cell) else 0.0

func ground(cell: Vector2i) -> int:
	if ledges.has(cell):
		return ledges[cell]
	if TownData.STAIRS.has_point(cell):
		return Ground.STAIRS
	if TownData.RAMP.has_point(cell):
		return Ground.RAMP
	if in_reserved(cell):
		return Ground.RESERVED
	for landing in TownData.STAIR_LANDINGS:
		if landing.has_point(cell):
			return Ground.PAVING
	if TownData.SQUARE.has_point(cell):
		return Ground.PAVING
	return Ground.ROAD if roads.has(cell) else (Ground.TERRACE_GRASS if on_terrace(cell) else Ground.GRASS)

func reachable() -> Dictionary:
	var visited: Dictionary = {TownData.START_CELL: true}
	var pending: Array[Vector2i] = [TownData.START_CELL]
	while not pending.is_empty():
		var cell: Vector2i = pending.pop_back()
		for offset in NEIGHBORS:
			var next: Vector2i = cell + offset
			if walkable(next) and not visited.has(next):
				visited[next] = true
				pending.append(next)
	return visited
