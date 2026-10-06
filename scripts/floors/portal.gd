class_name Portal
extends Area2D
## Exit to the next floor. Stays dormant (grey) until the floor boss dies (stage 3).

signal entered

const DORMANT_COLOR: Color = Color(0.45, 0.45, 0.5, 0.8)
const ACTIVE_COLOR: Color = Color(0.75, 0.35, 1.0, 0.9)

@export var active: bool = false:
	set(value):
		active = value
		_refresh()

@onready var _visual: Polygon2D = $Visual
@onready var _light: PointLight2D = $Light


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_refresh()


func _process(_delta: float) -> void:
	if active:
		_visual.rotation += 0.02


func _refresh() -> void:
	if not is_node_ready():
		return
	_visual.color = ACTIVE_COLOR if active else DORMANT_COLOR
	_light.enabled = active


func _on_body_entered(body: Node2D) -> void:
	if active and body is Player:
		entered.emit()
