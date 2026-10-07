@tool
class_name TownProp
extends Node2D
## One town decoration from TownArt.PROPS (barrel, fountain, cart, tree, lantern...). The node stands at the
## bottom center of the picture (where it touches the ground), so the y-sorted World layers it correctly.
## Solid props block movement with a small footprint; animated ones (fountain, forge) loop their frames;
## lanterns and the forge give light at night (TownLevel turns `lit` on).

const FRAME_TIME: float = 0.18
const LIGHT_COLOR: Color = Color(1.0, 0.72, 0.38)
const LIGHT_ENERGY: float = 0.95
const LIGHT_SCALE: float = 0.6

@export_enum("fountain", "well", "well_stone", "hand_cart", "hay_cart", "wheelbarrow", "wagon", "woodpile",
	"woodpile_small", "anvil", "trough", "hay_trough", "hay_bale", "bench", "bench_long", "table", "stool",
	"banner_white", "banner_blue", "banner_green", "banner_red", "banner_yellow", "banner_black", "laundry",
	"laundry_sheet", "scarecrow", "notice_board", "sign_post", "lantern", "lantern_cage", "pole", "grave", "statue",
	"tower", "stall_orange", "stall_green", "stall_grey", "barrel", "barrel_open", "barrels", "barrel_big", "bucket", "tub", "crate", "crate_small", "crates",
	"chest", "forge", "smith_anvil", "smith_rack", "smith_bench", "quench", "coal", "tree", "tree_pine", "bridge",
	"bush", "bush_round", "flowers_red", "flowers_blue", "flowers_yellow", "flowers_mix", "sunflower", "cabbage",
	"lettuce", "leafy", "herbs", "reeds", "grass_tuft") var prop: String = "barrel":
	set(value):
		prop = value
		_frame = 0
		queue_redraw()
@export var flip_h: bool = false:
	set(value):
		flip_h = value
		queue_redraw()
## Blocks movement with the footprint from TownArt (turn off for decorations you can walk over).
@export var solid: bool = true
## Lamp post: a pole with this lantern on top (only for "lantern" / "lantern_cage").
@export var on_pole: bool = false:
	set(value):
		on_pole = value
		queue_redraw()
## Night light (only props with a light point in TownArt).
@export var lit: bool = false:
	set(value):
		lit = value
		_update_light()
		queue_redraw()

var _frame: int = 0
var _time: float = 0.0
var _light: PointLight2D


func _ready() -> void:
	_time = randf() * FRAME_TIME * 4.0
	if Engine.is_editor_hint():
		return
	var info: Dictionary = _info()
	if info.has("light"):
		add_to_group(&"town_lights")
	var footprint: Vector2i = info.get("solid", Vector2i.ZERO)
	if solid and footprint != Vector2i.ZERO:
		var body := StaticBody2D.new()
		body.name = "Collision"
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(footprint)
		shape.shape = rect
		shape.position = Vector2(0, -footprint.y / 2.0)
		body.add_child(shape)
		add_child(body)
	_update_light()


func _process(delta: float) -> void:
	var frames: int = _info().get("frames", 1)
	if frames <= 1:
		return
	_time += delta
	var frame: int = int(_time / FRAME_TIME) % frames
	if frame != _frame:
		_frame = frame
		queue_redraw()


func _info() -> Dictionary:
	return TownArt.PROPS.get(prop, TownArt.PROPS["barrel"])


## Height of the picture in pixels (for things placed on top, like smoke).
func height() -> float:
	var info: Dictionary = _info()
	return (info["rect"] as Rect2i).size.y + (_pole_height() if on_pole else 0.0)


func _pole_height() -> float:
	return (TownArt.PROPS["pole"]["rect"] as Rect2i).size.y - 6.0


func _draw() -> void:
	var info: Dictionary = _info()
	var region := Rect2(info["rect"])
	region.position += Vector2(info.get("step", Vector2i.ZERO) * _frame)
	var texture: Texture2D = TownArt.sheet(info["sheet"])
	var lift: float = 0.0
	if on_pole:
		var pole: Rect2i = TownArt.PROPS["pole"]["rect"]
		draw_texture_rect_region(TownArt.sheet("deco"), Rect2(-pole.size.x / 2.0, -pole.size.y, pole.size.x, pole.size.y),
			Rect2(pole))
		lift = _pole_height()
	if info.has("trunk"):
		# Trees: trunk sheet under the crown.
		var trunk: Rect2i = info["trunk"]
		draw_texture_rect_region(TownArt.sheet("trunk"), Rect2(-trunk.size.x / 2.0, -trunk.size.y + 8.0, trunk.size.x,
			trunk.size.y), Rect2(trunk))
		lift = trunk.size.y - 26.0
	var size: Vector2 = region.size
	var rect := Rect2(-size.x / 2.0, -size.y - lift, size.x, size.y)
	if flip_h:
		rect.size.x = -rect.size.x
		rect.position.x = size.x / 2.0
	draw_texture_rect_region(texture, rect, region)
	if lit and info.has("light"):
		var glow: Vector2 = info["light"] - Vector2(0, lift)
		draw_circle(glow, 4.0, Color(1.0, 0.9, 0.5, 0.6))


func _update_light() -> void:
	if Engine.is_editor_hint() or not is_inside_tree():
		return
	var info: Dictionary = _info()
	if not info.has("light"):
		return
	if _light == null:
		_light = PointLight2D.new()
		_light.texture = TownLighting.light_texture()
		_light.color = LIGHT_COLOR
		_light.energy = LIGHT_ENERGY
		_light.texture_scale = LIGHT_SCALE
		_light.position = info["light"] - Vector2(0, _pole_height() if on_pole else 0.0)
		add_child(_light)
	_light.visible = lit
