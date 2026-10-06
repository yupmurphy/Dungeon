class_name StatBar
extends Control
## Simple filled bar built from two rectangles. Size it with the Control's offsets.

@export var fill_color: Color = Color(0.85, 0.15, 0.15)
@export var back_color: Color = Color(0.05, 0.05, 0.05, 0.85)

var _ratio: float = 1.0

@onready var _back: ColorRect = $Back
@onready var _fill: ColorRect = $Fill


func _ready() -> void:
	_back.color = back_color
	_fill.color = fill_color
	_fill.position = Vector2(1.0, 1.0)
	resized.connect(_refresh)
	_refresh()


func set_ratio(value: float) -> void:
	_ratio = clampf(value, 0.0, 1.0)
	_refresh()


func _refresh() -> void:
	_fill.size = Vector2(maxf(size.x - 2.0, 0.0) * _ratio, maxf(size.y - 2.0, 0.0))
