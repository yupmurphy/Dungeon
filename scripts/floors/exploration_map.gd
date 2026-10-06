class_name ExplorationMap
extends Node2D
## Fog of war + map data. Keeps which tiles the player has seen and draws two textures from it:
## - fog: black over unseen tiles (child Sprite2D, one pixel per tile, scaled up to tile size)
## - map_texture: explored tiles in region colors, used by the minimap and the big map (M).
## Tiles are revealed in a radius around the player, only where there is line of sight.

signal revealed

const REVEAL_RADIUS: int = 9
const WALL_MAP_COLOR: Color = Color(0.3, 0.28, 0.34)
const PORTAL_MAP_COLOR: Color = Color(0.8, 0.4, 1.0)

var layout: FloorLayout
var map_texture: ImageTexture
## [{name, color}] per region slot, for the big map legend.
var legend: Array[Dictionary] = []

var _explored: PackedByteArray
var _explored_floor: int = 0
var _fog_image: Image
var _map_image: Image
var _fog_texture: ImageTexture
var _slot_colors: Array[Color] = []
var _last_cell: Vector2i = Vector2i(-99999, -99999)
var _dirty: bool = false

@onready var _fog: Sprite2D = $Fog


func _ready() -> void:
	add_to_group("exploration")


func setup(new_layout: FloorLayout, slot_colors: Array[Color], new_legend: Array[Dictionary]) -> void:
	layout = new_layout
	_slot_colors = slot_colors
	legend = new_legend
	var w: int = layout.size.x
	var h: int = layout.size.y
	_explored.resize(w * h)
	_explored.fill(0)
	_explored_floor = 0
	_fog_image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	_fog_image.fill(Color.BLACK)
	_map_image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	_map_image.fill(Color.TRANSPARENT)
	_fog_texture = ImageTexture.create_from_image(_fog_image)
	map_texture = ImageTexture.create_from_image(_map_image)
	_fog.texture = _fog_texture
	_fog.centered = false
	_fog.scale = Vector2(TileAtlas.TILE_SIZE, TileAtlas.TILE_SIZE)
	_last_cell = Vector2i(-99999, -99999)


func world_to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i((world_position / TileAtlas.TILE_SIZE).floor())


## Call every frame with the player position; work happens only when the player changes tile.
func update_player(world_position: Vector2) -> void:
	if layout == null:
		return
	var cell: Vector2i = world_to_cell(world_position)
	if cell == _last_cell:
		return
	_last_cell = cell
	for dy in range(-REVEAL_RADIUS, REVEAL_RADIUS + 1):
		for dx in range(-REVEAL_RADIUS, REVEAL_RADIUS + 1):
			if dx * dx + dy * dy > REVEAL_RADIUS * REVEAL_RADIUS:
				continue
			var target: Vector2i = cell + Vector2i(dx, dy)
			if layout.in_bounds(target.x, target.y) and _has_line_of_sight(cell, target):
				_mark(target.x, target.y)
	_commit()


func reveal_all() -> void:
	for y in layout.size.y:
		for x in layout.size.x:
			if layout.is_rendered(x, y):
				_mark(x, y)
	_commit()


func is_explored(cell: Vector2i) -> bool:
	return layout.in_bounds(cell.x, cell.y) and _explored[cell.y * layout.size.x + cell.x] == 1


func explored_ratio() -> float:
	return float(_explored_floor) / maxf(layout.floor_cell_count(), 1.0)


## Bresenham walk; every cell strictly between a and b must be floor. The target itself may be a wall,
## so walls facing the player get revealed.
func _has_line_of_sight(a: Vector2i, b: Vector2i) -> bool:
	var dx: int = absi(b.x - a.x)
	var dy: int = -absi(b.y - a.y)
	var sx: int = 1 if a.x < b.x else -1
	var sy: int = 1 if a.y < b.y else -1
	var error: int = dx + dy
	var cell: Vector2i = a
	while cell != b:
		if cell != a and layout.is_wall(cell.x, cell.y):
			return false
		var doubled: int = 2 * error
		if doubled >= dy:
			error += dy
			cell.x += sx
		if doubled <= dx:
			error += dx
			cell.y += sy
	return true


func _mark(x: int, y: int) -> void:
	var index: int = y * layout.size.x + x
	if _explored[index] == 1:
		return
	_explored[index] = 1
	_dirty = true
	_fog_image.set_pixel(x, y, Color.TRANSPARENT)
	if layout.is_floor(x, y):
		_explored_floor += 1
		var color: Color = _slot_colors[layout.slot_at(x, y)]
		if Vector2i(x, y).distance_to(layout.portal_cell) <= 1.0:
			color = PORTAL_MAP_COLOR
		_map_image.set_pixel(x, y, color)
	elif layout.is_rendered(x, y):
		_map_image.set_pixel(x, y, WALL_MAP_COLOR)


func _commit() -> void:
	if not _dirty:
		return
	_dirty = false
	_fog_texture.update(_fog_image)
	map_texture.update(_map_image)
	revealed.emit()
