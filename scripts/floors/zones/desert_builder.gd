class_name DesertBuilder
extends ZoneBuilder
## The Underground Desert: sand shaped into dune ridges by one wind direction, big rock formations
## (mesas), giant bones of long-dead beasts, quicksand patches that slow you to a crawl, and one oasis
## with water, lush grass and palms.

const MESA_FREQUENCY: float = 0.009
const MESA: float = 0.77
const QUICKSAND_PATCHES: Vector2i = Vector2i(5, 8)
const QUICKSAND_RADIUS: Vector2 = Vector2(4.0, 9.0)
const DUNE_FREQUENCY: float = 0.01
## Dune ridges: one every this many tiles across the wind.
const DUNE_SPACING: float = 9.0
const DUNE_CREST: float = 0.8
const OASIS_RADIUS: Vector2 = Vector2(11.0, 15.0)
const OASIS_GRASS_BAND: float = 6.0
const BONE_SITES: Vector2i = Vector2i(6, 10)

var _mesas: PackedByteArray
var _quicksand: PackedByteArray
var _dune_bend: PackedByteArray
var _wind: Vector2
var _oasis: Vector2 = Vector2(-1000, -1000)
var _oasis_radius: float = 0.0


func plan() -> void:
	var w: int = layout.size.x
	var h: int = layout.size.y
	_mesas = FloorGenerator.noise_bytes(seed_value + 61, MESA_FREQUENCY, w, h)
	_dune_bend = FloorGenerator.noise_bytes(seed_value + 63, DUNE_FREQUENCY, w, h)
	_wind = Vector2.from_angle(rng.randf() * TAU)
	_plan_oasis()
	_plan_quicksand()


func paint(x: int, y: int, i: int) -> int:
	var oasis: float = Vector2(x + 0.5, y + 0.5).distance_to(_oasis)
	if oasis < _oasis_radius + OASIS_GRASS_BAND:
		if oasis < _oasis_radius * 0.5:
			return Terrain.Type.WATER_DEEP
		if oasis < _oasis_radius:
			return Terrain.Type.WATER_SHALLOW
		return Terrain.Type.OASIS_GRASS
	if _mesas[i] / 255.0 > MESA:
		return Terrain.Type.ROCK
	if _quicksand[i] == 1:
		return Terrain.Type.QUICKSAND
	# Dunes: parallel ridges across the wind, bent by noise.
	var across: float = Vector2(x, y).dot(_wind) / DUNE_SPACING + _dune_bend[i] / 255.0 * 6.0
	if sin(across * TAU) > DUNE_CREST:
		return Terrain.Type.DUNE
	return Terrain.Type.SAND


func ground() -> int:
	return Terrain.Type.SAND


func decorate(used: Dictionary) -> void:
	var floors: PackedInt32Array = floor_cells()
	_decorate_oasis(used)
	# Giant bones: a skull and ribs of the same beast lie together.
	var sites: int = rng.randi_range(BONE_SITES.x, BONE_SITES.y)
	var placed: Array[Vector2i] = []
	for attempt in sites * 20:
		if placed.size() >= sites:
			break
		var cell: Vector2i = random_zone_cell(func(c: Vector2i) -> bool:
			if layout.terrain_at(c.x, c.y) != Terrain.Type.SAND:
				return false
			for other in placed:
				if Vector2(other).distance_to(Vector2(c)) < 35.0:
					return false
			return true)
		if cell.x < 0:
			continue
		if place_prop("ribs", cell, used):
			place_prop("skull", cell + Vector2i(4 if rng.randf() < 0.5 else -3, rng.randi_range(-1, 2)), used)
			for k in 4:
				place_prop("bone", cell + Vector2i(rng.randi_range(-5, 7), rng.randi_range(-4, 5)), used)
			placed.append(cell)
			layout.add_feature(&"giant_bones", cell, slot)
	scatter(floors, [Terrain.Type.SAND, Terrain.Type.DUNE], [["cactus", 0.004], ["shrub", 0.008],
		["bone", 0.002], ["boulder", 0.002]], used)


func _plan_oasis() -> void:
	var outer_hub: float = hub_outer_radius(0.0)
	var arena_center: Vector2 = arena["center"]
	var good_spot: Callable = func(c: Vector2i) -> bool:
		var p: Vector2 = Vector2(c)
		var edge: int = mini(mini(c.x, c.y), mini(layout.size.x - 1 - c.x, layout.size.y - 1 - c.y))
		return edge > 45 and p.distance_to(center()) > outer_hub + 50.0 and p.distance_to(arena_center) > 70.0 \
			and distance_to_gates(c) > 40.0
	var cell: Vector2i = random_zone_cell(good_spot, 2000)
	if cell.x < 0:
		return
	_oasis = Vector2(cell) + Vector2(0.5, 0.5)
	_oasis_radius = rng.randf_range(OASIS_RADIUS.x, OASIS_RADIUS.y)
	layout.add_feature(&"oasis", cell, slot)


## Quicksand: a few blobs in the open desert, away from the oasis, the gates and each other.
func _plan_quicksand() -> void:
	_quicksand = PackedByteArray()
	_quicksand.resize(layout.size.x * layout.size.y)
	var patches: Array[Vector2i] = []
	var count: int = rng.randi_range(QUICKSAND_PATCHES.x, QUICKSAND_PATCHES.y)
	var good_spot: Callable = func(c: Vector2i) -> bool:
		var edge: int = mini(mini(c.x, c.y), mini(layout.size.x - 1 - c.x, layout.size.y - 1 - c.y))
		if edge < data.border_max + 10 or Vector2(c).distance_to(_oasis) < _oasis_radius + 25.0 \
				or distance_to_gates(c) < 30.0:
			return false
		for other in patches:
			if Vector2(other).distance_to(Vector2(c)) < 45.0:
				return false
		return true
	for k in count:
		var cell: Vector2i = random_zone_cell(good_spot)
		if cell.x < 0:
			continue
		patches.append(cell)
		var radius: float = rng.randf_range(QUICKSAND_RADIUS.x, QUICKSAND_RADIUS.y)
		var phase: float = rng.randf() * TAU
		var r: int = ceili(radius * 1.3)
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var p: Vector2i = cell + Vector2i(dx, dy)
				if not layout.in_bounds(p.x, p.y):
					continue
				var offset := Vector2(dx, dy)
				var edge: float = radius * (1.0 + 0.25 * sin(offset.angle() * 3.0 + phase))
				if offset.length() <= edge:
					_quicksand[p.y * layout.size.x + p.x] = 1
		layout.add_feature(&"quicksand", cell, slot)


func _decorate_oasis(used: Dictionary) -> void:
	if _oasis_radius <= 0.0:
		return
	var palms: int = rng.randi_range(8, 12)
	for k in palms:
		var angle: float = TAU * k / palms + rng.randf_range(-0.2, 0.2)
		var spot: Vector2 = _oasis + Vector2.from_angle(angle) * (_oasis_radius + rng.randf_range(1.5, OASIS_GRASS_BAND - 1.0))
		place_prop("palm", Vector2i(spot.floor()), used)
	for k in 6:
		var spot: Vector2 = _oasis + Vector2.from_angle(rng.randf() * TAU) * _oasis_radius * 0.8
		place_prop("lily", Vector2i(spot.floor()), used)
