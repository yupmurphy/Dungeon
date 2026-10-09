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
## Wall details (closed zones only), capped per streamed chunk.
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
const SIDES: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
## Group members stand within this many tiles of each other; placing them gives up after this many tries each.
const GROUP_SPREAD: int = 2
const GROUP_TRIES: int = 6
## Groups living around a home place (goblin camp) stand this far from its center, in tiles.
const HOME_GROUP_DISTANCE: float = 5.0
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


## Torches and wall details (cracks, roots, webs; goblin marks and bones near goblin places) on rock next to
## walkable ground, side walls of corridors too. Sparse and capped per chunk (lights and nodes cost).
## They only face the room (down, left, right): a wall's back side is not seen from above.
static func _add_torches(layout: FloorLayout, data: FloorData, slot: int, floors: PackedInt32Array,
		_rng: RandomNumberGenerator) -> void:
	# Own random stream: adding wall details does not move the monsters and props of a seed.
	var rng := RandomNumberGenerator.new()
	rng.seed = layout.seed_value * WALL_DETAIL_SEED_MULTIPLIER + WALL_DETAIL_SEED_OFFSET + slot
	var candidates: Dictionary = {}
	for index in floors:
		var floor_cell: Vector2i = _cell_of(layout, index)
		if layout.is_protected(floor_cell.x, floor_cell.y):
			continue
		for offset in SIDES:
			var wall: Vector2i = floor_cell + offset
			if layout.slot_at(wall.x, wall.y) == slot and layout.is_rock(wall.x, wall.y) \
					and not layout.is_protected(wall.x, wall.y) and not candidates.has(wall):
				candidates[wall] = -offset
	var cells: Array = candidates.keys()
	# Seeded shuffle, so details do not collect along the top edge of each chunk.
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
		var facing: Vector2i = candidates[cell]
		var spawn := FloorLayout.Spawn.new()
		spawn.cell = cell
		spawn.slot = slot
		spawn.wall_direction = facing
		if facing in TORCH_MOUNT_DIRECTIONS and torches.get(chunk, 0) < MAX_TORCHES_PER_CHUNK \
				and rng.randf() < TORCH_CHANCE and _far_enough(cell, torch_buckets, torch_spacing) \
				and _far_enough(cell, decor_buckets, WALL_DECOR_SPACING):
			spawn.kind = FloorLayout.SpawnKind.TORCH
			torches[chunk] = torches.get(chunk, 0) + 1
			_remember(cell, torch_buckets, torch_spacing)
		elif facing in TORCH_MOUNT_DIRECTIONS and decor.get(chunk, 0) < MAX_WALL_DECOR_PER_CHUNK \
				and rng.randf() < WALL_DECOR_CHANCE and _far_enough(cell, decor_buckets, WALL_DECOR_SPACING):
			spawn.kind = FloorLayout.SpawnKind.WALL_DECOR
			spawn.art = _wall_decor_kind(layout, slot, cell, rng)
			decor[chunk] = decor.get(chunk, 0) + 1
		else:
			continue
		layout.add_spawn(spawn)
		_remember(cell, decor_buckets, WALL_DECOR_SPACING)


## Nothing of the same kind closer than `spacing` (cells grouped in buckets of that size, checked around).
static func _far_enough(cell: Vector2i, buckets: Dictionary, spacing: int) -> bool:
	var bucket: Vector2i = Vector2i((Vector2(cell) / spacing).floor())
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			for other: Vector2i in buckets.get(bucket + Vector2i(dx, dy), []):
				if Vector2(cell).distance_to(Vector2(other)) < spacing:
					return false
	return true


static func _remember(cell: Vector2i, buckets: Dictionary, spacing: int) -> void:
	var bucket: Vector2i = Vector2i((Vector2(cell) / spacing).floor())
	buckets.get_or_add(bucket, []).append(cell)


static func _wall_decor_kind(layout: FloorLayout, slot: int, cell: Vector2i, rng: RandomNumberGenerator) -> String:
	for feature in layout.features:
		if feature.slot == slot and feature.kind in [&"goblin_camp", &"chieftain_hall"] \
				and Vector2(cell).distance_to(Vector2(feature.cell)) <= GOBLIN_WALL_DECOR_RADIUS \
				and rng.randf() < GOBLIN_WALL_DECOR_CHANCE:
			return GOBLIN_WALL_DECOR[rng.randi() % GOBLIN_WALL_DECOR.size()]
	return NATURAL_WALL_DECOR[rng.randi() % NATURAL_WALL_DECOR.size()]


static func _add_monsters(layout: FloorLayout, data: FloorData, region: RegionData, slot: int,
		floors: PackedInt32Array, used: Dictionary, rng: RandomNumberGenerator) -> void:
	if floors.is_empty():
		return
	var count: int = 0 if region.monsters.is_empty() else roundi(floors.size() * region.monsters_per_100_tiles / 100.0)
	var safe: float = data.safe_start_radius
	for n in count:
		for attempt in 20:
			var cell: Vector2i = _cell_of(layout, floors[rng.randi() % floors.size()])
			if used.has(cell) or layout.is_protected(cell.x, cell.y) \
					or Vector2(cell).distance_to(Vector2(layout.start_cell)) < safe \
					or Terrain.speed_factor(layout.terrain_at(cell.x, cell.y)) < 0.8:
				continue
			_spawn_group(layout, data, region.monsters[rng.randi() % region.monsters.size()], cell, slot, used, rng)
			break
	# Monsters that live somewhere (goblins in their camps) also gather there; home monsters live only there.
	for monster in region.monsters + region.home_monsters:
		if monster.home_feature == &"" or monster.groups_per_home <= 0:
			continue
		for feature in layout.features:
			if feature.kind != monster.home_feature or feature.slot != slot:
				continue
			for g in monster.groups_per_home:
				var offset: Vector2 = Vector2.from_angle(rng.randf() * TAU) * HOME_GROUP_DISTANCE
				var spot: Vector2i = feature.cell + Vector2i(offset.round())
				_spawn_group(layout, data, monster, spot, slot, used, rng)


## One monster, or a group of them (MonsterData.group_size) on free cells close to `cell`.
static func _spawn_group(layout: FloorLayout, data: FloorData, monster: MonsterData, cell: Vector2i, slot: int,
		used: Dictionary, rng: RandomNumberGenerator) -> void:
	var count: int = rng.randi_range(monster.group_size.x, maxi(monster.group_size.x, monster.group_size.y))
	var placed: int = 0
	for attempt in count * GROUP_TRIES:
		if placed >= count:
			break
		var spot: Vector2i = cell if attempt == 0 else cell + Vector2i(rng.randi_range(-GROUP_SPREAD, GROUP_SPREAD),
			rng.randi_range(-GROUP_SPREAD, GROUP_SPREAD))
		if used.has(spot) or not layout.is_floor(spot.x, spot.y) or layout.slot_at(spot.x, spot.y) != slot \
				or layout.is_protected(spot.x, spot.y) \
				or Vector2(spot).distance_to(Vector2(layout.start_cell)) < data.safe_start_radius:
			continue
		used[spot] = true
		var spawn := FloorLayout.Spawn.new()
		spawn.kind = FloorLayout.SpawnKind.MONSTER
		spawn.cell = spot
		spawn.slot = slot
		spawn.monster = monster
		if placed == 0 and monster.group_leader != null and rng.randf() < monster.leader_chance:
			spawn.monster = monster.group_leader
		layout.add_spawn(spawn)
		placed += 1


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
