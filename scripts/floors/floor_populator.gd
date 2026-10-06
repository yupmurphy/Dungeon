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
## Chance that a wall face on the torch grid gets a torch (closed zones only).
const TORCH_CHANCE: float = 0.5
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


## Torches on brick faces (rock with floor below), on a grid so they are spread out.
static func _add_torches(layout: FloorLayout, data: FloorData, slot: int, floors: PackedInt32Array,
		rng: RandomNumberGenerator) -> void:
	var w: int = layout.size.x
	for i in floors:
		var x: int = i % w
		@warning_ignore("integer_division")
		var y: int = i / w
		if x % data.torch_spacing != 0 or not WallTiler.is_face(layout.is_rock, x, y - 1):
			continue
		if rng.randf() >= TORCH_CHANCE:
			continue
		var spawn := FloorLayout.Spawn.new()
		spawn.kind = FloorLayout.SpawnKind.TORCH
		spawn.cell = Vector2i(x, y - 1)
		spawn.slot = slot
		layout.add_spawn(spawn)


static func _add_monsters(layout: FloorLayout, data: FloorData, region: RegionData, slot: int,
		floors: PackedInt32Array, used: Dictionary, rng: RandomNumberGenerator) -> void:
	if region.monsters.is_empty() or floors.is_empty():
		return
	var count: int = roundi(floors.size() * region.monsters_per_100_tiles / 100.0)
	var safe: float = data.safe_start_radius
	for n in count:
		for attempt in 20:
			var cell: Vector2i = _cell_of(layout, floors[rng.randi() % floors.size()])
			if used.has(cell) or layout.is_protected(cell.x, cell.y) \
					or Vector2(cell).distance_to(Vector2(layout.start_cell)) < safe \
					or Terrain.speed_factor(layout.terrain_at(cell.x, cell.y)) < 0.8:
				continue
			used[cell] = true
			var spawn := FloorLayout.Spawn.new()
			spawn.kind = FloorLayout.SpawnKind.MONSTER
			spawn.cell = cell
			spawn.slot = slot
			spawn.monster = region.monsters[rng.randi() % region.monsters.size()]
			layout.add_spawn(spawn)
			break


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
