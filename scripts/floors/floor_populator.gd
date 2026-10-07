class_name FloorPopulator
extends RefCounted
## Decides, from the seed, everything a floor contains: monsters, props and wall torches.
## Only data is produced (FloorLayout.Spawn); ChunkManager creates the nodes near the player.
## Amounts scale with each zone's floor area (RegionData densities).

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
## Share of props placed against rock; the rest stand in the open.
const WALL_PROP_SHARE: float = 0.6
const WALL_PROP_TRIES: int = 12
## Props keep this distance (in tiles) from gates and the arena entrance.
const PASSAGE_CLEARANCE: int = 2
## Wall atmosphere is sparse and bounded per streamed chunk to limit lights and nodes.
## Rear faces have no visible mounting surface in the top-down view.
const TORCH_MOUNT_DIRECTIONS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]
const TORCH_CHANCE: float = 0.5
const WALL_DECOR_CHANCE: float = 0.18
const WALL_DECOR_SPACING: int = 3
const MAX_TORCHES_PER_CHUNK: int = 2
const MAX_WALL_DECOR_PER_CHUNK: int = 4
const WALL_DETAIL_SEED_MULTIPLIER: int = 6011
const WALL_DETAIL_SEED_OFFSET: int = 29
const GOBLIN_WALL_DECOR_RADIUS: float = 35.0
const GOBLIN_WALL_DECOR_CHANCE: float = 0.35
const NATURAL_WALL_DECOR: Array[String] = ["cracks", "cracks", "roots", "web"]
const GOBLIN_WALL_DECOR: Array[String] = ["goblin_mark", "wall_bones"]
const MONSTER_PLACEMENT_TRIES: int = 20
const MONSTER_DENSITY_SCALE: float = 100.0
const MIN_MONSTER_TERRAIN_SPEED: float = 0.8
const GROUP_ANCHOR_CLEARANCE_TILES: float = 5.0
## Camp markers can be covered by a solid fire or tent. Start on nearby open ground.
const FEATURE_ENTRY_SEARCH_TILES: int = 5
const FEATURE_NEIGHBORS: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const RING: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0),
	Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0)]


## Monsters everywhere; torches and the generic dungeon props (barrels, chests...) in closed zones only
## (open zones get their own decoration from their ZoneBuilder). `used` holds cells already taken.
static func populate(layout: FloorLayout, data: FloorData, used: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout.seed_value * 7919 + 13
	var floors: Array[PackedInt32Array] = _floor_cells_by_slot(layout)
	for slot in data.regions.size():
		var region: RegionData = data.regions[slot]
		if region.kind == RegionData.Kind.CLOSED:
			_add_torches(layout, data, slot, floors[slot], rng)
			_add_props(layout, region, slot, floors[slot], used, rng)
		_add_monsters(layout, data, region, slot, floors[slot], used, rng)


static func _floor_cells_by_slot(layout: FloorLayout) -> Array[PackedInt32Array]:
	var result: Array[PackedInt32Array] = []
	for slot in layout.slot_count:
		result.append(PackedInt32Array())
	var cells: PackedByteArray = layout.cells_raw()
	var slots: PackedByteArray = layout.slots_raw()
	for i in cells.size():
		if cells[i] == 1:
			result[slots[i]].append(i)
	return result



## Wall details mount on rock next to real walkable ground, including corridor side walls.
## They do not reserve floor cells or change the map's movement/sight data.
static func _add_torches(layout: FloorLayout, data: FloorData, slot: int, floors: PackedInt32Array,
		_rng: RandomNumberGenerator) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout.seed_value * WALL_DETAIL_SEED_MULTIPLIER + WALL_DETAIL_SEED_OFFSET + slot
	var candidates: Dictionary = {}
	for index in floors:
		var floor_cell: Vector2i = _cell_of(layout, index)
		if not layout.is_floor(floor_cell.x, floor_cell.y) or layout.is_protected(floor_cell.x, floor_cell.y):
			continue
		for offset in FEATURE_NEIGHBORS:
			var wall: Vector2i = floor_cell + offset
			if layout.in_bounds(wall.x, wall.y) and layout.slot_at(wall.x, wall.y) == slot \
					and layout.is_rock(wall.x, wall.y) and not layout.is_protected(wall.x, wall.y) \
					and not candidates.has(wall):
				candidates[wall] = -offset
	var cells: Array = candidates.keys()
	# Seeded shuffle prevents details from collecting only along the top edge of each chunk.
	for index in range(cells.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var swap: Vector2i = cells[index]
		cells[index] = cells[other]
		cells[other] = swap
	var torches: Dictionary = {}
	var decor: Dictionary = {}
	var torch_buckets: Dictionary = {}
	var decor_buckets: Dictionary = {}
	var torch_spacing: int = maxi(data.torch_spacing, WALL_DECOR_SPACING)
	for cell: Vector2i in cells:
		var chunk: Vector2i = layout.chunk_of(cell)
		if candidates[cell] in TORCH_MOUNT_DIRECTIONS \
				and torches.get(chunk, 0) < MAX_TORCHES_PER_CHUNK and rng.randf() < TORCH_CHANCE \
				and _wall_detail_far_enough(cell, torch_buckets, torch_spacing) \
				and _wall_detail_far_enough(cell, decor_buckets, WALL_DECOR_SPACING):
			var spawn := FloorLayout.Spawn.new()
			spawn.kind = FloorLayout.SpawnKind.TORCH
			spawn.cell = cell
			spawn.slot = slot
			spawn.wall_direction = candidates[cell]
			layout.add_spawn(spawn)
			torches[chunk] = torches.get(chunk, 0) + 1
			_wall_detail_remember(cell, torch_buckets, torch_spacing)
			_wall_detail_remember(cell, decor_buckets, WALL_DECOR_SPACING)
		elif decor.get(chunk, 0) < MAX_WALL_DECOR_PER_CHUNK and rng.randf() < WALL_DECOR_CHANCE \
				and _wall_detail_far_enough(cell, decor_buckets, WALL_DECOR_SPACING):
			var spawn := FloorLayout.Spawn.new()
			spawn.kind = FloorLayout.SpawnKind.WALL_DECOR
			spawn.cell = cell
			spawn.slot = slot
			spawn.wall_direction = candidates[cell]
			spawn.art = _wall_decor_kind(layout, slot, cell, rng)
			layout.add_spawn(spawn)
			decor[chunk] = decor.get(chunk, 0) + 1
			_wall_detail_remember(cell, decor_buckets, WALL_DECOR_SPACING)


static func _wall_detail_bucket(cell: Vector2i, spacing: int) -> Vector2i:
	return Vector2i(floori(float(cell.x) / spacing), floori(float(cell.y) / spacing))


static func _wall_detail_far_enough(cell: Vector2i, buckets: Dictionary, spacing: int) -> bool:
	var bucket: Vector2i = _wall_detail_bucket(cell, spacing)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			for other: Vector2i in buckets.get(bucket + Vector2i(dx, dy), []):
				if Vector2(cell).distance_to(Vector2(other)) < spacing:
					return false
	return true


static func _wall_detail_remember(cell: Vector2i, buckets: Dictionary, spacing: int) -> void:
	var bucket: Vector2i = _wall_detail_bucket(cell, spacing)
	if not buckets.has(bucket):
		buckets[bucket] = []
	buckets[bucket].append(cell)


static func _wall_decor_kind(layout: FloorLayout, slot: int, cell: Vector2i, rng: RandomNumberGenerator) -> String:
	for feature in layout.features:
		if feature.slot == slot and feature.kind in [&"goblin_camp", &"chieftain_hall"] \
				and Vector2(cell).distance_to(Vector2(feature.cell)) <= GOBLIN_WALL_DECOR_RADIUS \
				and rng.randf() < GOBLIN_WALL_DECOR_CHANCE:
			return GOBLIN_WALL_DECOR[rng.randi() % GOBLIN_WALL_DECOR.size()]
	return NATURAL_WALL_DECOR[rng.randi() % NATURAL_WALL_DECOR.size()]


static func _add_monsters(layout: FloorLayout, data: FloorData, region: RegionData, slot: int,
		floors: PackedInt32Array, used: Dictionary, rng: RandomNumberGenerator) -> void:
	if region.monsters.is_empty() or floors.is_empty():
		return
	var total: int = roundi(floors.size() * region.monsters_per_100_tiles / MONSTER_DENSITY_SCALE)
	var ordinary: Array[MonsterData] = []
	var ecological: Array[MonsterData] = []
	for monster in region.monsters:
		if String(monster.spawn_feature).is_empty():
			ordinary.append(monster)
		else:
			ecological.append(monster)
	var ordinary_count: int = roundi(float(total) * ordinary.size() / region.monsters.size())
	for n in ordinary_count:
		for attempt in MONSTER_PLACEMENT_TRIES:
			var cell: Vector2i = _cell_of(layout, floors[rng.randi() % floors.size()])
			if not _monster_cell_ok(layout, data, slot, cell, used):
				continue
			_add_monster_spawn(layout, slot, cell, ordinary[rng.randi() % ordinary.size()], used)
			break
	var budget: int = roundi(float(total) / region.monsters.size())
	for monster in ecological:
		_add_feature_groups(layout, data, slot, monster, budget, used, rng)


static func _monster_cell_ok(layout: FloorLayout, data: FloorData, slot: int,
		cell: Vector2i, used: Dictionary) -> bool:
	return layout.is_floor(cell.x, cell.y) and layout.slot_at(cell.x, cell.y) == slot \
		and not used.has(cell) and not layout.is_protected(cell.x, cell.y) \
		and Vector2(cell).distance_to(Vector2(layout.start_cell)) >= data.safe_start_radius \
		and Terrain.speed_factor(layout.terrain_at(cell.x, cell.y)) >= MIN_MONSTER_TERRAIN_SPEED


static func _add_monster_spawn(layout: FloorLayout, slot: int, cell: Vector2i,
		monster: MonsterData, used: Dictionary, group_id: int = -1,
		origin_feature: StringName = &"", origin_cell: Vector2i = Vector2i.ZERO) -> void:
	used[cell] = true
	var spawn := FloorLayout.Spawn.new()
	spawn.kind = FloorLayout.SpawnKind.MONSTER
	spawn.cell = cell
	spawn.slot = slot
	spawn.monster = monster
	spawn.group_id = group_id
	spawn.origin_feature = origin_feature
	spawn.origin_cell = origin_cell
	layout.add_spawn(spawn)


## Connected camp territory only: never jump through rock into a neighboring chamber/zone.
static func _feature_territory(layout: FloorLayout, slot: int, origin: Vector2i,
		monster: MonsterData, used: Dictionary) -> Dictionary:
	var territory: Dictionary = {}
	var entry: Vector2i = origin
	var found: bool = false
	for radius in range(FEATURE_ENTRY_SEARCH_TILES + 1):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var candidate: Vector2i = origin + Vector2i(dx, dy)
				if layout.is_floor(candidate.x, candidate.y) and layout.slot_at(candidate.x, candidate.y) == slot \
						and not used.get(candidate, false) \
						and Vector2(candidate).distance_to(Vector2(origin)) <= monster.spawn_radius_tiles:
					entry = candidate
					found = true
					break
			if found:
				break
		if found:
			break
	if not found:
		return territory
	var visited: Dictionary = {entry: true}
	var stack: Array[Vector2i] = [entry]
	while not stack.is_empty():
		var cell: Vector2i = stack.pop_back()
		if not layout.is_floor(cell.x, cell.y) or layout.slot_at(cell.x, cell.y) != slot \
				or Vector2(cell).distance_to(Vector2(origin)) > monster.spawn_radius_tiles:
			continue
		if used.get(cell, false):
			continue
		territory[cell] = true
		for offset in FEATURE_NEIGHBORS:
			var next: Vector2i = cell + offset
			if not visited.has(next):
				visited[next] = true
				stack.append(next)
	return territory


static func _add_feature_groups(layout: FloorLayout, data: FloorData, slot: int,
		monster: MonsterData, budget: int, used: Dictionary, rng: RandomNumberGenerator) -> void:
	var minimum: int = maxi(monster.spawn_group_size.x, 1)
	var maximum: int = maxi(monster.spawn_group_size.y, minimum)
	var remaining: int = budget
	var anchors: Array[Vector2i] = []
	for feature in layout.features:
		if feature.slot != slot or feature.kind != monster.spawn_feature:
			continue
		var territory: Dictionary = _feature_territory(layout, slot, feature.cell, monster, used)
		var cells: Array = territory.keys()
		if cells.is_empty():
			continue
		while remaining >= minimum:
			var count: int = rng.randi_range(minimum, mini(maximum, remaining))
			var placed: bool = false
			for attempt in MONSTER_PLACEMENT_TRIES:
				var anchor: Vector2i = cells[rng.randi() % cells.size()]
				if anchors.any(func(other: Vector2i) -> bool:
					return Vector2(anchor).distance_to(Vector2(other)) < GROUP_ANCHOR_CLEARANCE_TILES):
					continue
				var candidates: Array[Vector2i] = []
				var spread: int = maxi(monster.group_spread_tiles, 1)
				for dy in range(-spread, spread + 1):
					for dx in range(-spread, spread + 1):
						var cell: Vector2i = anchor + Vector2i(dx, dy)
						if territory.has(cell) and _monster_cell_ok(layout, data, slot, cell, used):
							candidates.append(cell)
				if candidates.size() < count:
					continue
				var group_id: int = layout.spawns.size()
				for member in count:
					var index: int = rng.randi() % candidates.size()
					var cell: Vector2i = candidates[index]
					candidates.remove_at(index)
					_add_monster_spawn(layout, slot, cell, monster, used, group_id, feature.kind, feature.cell)
				anchors.append(anchor)
				remaining -= count
				placed = true
				break
			if not placed:
				break  # Never fill missing camp groups with solitary monsters elsewhere.


static func _add_props(layout: FloorLayout, region: RegionData, slot: int, floors: PackedInt32Array,
		used: Dictionary, rng: RandomNumberGenerator) -> void:
	if floors.is_empty():
		return
	var total: int = roundi(floors.size() * region.decor_per_100_tiles / 100.0)
	var against_wall: int = roundi(total * WALL_PROP_SHARE)
	for n in total:
		var tries: int = WALL_PROP_TRIES if n < against_wall else 3
		for attempt in tries:
			var cell: Vector2i = _cell_of(layout, floors[rng.randi() % floors.size()])
			if n < against_wall and not _touches_rock(layout, cell):
				continue
			var prop: Dictionary = _pick_prop(rng)
			if not _prop_cell_ok(layout, cell, used, prop["solid"]):
				continue
			var spawn := FloorLayout.Spawn.new()
			spawn.kind = FloorLayout.SpawnKind.PROP
			spawn.cell = cell
			spawn.slot = slot
			spawn.tile_index = prop["tile"]
			spawn.solid = prop["solid"]
			layout.add_spawn(spawn)
			used[cell] = prop["solid"]
			break


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


static func _prop_cell_ok(layout: FloorLayout, cell: Vector2i, used: Dictionary, solid: bool) -> bool:
	if used.has(cell) or not layout.is_floor(cell.x, cell.y):
		return false
	for dy in range(-PASSAGE_CLEARANCE, PASSAGE_CLEARANCE + 1):
		for dx in range(-PASSAGE_CLEARANCE, PASSAGE_CLEARANCE + 1):
			if layout.is_protected(cell.x + dx, cell.y + dy):
				return false
	return not solid or _keeps_passage(layout, cell, used)


## A solid prop must not cut a path: the open cells around it must form one unbroken run.
static func _keeps_passage(layout: FloorLayout, cell: Vector2i, used: Dictionary) -> bool:
	var runs: int = 0
	var last_open: bool = _is_open(layout, cell + RING[RING.size() - 1], used)
	for offset in RING:
		var open: bool = _is_open(layout, cell + offset, used)
		if open and not last_open:
			runs += 1
		last_open = open
	return runs <= 1


static func _is_open(layout: FloorLayout, cell: Vector2i, used: Dictionary) -> bool:
	return layout.is_floor(cell.x, cell.y) and not used.get(cell, false)


static func _touches_rock(layout: FloorLayout, cell: Vector2i) -> bool:
	return layout.is_wall(cell.x - 1, cell.y) or layout.is_wall(cell.x + 1, cell.y) \
		or layout.is_wall(cell.x, cell.y - 1) or layout.is_wall(cell.x, cell.y + 1)


static func _cell_of(layout: FloorLayout, index: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(index % layout.size.x, index / layout.size.x)
