class_name FloorShape
extends RefCounted
## The outline of a floor: a long organic capsule stretched from one corner of the map to the opposite one
## (which diagonal is random). Slow noise bends and swells it, fast noise roughens its edge, and a wavy border
## along the map's edge keeps it from ever touching the map's sides in a straight line. Its width is chosen so the
## land covers a random share of the map (FloorData.shape_coverage). Cells outside are impassable border.
## Pure data, seeded: same seed => same shape.

## Frequencies of the noises (bends, edge bumps, border along the map's edge).
const WARP_FREQUENCY: float = 0.004
const ROUGH_FREQUENCY: float = 0.03
const EDGE_FREQUENCY: float = 0.007

## 1 = land, 0 = border; one byte per cell.
var inside: PackedByteArray
## The two ends of the capsule (cells near opposite corners): the start and the far end of the floor.
var tips: Array[Vector2i] = []
## Share of the map the land covers, and the share that was aimed at.
var coverage: float = 0.0
var target_coverage: float = 0.0


static func build(data: FloorData, size: Vector2i, seed_value: int, rng: RandomNumberGenerator) -> FloorShape:
	var shape := FloorShape.new()
	var w: int = size.x
	var h: int = size.y
	shape.target_coverage = rng.randf_range(data.shape_coverage.x, data.shape_coverage.y)
	var corners: Array[Vector2] = [Vector2(0, 0), Vector2(w, h)]
	if rng.randf() < 0.5:
		corners = [Vector2(w, 0), Vector2(0, h)]
	var tip_a: Vector2 = corners[0].lerp(corners[1], data.shape_tip_inset)
	var tip_b: Vector2 = corners[1].lerp(corners[0], data.shape_tip_inset)
	shape.tips = [Vector2i(tip_a.floor()), Vector2i(tip_b.floor())]
	var axis: Vector2 = tip_b - tip_a
	var axis_length_squared: float = axis.length_squared()

	# The slow parts (bends, bays) on a half-size grid; the small bumps per cell.
	var w2: int = ceili(w / 2.0)
	var h2: int = ceili(h / 2.0)
	var warp_x: PackedByteArray = FloorGenerator.noise_bytes(seed_value + 21, WARP_FREQUENCY * 2.0, w2, h2)
	var warp_y: PackedByteArray = FloorGenerator.noise_bytes(seed_value + 22, WARP_FREQUENCY * 2.0, w2, h2)
	var edge: PackedByteArray = FloorGenerator.noise_bytes(seed_value + 24, EDGE_FREQUENCY * 2.0, w2, h2)
	var rough: PackedByteArray = FloorGenerator.noise_bytes(seed_value + 23, ROUGH_FREQUENCY, w, h)
	var warp_scale: float = data.shape_warp * 2.0 / 255.0
	var rough_scale: float = data.shape_roughness * 2.0 / 255.0
	var edge_min: float = data.shape_edge_depth.x
	var edge_range: float = data.shape_edge_depth.y - data.shape_edge_depth.x
	var edge_bumps: float = data.shape_roughness / 255.0

	# Per half-size cell: how far it is from the (bent) capsule's middle line, and how deep the border along the
	# map's edge is there (cubed slow noise: mostly thin, with a few big bays).
	var distance := PackedFloat32Array()
	distance.resize(w2 * h2)
	var depth := PackedFloat32Array()
	depth.resize(w2 * h2)
	var samples := PackedFloat32Array()
	for y2 in h2:
		for x2 in w2:
			var j: int = y2 * w2 + x2
			var e: float = edge[j] / 255.0
			depth[j] = edge_min + e * e * e * edge_range
			var p := Vector2(x2 * 2 + 1 + (warp_x[j] - 127.5) * warp_scale, y2 * 2 + 1 + (warp_y[j] - 127.5) * warp_scale)
			var t: float = clampf((p - tip_a).dot(axis) / axis_length_squared, 0.0, 1.0)
			distance[j] = p.distance_to(tip_a + axis * t)
			# One sample per half-size cell, at its top-left cell, with that cell's bumps.
			var x: int = x2 * 2
			var y: int = y2 * 2
			var i: int = y * w + x
			if mini(mini(x, y), mini(w - 1 - x, h - 1 - y)) >= depth[j] + rough[i] * edge_bumps:
				samples.append(distance[j] + (rough[i] - 127.5) * rough_scale)

	# The width that lets the target share of the map in.
	samples.sort()
	var wanted: int = int(shape.target_coverage * w2 * h2)
	var width: float = INF if wanted >= samples.size() else samples[wanted]
	shape.inside.resize(w * h)
	var count: int = 0
	for y in h:
		var row2: int = (y >> 1) * w2
		var edge_y: int = mini(y, h - 1 - y)
		for x in w:
			var i: int = y * w + x
			var j: int = row2 + (x >> 1)
			var land: bool = mini(edge_y, mini(x, w - 1 - x)) >= depth[j] + rough[i] * edge_bumps \
				and distance[j] + (rough[i] - 127.5) * rough_scale <= width
			if land:
				shape.inside[i] = 1
				count += 1
	shape.coverage = float(count) / (w * h)
	return shape


func is_inside(size: Vector2i, cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y and inside[cell.y * size.x + cell.x] == 1
