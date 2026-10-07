class_name WallAtmosphereChecks
extends RefCounted

const PLACEMENT_CHECK: String = "wall atmosphere: rock mounts, spacing, chunk caps, front/lateral torches only, no luminous crystals"
const GEOMETRY_CHECK: String = "wall atmosphere does not modify floor, terrain, sight or protected cells"
const FLAME_CHECK: String = "wall torches have four distinct cached flame frames"
const SCENE_CHECK: String = "raised front torch clears the floor; other three short mounts and shadows stay correct, animation and flame lights; decor stays non-solid"
const MAX_TORCH_PROJECTION_GAP: float = 2.0
const UNIT_SIZE: Vector2i = Vector2i(64, 64)
const UNIT_MARGIN: int = 8
const UNIT_SEED: int = 1


static func unit_results() -> Dictionary:
	var results: Dictionary = {}
	var frames: Dictionary = {}
	for frame in WallArt.FLAME_FRAMES:
		var texture: ImageTexture = WallArt.torch_texture(frame)
		frames[hash(texture.get_image().get_data())] = true
	results[FLAME_CHECK] = frames.size() == WallArt.FLAME_FRAMES
	var layout := FloorLayout.new()
	layout.setup(UNIT_SIZE, UNIT_SEED, 1)
	var floors := PackedInt32Array()
	for y in UNIT_SIZE.y:
		for x in UNIT_SIZE.x:
			layout.set_slot(x, y, 0)
			if x >= UNIT_MARGIN and y >= UNIT_MARGIN and x < UNIT_SIZE.x - UNIT_MARGIN and y < UNIT_SIZE.y - UNIT_MARGIN:
				layout.paint(x, y, Terrain.Type.CAVE)
				floors.append(y * UNIT_SIZE.x + x)
	layout.protect(UNIT_MARGIN, UNIT_MARGIN)
	var cells: PackedByteArray = layout.cells_raw().duplicate()
	var terrain: PackedByteArray = layout.terrain_raw().duplicate()
	var protected: PackedByteArray = layout.protected_raw().duplicate()
	FloorPopulator._add_torches(layout, FloorData.new(), 0, floors, RandomNumberGenerator.new())
	results[GEOMETRY_CHECK] = cells == layout.cells_raw() and terrain == layout.terrain_raw() \
		and protected == layout.protected_raw() and layout.count_spawns(FloorLayout.SpawnKind.TORCH) > 0 \
		and layout.count_spawns(FloorLayout.SpawnKind.WALL_DECOR) > 0
	var visible_mounts_only: bool = true
	for spawn in layout.spawns:
		if spawn.kind == FloorLayout.SpawnKind.TORCH:
			visible_mounts_only = visible_mounts_only and spawn.wall_direction != Vector2i.UP
	results["wall torches never spawn on rear-facing walls"] = visible_mounts_only
	return results


static func placement_ok(layout: FloorLayout, data: FloorData) -> bool:
	var torches: Array[Vector2i] = []
	var decor: int = 0
	var lateral: bool = false
	var torch_chunks: Dictionary = {}
	var decor_chunks: Dictionary = {}
	var occupied: Dictionary = {}
	for spawn in layout.spawns:
		if spawn.slot == layout.hub_slot and spawn.art == "crystal":
			return false
		if spawn.kind not in [FloorLayout.SpawnKind.TORCH, FloorLayout.SpawnKind.WALL_DECOR]:
			continue
		var floor_cell: Vector2i = spawn.cell + spawn.wall_direction
		if spawn.wall_direction not in FloorPopulator.FEATURE_NEIGHBORS or occupied.has(spawn.cell) \
				or not layout.is_rock(spawn.cell.x, spawn.cell.y) or layout.is_protected(spawn.cell.x, spawn.cell.y) \
				or layout.slot_at(spawn.cell.x, spawn.cell.y) != spawn.slot \
				or not layout.is_floor(floor_cell.x, floor_cell.y) or layout.is_protected(floor_cell.x, floor_cell.y):
			return false
		occupied[spawn.cell] = true
		var chunk: Vector2i = layout.chunk_of(spawn.cell)
		if spawn.kind == FloorLayout.SpawnKind.TORCH:
			if spawn.wall_direction not in FloorPopulator.TORCH_MOUNT_DIRECTIONS:
				return false
			for other in torches:
				if Vector2(spawn.cell).distance_to(Vector2(other)) < maxi(data.torch_spacing, FloorPopulator.WALL_DECOR_SPACING):
					return false
			torches.append(spawn.cell)
			lateral = lateral or spawn.wall_direction.x != 0
			torch_chunks[chunk] = torch_chunks.get(chunk, 0) + 1
			if torch_chunks[chunk] > FloorPopulator.MAX_TORCHES_PER_CHUNK:
				return false
		else:
			if spawn.art not in WallArt.DECOR_KINDS or spawn.solid:
				return false
			if spawn.art in FloorPopulator.GOBLIN_WALL_DECOR:
				var near_hall: bool = false
				for feature in layout.features:
					near_hall = near_hall or (feature.slot == spawn.slot \
						and feature.kind in [&"goblin_camp", &"chieftain_hall"] \
						and Vector2(spawn.cell).distance_to(Vector2(feature.cell)) <= FloorPopulator.GOBLIN_WALL_DECOR_RADIUS)
				if not near_hall:
					return false
			decor += 1
			decor_chunks[chunk] = decor_chunks.get(chunk, 0) + 1
			if decor_chunks[chunk] > FloorPopulator.MAX_WALL_DECOR_PER_CHUNK:
				return false
	return not torches.is_empty() and decor > 0 and lateral


static func signature(layout: FloorLayout) -> int:
	var entries: Array = []
	for spawn in layout.spawns:
		if spawn.kind in [FloorLayout.SpawnKind.TORCH, FloorLayout.SpawnKind.WALL_DECOR]:
			entries.append([spawn.kind, spawn.cell, spawn.wall_direction, spawn.art])
	return hash(entries)


static func scene_ok(level: FloorLevel) -> bool:
	var torches: Array[Node] = level.get_tree().get_nodes_in_group("wall_torch")
	var decorations: Array[Node] = level.get_tree().get_nodes_in_group("wall_decoration")
	if torches.is_empty() or decorations.is_empty() or not _projecting_mounts_ok(level):
		return false
	for node in torches:
		var torch := node as WallTorch
		var before: Texture2D = torch._sprite.texture
		torch._process(1.0 / WallTorch.FLAME_FPS)
		if before == torch._sprite.texture or torch._light.position \
				!= torch._sprite.position + GameScale.world_vector(WallTorch.FLAME_LIGHT_OFFSET) \
				or absf(torch._light.energy - torch.base_energy) > torch.flicker_amount + 0.001:
			return false
	for node in decorations:
		if not node is WallDecoration or node.get_child_count() != 1 or not node.get_child(0) is Sprite2D:
			return false
	return true


## Instantiate the actual scene in all four orientations, including cases absent from the loaded chunks.
static func _projecting_mounts_ok(level: Node) -> bool:
	var scene := load("res://scenes/levels/wall_torch.tscn") as PackedScene
	var all_ok: bool = true
	var half: float = GameScale.TILE_SIZE / 2.0
	for direction in FloorPopulator.FEATURE_NEIGHBORS:
		var torch := scene.instantiate() as WallTorch
		torch.mount_direction = direction
		torch.visible = false
		level.add_child(torch)
		var bracket := torch.get_node_or_null("Bracket") as Sprite2D
		var shadow := torch.get_node_or_null("CastShadow") as Sprite2D
		all_ok = all_ok and bracket != null and shadow != null
		if bracket != null and shadow != null:
			all_ok = all_ok and bracket.texture == WallArt.bracket_texture(direction) \
				and torch.find_children("*", "CollisionObject2D", true, false).is_empty()
			if direction == Vector2i.DOWN:
				# Check actual opaque handle pixels, not just the sprite origin.
				for frame in WallArt.FLAME_FRAMES:
					var image: Image = WallArt.torch_texture(frame).get_image()
					var bottom: int = -1
					for y in image.get_height():
						for x in image.get_width():
							if image.get_pixel(x, y).a > 0.0:
								bottom = maxi(bottom, y)
					var handle_bottom: float = torch._sprite.position.y + GameScale.world(bottom + 1 - WallArt.SIZE.y / 2.0)
					all_ok = all_ok and bottom >= 0 and handle_bottom < half
				all_ok = all_ok and shadow.position.y + GameScale.world(WallArt.SHADOW_RADIUS.y) < half
			else:
				all_ok = all_ok and torch._sprite.position.dot(Vector2(direction)) > half \
					and torch._sprite.position.dot(Vector2(direction)) - half <= GameScale.world(MAX_TORCH_PROJECTION_GAP) \
					and shadow.position.dot(Vector2(direction)) > half
		torch.free()
	return all_ok
