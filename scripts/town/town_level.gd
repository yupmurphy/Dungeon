class_name TownLevel
extends Node2D
## Exterior-only stage: a fixed, peaceful hub. Dungeon remains the default main scene.
const DECORATION_SCENE: String = "res://scenes/town/decoration.tscn"
const LEDGE_KINDS: Array[int] = [TownLayout.Ground.LEDGE_FRONT, TownLayout.Ground.LEDGE_SIDE, TownLayout.Ground.LEDGE_BACK]
const BUILDING_SCENE: String = "res://scenes/town/building.tscn"
const INTERACT_KEY: int = KEY_E
const MAP_ZOOM: Vector2 = Vector2(0.105, 0.105)
const NORMAL_ZOOM: Vector2 = Vector2.ONE
const PLOT_LABEL_SIZE: Vector2 = Vector2(200, 30)
const PLOT_FONT_SIZE: int = 11
const BORDER_THICKNESS: int = 2
const SETUP_BUDGET_MS: int = 2500
var data: TownData = TownData.new()
var layout: TownLayout
var setup_ms: int = 0
var map_open: bool = false
@onready var player: Player = $World/Player
@onready var world: Node2D = $World
@onready var ground: TileMapLayer = $Ground
@onready var hint: Label = $TownUI/Hint

func _ready() -> void:
	var began: int = Time.get_ticks_msec()
	# Leaving a dungeon must not keep its slowing terrain active in town.
	FloorLayout.active = null
	layout = TownLayout.new(data)
	_setup_input()
	_build_ground()
	_build_stairs()
	_build_exteriors()
	_build_market()
	_build_plots()
	_build_decorations()
	_build_bounds()
	_build_road_sign()
	player.position = (Vector2(TownData.START_CELL) + Vector2.ONE / 2.0) * GameScale.TILE_SIZE
	(player.get_node("Torch") as PointLight2D).visible = false
	var camera := player.get_node("Camera2D") as Camera2D
	camera.set_room_limits(Rect2i(Vector2i.ZERO, TownData.MAP_SIZE * GameScale.TILE_SIZE))
	camera.reset_smoothing()
	$TownUI/Title.text = tr(&"TOWN_TITLE")
	$TownUI/Controls.text = tr(&"TOWN_CONTROLS")
	setup_ms = Time.get_ticks_msec() - began
	print("Town exterior: %d buildings, %d reserved plots, %d market stalls, setup %d ms" % [data.buildings.size(), TownData.RESERVED_PLOTS.size(), TownData.STALL_CELLS.size(), setup_ms])

func _setup_input() -> void:
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
	if InputMap.action_get_events("interact").is_empty():
		var key := InputEventKey.new()
		key.physical_keycode = INTERACT_KEY
		InputMap.action_add_event("interact", key)

func _build_ground() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(GameScale.TILE_SIZE, GameScale.TILE_SIZE)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)
	var atlas := TileSetAtlasSource.new()
	var image: Image = TownArt.ground_atlas()
	image.resize(image.get_width() * GameScale.TILE_SIZE / TownArt.TILE,
		image.get_height() * GameScale.TILE_SIZE / TownArt.TILE, Image.INTERPOLATE_NEAREST)
	atlas.texture = ImageTexture.create_from_image(image)
	atlas.texture_region_size = tile_set.tile_size
	# Attach first: new TileData then inherits this TileSet physics layer.
	tile_set.add_source(atlas, 0)
	for kind in TownArt.GROUND_COLORS.size():
		for v in TownArt.ATLAS_VARIANTS:
			var coords := Vector2i(v, kind)
			atlas.create_tile(coords)
			if kind in LEDGE_KINDS:
				var tile_data: TileData = atlas.get_tile_data(coords, 0)
				var half: float = GameScale.TILE_SIZE / 2.0
				tile_data.set_collision_polygons_count(0, 1)
				tile_data.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)]))
	ground.tile_set = tile_set
	for y in TownData.MAP_SIZE.y:
		for x in TownData.MAP_SIZE.x:
			var cell := Vector2i(x, y)
			var variant: int = posmod(x * TownArt.GROUND_HASH_X + y * TownArt.GROUND_HASH_Y, TownArt.ATLAS_VARIANTS)
			ground.set_cell(cell, 0, Vector2i(variant, layout.ground(cell)))


func _build_stairs() -> void:
	var sprite := Sprite2D.new()
	sprite.name = "StairFlight"
	sprite.texture = TownArt.stair_texture()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	sprite.scale = GameScale.world_vector(Vector2.ONE)
	sprite.position = Vector2(TownData.STAIRS.position - Vector2i(TownData.STAIR_BORDER_TILES, 0)) * GameScale.TILE_SIZE
	ground.add_child(sprite)


func _build_exteriors() -> void:
	var scene := load(BUILDING_SCENE) as PackedScene
	for item in data.buildings:
		var building := scene.instantiate() as TownBuilding
		building.name = String(item.id)
		building.data = item
		building.position = Vector2(item.footprint.position.x + item.footprint.size.x / 2.0, item.footprint.end.y) * GameScale.TILE_SIZE
		world.add_child(building)
		var shadow := Sprite2D.new()
		shadow.texture = TownArt.building_shadow(item)
		shadow.scale = GameScale.world_vector(Vector2.ONE)
		shadow.position = building.position + Vector2(GameScale.world(TownArt.SHADOW_OFFSET.x), -shadow.texture.get_height() * shadow.scale.y / 2.0 + GameScale.world(TownArt.SHADOW_OFFSET.y * 2))
		ground.add_child(shadow)

func _build_market() -> void:
	for index in TownData.STALL_CELLS.size():
		var cell: Vector2i = TownData.STALL_CELLS[index]
		var node := Node2D.new()
		node.name = "MarketStall%d" % (index + 1)
		node.position = Vector2(cell.x + TownData.STALL_SIZE.x / 2.0, cell.y + TownData.STALL_SIZE.y) * GameScale.TILE_SIZE
		world.add_child(node)
		node.add_to_group("town_stall")
		var sprite := Sprite2D.new()
		sprite.texture = TownArt.stall_texture(index)
		sprite.scale = GameScale.world_vector(Vector2.ONE)
		sprite.position.y = -sprite.texture.get_height() * sprite.scale.y / 2.0
		node.add_child(sprite)
		_collision(node, Vector2(TownData.STALL_SIZE) * GameScale.TILE_SIZE,
			Vector2(0, -TownData.STALL_SIZE.y * GameScale.TILE_SIZE / 2.0))

func _build_plots() -> void:
	for index in TownData.RESERVED_PLOTS.size():
		var plot: Rect2i = TownData.RESERVED_PLOTS[index]
		var label := Label.new()
		label.name = "ReservedPlot%d" % (index + 1)
		label.position = Vector2(plot.get_center()) * GameScale.TILE_SIZE - PLOT_LABEL_SIZE / 2.0
		label.size = PLOT_LABEL_SIZE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", PLOT_FONT_SIZE)
		label.add_theme_color_override("font_color", Color("e4dcc0"))
		label.add_theme_color_override("font_outline_color", Color("47543a"))
		label.add_theme_constant_override("outline_size", 2)
		label.text = tr(&"TOWN_RESERVED").format({"number": index + 1})
		$PlotLabels.add_child(label)

func _build_decorations() -> void:
	var scene := load(DECORATION_SCENE) as PackedScene
	for item in layout.props:
		var prop := scene.instantiate() as TownDecoration
		prop.name = String(item.id)
		prop.data = item
		prop.position = Vector2(item.footprint.position.x + item.footprint.size.x / 2.0, item.footprint.end.y) * GameScale.TILE_SIZE
		world.add_child(prop)


func _build_bounds() -> void:
	var size: Vector2 = Vector2(TownData.MAP_SIZE) * GameScale.TILE_SIZE
	var edge: float = BORDER_THICKNESS * GameScale.TILE_SIZE
	for rect in [Rect2(Vector2.ZERO, Vector2(size.x, edge)), Rect2(Vector2(0, size.y - edge), Vector2(size.x, edge)),
		Rect2(Vector2.ZERO, Vector2(edge, size.y)), Rect2(Vector2(size.x - edge, 0), Vector2(edge, size.y))]:
		_collision(self, rect.size, rect.get_center())

func _collision(parent: Node, size: Vector2, at: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = at
	body.add_child(shape)
	parent.add_child(body)

func _process(_delta: float) -> void:
	var cell := Vector2i((player.position / GameScale.TILE_SIZE).floor())
	player.set_meta("town_elevation", layout.elevation(cell))
	var door: TownDoor = nearby_door()
	if door == null:
		hint.text = ""
	else:
		hint.text = tr(&"TOWN_DOOR_HINT").format({"name": tr(door.data.name_key)})

func nearby_door() -> TownDoor:
	for node in get_tree().get_nodes_in_group("town_door"):
		var door := node as TownDoor
		if door.nearby_player == player:
			return door
	return null

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed("map"):
		map_open = not map_open
		var camera := player.get_node("Camera2D") as Camera2D
		camera.zoom = MAP_ZOOM if map_open else NORMAL_ZOOM
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		var door: TownDoor = nearby_door()
		if door != null:
			hint.text = tr(&"TOWN_INTERIOR_PENDING")
			# Interior stage will connect this doorway to a transition owner, never reload player here.
			get_viewport().set_input_as_handled()


func _build_road_sign() -> void:
	var label := Label.new()
	label.position = Vector2(TownData.GATE_CELL) * GameScale.TILE_SIZE - PLOT_LABEL_SIZE / 2.0
	label.size = PLOT_LABEL_SIZE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", PLOT_FONT_SIZE)
	label.add_theme_color_override("font_color", Color("eee0b7"))
	label.add_theme_color_override("font_outline_color", Color("35422f"))
	label.add_theme_constant_override("outline_size", 3)
	label.text = tr(&"TOWN_DUNGEON_ROAD")
	$PlotLabels.add_child(label)
