class_name TownBuilding
extends Node2D
## One reusable exterior. Root is at the front foundation so characters sort behind the roof.
const LABEL_DISTANCE: float = 70.0
const LABEL_SIZE: Vector2 = Vector2(128, 16)
const LABEL_FONT_SIZE: int = 11
const DOOR_APPROACH_OFFSET: float = 8.0
var data: TownBuildingData
var door: TownDoor
var sign: Label

func _ready() -> void:
	add_to_group("town_building")
	var sprite := Sprite2D.new()
	sprite.name = "Facade"
	sprite.texture = TownArt.building_texture(data)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = GameScale.world_vector(Vector2.ONE)
	sprite.position = Vector2(0, -sprite.texture.get_height() * sprite.scale.y / 2.0)
	add_child(sprite)
	var body := StaticBody2D.new()
	body.name = "Footprint"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(data.footprint.size) * GameScale.TILE_SIZE
	shape.shape = rect
	shape.position.y = -rect.size.y / 2.0
	body.add_child(shape)
	add_child(body)
	door = TownDoor.new()
	door.name = "Door"
	door.data = data
	door.position = Vector2((floori(data.footprint.size.x / 2.0) + 0.5 - data.footprint.size.x / 2.0) * GameScale.TILE_SIZE,
		GameScale.world(DOOR_APPROACH_OFFSET))
	add_child(door)
	var marker := Marker2D.new()
	marker.name = "ExteriorReturn"
	marker.position = door.position
	add_child(marker)
	sign = Label.new()
	sign.name = "NameLabel"
	sign.position = Vector2(-LABEL_SIZE.x / 2.0, GameScale.world(10))
	sign.size = LABEL_SIZE
	sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sign.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	sign.add_theme_color_override("font_color", Color("f3e4bb"))
	sign.add_theme_color_override("font_outline_color", Color("292b2e"))
	sign.add_theme_constant_override("outline_size", 3)
	sign.text = tr(data.name_key)
	if data.kind == &"house":
		sign.text = tr(&"TOWN_HOUSE_NUMBER").format({"number": String(data.id).trim_prefix("house_")})
	sign.z_index = 2
	add_child(sign)

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	sign.visible = player != null and player.global_position.distance_to(door.global_position) < GameScale.world(LABEL_DISTANCE)
