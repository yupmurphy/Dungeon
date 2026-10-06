class_name FloorGenerator
extends RefCounted
## Builds a FloorLayout from FloorData + seed. Same seed => same floor.
##
## 1. The map is cut into sectors (4 x 4 sectors of 40 x 40 tiles for a 160 x 160 floor).
## 2. Start sector on the map edge; boss sector = the sector farthest from it.
## 3. The other sectors are shared between the regions by a random flood fill, so every
##    region is one connected block and lands somewhere else on each generation.
## 4. One room per sector. Corridors follow a random spanning tree of neighboring sectors
##    (everything reachable) plus a few extra links (loops, so it's not a pure maze).
## 5. The boss arena is linked to exactly one neighbor; the portal sits at the far end of the arena.

const SECTOR_MARGIN: int = 3
const CORRIDOR_HALF_WIDTH: int = 1  # 3 tiles wide
const EXTRA_LINK_CHANCE: float = 0.3
const MIN_ROOM: Vector2i = Vector2i(12, 10)
const MAX_ROOM: Vector2i = Vector2i(28, 24)
const START_ROOM: Vector2i = Vector2i(14, 12)
const BOSS_ROOM: Vector2i = Vector2i(30, 26)
## Rooms at least this big may get stone pillars.
const PILLAR_ROOM_MIN: Vector2i = Vector2i(18, 16)
const PILLAR_CHANCE: float = 0.5
const PORTAL_WALL_DISTANCE: int = 3


static func generate(data: FloorData, seed_value: int) -> FloorLayout:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var layout := FloorLayout.new()
	layout.setup(data.map_size, data.sector_grid, seed_value, data.regions.size())

	var start: Vector2i = _pick_start_sector(layout, rng)
	var boss: Vector2i = _farthest_sector(layout, start, rng)
	layout.boss_sector = boss
	layout.set_sector_slot(start, FloorLayout.START_SLOT)
	layout.set_sector_slot(boss, layout.boss_slot)
	_assign_regions(layout, rng)

	var room_by_sector: Dictionary = {}
	for sector in layout.all_sectors():
		room_by_sector[sector] = _carve_room(layout, sector, rng)
	_connect_sectors(layout, room_by_sector, start, boss, rng)
	for room in layout.rooms:
		if room.kind == FloorLayout.RoomKind.NORMAL:
			_add_pillars(layout, room, rng)

	layout.start_cell = (room_by_sector[start] as FloorLayout.Room).center()
	layout.finalize()
	return layout


static func _pick_start_sector(layout: FloorLayout, rng: RandomNumberGenerator) -> Vector2i:
	var edge: Array[Vector2i] = []
	for sector in layout.all_sectors():
		if sector.x == 0 or sector.y == 0 or sector.x == layout.sector_grid.x - 1 \
				or sector.y == layout.sector_grid.y - 1:
			edge.append(sector)
	return edge[rng.randi() % edge.size()]


static func _farthest_sector(layout: FloorLayout, from: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	var best: Array[Vector2i] = []
	var best_distance: int = -1
	for sector in layout.all_sectors():
		var distance: int = absi(sector.x - from.x) + absi(sector.y - from.y)
		if distance > best_distance:
			best_distance = distance
			best = [sector]
		elif distance == best_distance:
			best.append(sector)
	return best[rng.randi() % best.size()]


static func _assign_regions(layout: FloorLayout, rng: RandomNumberGenerator) -> void:
	var free: Array[Vector2i] = []
	for sector in layout.all_sectors():
		if layout.sector_slot(sector) == -1:
			free.append(sector)

	# Region seeds spread apart: each new seed is one of the sectors farthest from the previous ones.
	var seeds: Array[Vector2i] = []
	for region in layout.region_count:
		var candidates: Array[Vector2i] = []
		var best_distance: int = -1
		for sector in free:
			var distance: int = 1000
			for other in seeds:
				distance = mini(distance, absi(sector.x - other.x) + absi(sector.y - other.y))
			if distance > best_distance:
				best_distance = distance
				candidates = [sector]
			elif distance == best_distance:
				candidates.append(sector)
		var chosen: Vector2i = candidates[rng.randi() % candidates.size()]
		seeds.append(chosen)
		free.erase(chosen)
		layout.set_sector_slot(chosen, region + 1)

	# Grow the regions one sector at a time, in random order, so they stay similar in size.
	var grew: bool = true
	while not free.is_empty() and grew:
		grew = false
		var order: Array = range(layout.region_count)
		_shuffle(order, rng)
		for region: int in order:
			var options: Array[Vector2i] = []
			for sector in free:
				for neighbor in layout.sector_neighbors(sector):
					if layout.sector_slot(neighbor) == region + 1:
						options.append(sector)
						break
			if options.is_empty():
				continue
			var picked: Vector2i = options[rng.randi() % options.size()]
			free.erase(picked)
			layout.set_sector_slot(picked, region + 1)
			grew = true

	# Sectors no region could reach (rare) join a neighboring region.
	for sector in free:
		var slot: int = FloorLayout.START_SLOT
		for neighbor in layout.sector_neighbors(sector):
			var neighbor_slot: int = layout.sector_slot(neighbor)
			if neighbor_slot > 0 and neighbor_slot != layout.boss_slot:
				slot = neighbor_slot
		layout.set_sector_slot(sector, slot)


static func _carve_room(layout: FloorLayout, sector: Vector2i, rng: RandomNumberGenerator) -> FloorLayout.Room:
	var slot: int = layout.sector_slot(sector)
	var room := FloorLayout.Room.new()
	room.sector = sector
	room.slot = slot
	var room_size: Vector2i
	if slot == FloorLayout.START_SLOT:
		room.kind = FloorLayout.RoomKind.START
		room_size = START_ROOM
	elif slot == layout.boss_slot:
		room.kind = FloorLayout.RoomKind.BOSS
		room_size = BOSS_ROOM
	else:
		room.kind = FloorLayout.RoomKind.NORMAL
		room_size = Vector2i(rng.randi_range(MIN_ROOM.x, MAX_ROOM.x), rng.randi_range(MIN_ROOM.y, MAX_ROOM.y))

	var available: Vector2i = layout.sector_size - Vector2i(SECTOR_MARGIN, SECTOR_MARGIN) * 2
	room_size = room_size.min(available)
	var origin: Vector2i = sector * layout.sector_size + Vector2i(SECTOR_MARGIN, SECTOR_MARGIN)
	var position: Vector2i = origin + Vector2i(
		rng.randi_range(0, available.x - room_size.x), rng.randi_range(0, available.y - room_size.y))
	room.rect = Rect2i(position, room_size)
	for y in range(room.rect.position.y, room.rect.end.y):
		for x in range(room.rect.position.x, room.rect.end.x):
			layout.set_floor(x, y, true)
	layout.rooms.append(room)
	if room.kind == FloorLayout.RoomKind.BOSS:
		layout.boss_room = room
	return room


static func _connect_sectors(layout: FloorLayout, room_by_sector: Dictionary, start: Vector2i,
		boss: Vector2i, rng: RandomNumberGenerator) -> void:
	# Random spanning tree (randomized Prim) over every sector except the boss arena.
	var visited: Dictionary = {start: true}
	var frontier: Array[Array] = []
	for neighbor in layout.sector_neighbors(start):
		if neighbor != boss:
			frontier.append([start, neighbor])
	var used: Dictionary = {}
	while not frontier.is_empty():
		var edge: Array = frontier.pop_at(rng.randi() % frontier.size())
		var target: Vector2i = edge[1]
		if visited.has(target):
			continue
		visited[target] = true
		_link(layout, room_by_sector, edge[0], target, rng)
		used[_edge_key(edge[0], target)] = true
		for neighbor in layout.sector_neighbors(target):
			if neighbor != boss and not visited.has(neighbor):
				frontier.append([target, neighbor])

	# Extra links make loops, so there is more than one way around.
	for sector in layout.all_sectors():
		if sector == boss:
			continue
		for neighbor in layout.sector_neighbors(sector):
			if neighbor == boss or neighbor < sector or used.has(_edge_key(sector, neighbor)):
				continue
			if rng.randf() < EXTRA_LINK_CHANCE:
				_link(layout, room_by_sector, sector, neighbor, rng)
				used[_edge_key(sector, neighbor)] = true

	# The boss arena gets exactly one entrance; the portal goes on the opposite side.
	var entries: Array[Vector2i] = layout.sector_neighbors(boss)
	var entry: Vector2i = entries[rng.randi() % entries.size()]
	_link(layout, room_by_sector, entry, boss, rng)
	var arena: FloorLayout.Room = room_by_sector[boss]
	var away: Vector2i = boss - entry  # points from the entrance into the arena and beyond
	var center: Vector2i = arena.center()
	@warning_ignore("integer_division")
	layout.portal_cell = Vector2i(
		center.x + away.x * (arena.rect.size.x / 2 - PORTAL_WALL_DISTANCE),
		center.y + away.y * (arena.rect.size.y / 2 - PORTAL_WALL_DISTANCE))


static func _link(layout: FloorLayout, room_by_sector: Dictionary, a: Vector2i, b: Vector2i,
		rng: RandomNumberGenerator) -> void:
	layout.connections.append([a, b])
	var from: Vector2i = (room_by_sector[a] as FloorLayout.Room).center()
	var to: Vector2i = (room_by_sector[b] as FloorLayout.Room).center()
	# L-shaped corridor; which leg comes first is random.
	var corner: Vector2i = Vector2i(to.x, from.y) if rng.randf() < 0.5 else Vector2i(from.x, to.y)
	_carve_line(layout, from, corner)
	_carve_line(layout, corner, to)


static func _carve_line(layout: FloorLayout, from: Vector2i, to: Vector2i) -> void:
	var step: Vector2i = (to - from).sign()
	var cell: Vector2i = from
	while true:
		for dy in range(-CORRIDOR_HALF_WIDTH, CORRIDOR_HALF_WIDTH + 1):
			for dx in range(-CORRIDOR_HALF_WIDTH, CORRIDOR_HALF_WIDTH + 1):
				layout.set_floor(cell.x + dx, cell.y + dy, true)
				layout.mark_corridor(cell.x + dx, cell.y + dy)
		if cell == to:
			break
		cell += step


## Stone pillars (2 wide x 3 tall) in the room's quarters, never on a corridor or touching a wall.
static func _add_pillars(layout: FloorLayout, room: FloorLayout.Room, rng: RandomNumberGenerator) -> void:
	var rect: Rect2i = room.rect
	if rect.size.x < PILLAR_ROOM_MIN.x or rect.size.y < PILLAR_ROOM_MIN.y or rng.randf() > PILLAR_CHANCE:
		return
	var spots: Array[Vector2i] = [
		rect.position + Vector2i(3, 3),
		Vector2i(rect.end.x - 5, rect.position.y + 3),
		Vector2i(rect.position.x + 3, rect.end.y - 6),
		rect.end - Vector2i(5, 6),
	]
	for spot in spots:
		if _pillar_fits(layout, spot):
			for y in range(spot.y, spot.y + 3):
				for x in range(spot.x, spot.x + 2):
					layout.set_floor(x, y, false)


static func _pillar_fits(layout: FloorLayout, spot: Vector2i) -> bool:
	# Pillar plus a one-tile ring must be plain room floor (no corridor, no wall).
	for y in range(spot.y - 1, spot.y + 4):
		for x in range(spot.x - 1, spot.x + 3):
			if not layout.is_floor(x, y) or layout.is_corridor(x, y):
				return false
	return true


static func _edge_key(a: Vector2i, b: Vector2i) -> String:
	return "%s-%s" % [a, b] if a < b else "%s-%s" % [b, a]


## Seeded Fisher-Yates (Array.shuffle() would use the global, unseeded RNG).
static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var temp: Variant = items[i]
		items[i] = items[j]
		items[j] = temp
