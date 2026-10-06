class_name FloorPopulator
extends RefCounted
## Decides, from the seed, everything a floor contains: monsters, props and wall torches.
## Only data is produced (FloorLayout.Spawn); ChunkManager creates the nodes near the player.
## Amounts scale with hall size (RegionData densities), so bigger halls get more of everything.

## Prop tiles (see TileAtlas) with weights; the solid ones block movement.
const PROPS: Array[Dictionary] = [
	{"tile": 66, "weight": 5, "solid": true},   # barrel
	{"tile": 65, "weight": 2, "solid": true},   # tombstone
	{"tile": 64, "weight": 2, "solid": true},   # stone post
	{"tile": 73, "weight": 2, "solid": false},  # stool
	{"tile": 74, "weight": 1, "solid": true},   # anvil
	{"tile": 63, "weight": 1, "solid": true},   # shelf
	{"tile": 89, "weight": 1, "solid": true},   # chest
]
## Share of props placed along the walls; the rest form small clusters inside the hall.
const WALL_PROP_SHARE: float = 0.65
const START_ROOM_DECOR_FACTOR: float = 0.5
## Props keep this distance (in tiles) from corridor floor so doorways stay free.
const DOORWAY_CLEARANCE: int = 2


static func populate(layout: FloorLayout, data: FloorData) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout.seed_value * 7919 + 13
	for room in layout.rooms:
		var used: Dictionary = {}
		_add_torches(layout, data, room)
		var region: RegionData = null
		if room.slot >= 1 and room.slot <= data.regions.size():
			region = data.regions[room.slot - 1]
		match room.kind:
			FloorLayout.RoomKind.NORMAL:
				_add_props(layout, room, region.decor_per_100_tiles if region else 1.0, used, rng)
				if region != null:
					_add_monsters(layout, room, region, used, rng)
			FloorLayout.RoomKind.START:
				_add_props(layout, room, START_ROOM_DECOR_FACTOR, used, rng)


## Torches along the brick face above the hall's top edge.
static func _add_torches(layout: FloorLayout, data: FloorData, room: FloorLayout.Room) -> void:
	var y: int = room.rect.position.y - 1
	var x: int = room.rect.position.x + 2
	while x < room.rect.end.x - 1:
		if WallTiler.is_face(layout.is_wall, x, y):
			var spawn := FloorLayout.Spawn.new()
			spawn.kind = FloorLayout.SpawnKind.TORCH
			spawn.cell = Vector2i(x, y)
			spawn.slot = room.slot
			layout.add_spawn(spawn)
		x += data.torch_spacing


static func _add_monsters(layout: FloorLayout, room: FloorLayout.Room, region: RegionData,
		used: Dictionary, rng: RandomNumberGenerator) -> void:
	if region.monsters.is_empty():
		return
	var count: int = roundi(room.area() * region.monsters_per_100_tiles / 100.0)
	var inner: Rect2i = room.rect.grow(-2)
	for i in count:
		var cell: Vector2i = _random_free_cell(layout, inner, used, rng)
		if cell.x < 0:
			continue
		used[cell] = true
		var spawn := FloorLayout.Spawn.new()
		spawn.kind = FloorLayout.SpawnKind.MONSTER
		spawn.cell = cell
		spawn.slot = room.slot
		spawn.monster = region.monsters[rng.randi() % region.monsters.size()]
		layout.add_spawn(spawn)


static func _add_props(layout: FloorLayout, room: FloorLayout.Room, density: float,
		used: Dictionary, rng: RandomNumberGenerator) -> void:
	var total: int = roundi(room.area() * density / 100.0)
	var along_walls: int = roundi(total * WALL_PROP_SHARE)

	# Along the walls: the ring of cells one tile inside the hall.
	var ring: Array[Vector2i] = []
	var inner: Rect2i = room.rect.grow(-1)
	for x in range(inner.position.x, inner.end.x):
		ring.append(Vector2i(x, inner.position.y))
		ring.append(Vector2i(x, inner.end.y - 1))
	for y in range(inner.position.y + 1, inner.end.y - 1):
		ring.append(Vector2i(inner.position.x, y))
		ring.append(Vector2i(inner.end.x - 1, y))
	FloorGenerator._shuffle(ring, rng)
	var placed: int = 0
	for cell in ring:
		if placed >= along_walls:
			break
		if _prop_cell_ok(layout, cell, used):
			_add_prop(layout, room, cell, used, rng)
			placed += 1

	# Inside: small clusters of 1-3 props.
	var left: int = total - placed
	var middle: Rect2i = room.rect.grow(-3)
	while left > 0:
		var anchor: Vector2i = _random_free_cell(layout, middle, used, rng)
		if anchor.x < 0:
			break
		var cluster: int = mini(rng.randi_range(1, 3), left)
		for i in cluster:
			var cell: Vector2i = anchor + Vector2i(i % 2, i >> 1)
			if _prop_cell_ok(layout, cell, used):
				_add_prop(layout, room, cell, used, rng)
		left -= cluster


static func _add_prop(layout: FloorLayout, room: FloorLayout.Room, cell: Vector2i, used: Dictionary,
		rng: RandomNumberGenerator) -> void:
	var prop: Dictionary = _pick_prop(rng)
	var spawn := FloorLayout.Spawn.new()
	spawn.kind = FloorLayout.SpawnKind.PROP
	spawn.cell = cell
	spawn.slot = room.slot
	spawn.tile_index = prop["tile"]
	spawn.solid = prop["solid"]
	layout.add_spawn(spawn)
	used[cell] = true


static func _pick_prop(rng: RandomNumberGenerator) -> Dictionary:
	var total: int = 0
	for prop in PROPS:
		total += prop["weight"]
	var roll: int = rng.randi_range(0, total - 1)
	for prop in PROPS:
		roll -= prop["weight"]
		if roll < 0:
			return prop
	return PROPS[0]


## Free hall floor, away from corridors (doorways) and from pillars.
static func _prop_cell_ok(layout: FloorLayout, cell: Vector2i, used: Dictionary) -> bool:
	if used.has(cell) or not layout.is_floor(cell.x, cell.y):
		return false
	for dy in range(-DOORWAY_CLEARANCE, DOORWAY_CLEARANCE + 1):
		for dx in range(-DOORWAY_CLEARANCE, DOORWAY_CLEARANCE + 1):
			if layout.is_corridor(cell.x + dx, cell.y + dy):
				return false
	# Keep a free tile next to pillars so they never seal a gap.
	for offset: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var next: Vector2i = cell + offset
		if layout.is_wall(next.x, next.y) and not _touches_hall_edge(layout, cell):
			return false
	return true


## True if the cell is in the outer ring of its hall (walls there are the hall's own walls, not pillars).
static func _touches_hall_edge(layout: FloorLayout, cell: Vector2i) -> bool:
	for room in layout.rooms:
		if room.rect.has_point(cell):
			var inner: Rect2i = room.rect.grow(-1)
			return not inner.grow(-1).has_point(cell)
	return true


static func _random_free_cell(layout: FloorLayout, area: Rect2i, used: Dictionary,
		rng: RandomNumberGenerator) -> Vector2i:
	if area.size.x <= 0 or area.size.y <= 0:
		return Vector2i(-1, -1)
	for attempt in 30:
		var cell := Vector2i(rng.randi_range(area.position.x, area.end.x - 1),
			rng.randi_range(area.position.y, area.end.y - 1))
		if layout.is_floor(cell.x, cell.y) and not used.has(cell):
			return cell
	return Vector2i(-1, -1)
