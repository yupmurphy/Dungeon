class_name CharacterSheet
extends Control
## Character page (key C, pauses the game): level + XP bar on top, main stats on the left (with debug
## -, +, +10 buttons), derived values on the right. Hovering a line shows what it does / where it comes from.
## Words come from localization/texts.csv, numbers from Stats (see StatTexts).

const FONT_SIZE: int = 9
const SMALL_FONT_SIZE: int = 8
const DIM: Color = Color(0.0, 0.0, 0.0, 0.55)
const PANEL_COLOR: Color = Color(0.08, 0.07, 0.1, 0.97)
const BORDER_COLOR: Color = Color(0.55, 0.45, 0.3)
const TITLE_COLOR: Color = Color(1.0, 0.85, 0.45)
const TEXT_COLOR: Color = Color(0.9, 0.88, 0.82)
const VALUE_COLOR: Color = Color(1.0, 1.0, 1.0)
const HINT_COLOR: Color = Color(0.6, 0.58, 0.55)
const HOVER_COLOR: Color = Color(1.0, 1.0, 1.0, 0.08)
const BUTTON_COLOR: Color = Color(0.22, 0.2, 0.25)
const XP_COLOR: Color = Color(0.45, 0.7, 1.0)

# Layout, in base pixels (the game is 480 x 270).
const PANEL_RECT: Rect2 = Rect2(16, 10, 448, 250)
const LEFT_X: float = 28.0
const RIGHT_X: float = 238.0
const RIGHT_WIDTH: float = 214.0
const COLUMN_TITLE_Y: float = 42.0
const STATS_Y: float = 60.0
const STAT_ROW_HEIGHT: float = 20.0
const DERIVED_Y: float = 58.0
const DERIVED_ROW_HEIGHT: float = 12.0
const TOOLTIP_WIDTH: float = 190.0
## Debug buttons next to each stat: label and amount.
const STAT_BUTTONS: Array[Array] = [["-", -1], ["+", 1], ["+10", 10]]

var player: Player
## Tools/tests: pretend the mouse is here (x < 0 = use the real mouse).
var forced_mouse: Vector2 = Vector2(-1, -1)

var _stat_values: Array[Label] = []
## Debug buttons by Vector2i(stat, amount), and the +XP button (tests press them).
var _stat_buttons: Dictionary = {}
var _xp_button: Button
var _stat_rows: Array[Rect2] = []
var _derived_names: Array[Label] = []
var _derived_values: Array[Label] = []
var _derived_rows: Array[Rect2] = []
var _derived_tooltips: Array[String] = []
var _level_label: Label
var _xp_label: Label
var _xp_bar: StatBar
var _hover: ColorRect
var _tooltip: PanelContainer
var _tooltip_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("character_sheet") or (visible and event.is_action_pressed("ui_cancel")):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	if player == null or visible:
		return
	if not player.stats.changed.is_connected(refresh):
		player.stats.changed.connect(refresh)
		player.progression.changed.connect(refresh)
	refresh()
	show()
	get_tree().paused = true


func close() -> void:
	if not visible:
		return
	hide()
	_tooltip.hide()
	get_tree().paused = false


func refresh() -> void:
	if player == null:
		return
	var stats: Stats = player.stats
	for stat in Stats.Stat.values():
		_stat_values[stat].text = str(stats.get_stat(stat))
	var lines: Array[StatTexts.Derived] = StatTexts.derived(stats)
	for i in lines.size():
		_derived_names[i].text = lines[i].name
		_derived_values[i].text = lines[i].value
		_derived_tooltips[i] = lines[i].tooltip
	var progression: Progression = player.progression
	_level_label.text = tr(&"SHEET_LEVEL").format({"level": progression.level})
	_xp_label.text = tr(&"SHEET_XP").format({"xp": progression.xp, "needed": progression.xp_needed()})
	_xp_bar.set_ratio(float(progression.xp) / progression.xp_needed())


func _process(_delta: float) -> void:
	if not visible:
		return
	var mouse: Vector2 = forced_mouse if forced_mouse.x >= 0.0 else get_local_mouse_position()
	var text: String = ""
	var row: Rect2 = Rect2()
	for stat in _stat_rows.size():
		if _stat_rows[stat].has_point(mouse):
			text = StatTexts.stat_tooltip(player.stats, stat)
			row = _stat_rows[stat]
	for i in _derived_rows.size():
		if _derived_rows[i].has_point(mouse):
			text = _derived_tooltips[i]
			row = _derived_rows[i]
	_hover.visible = text != ""
	_hover.position = row.position
	_hover.size = row.size
	_show_tooltip(text, row)


## The tooltip opens beside the hovered row, over the other column, so it never hides what it explains.
func _show_tooltip(text: String, row: Rect2) -> void:
	_tooltip.visible = text != ""
	if text == "":
		return
	_tooltip_label.text = text
	_tooltip.reset_size()
	var at := Vector2(RIGHT_X, row.position.y)
	if row.position.x >= RIGHT_X - 4.0:
		at.x = RIGHT_X - _tooltip.size.x - 8.0
	at.y = clampf(at.y, 4.0, size.y - 4.0 - _tooltip.size.y)
	_tooltip.position = at


# --- Building the page ---

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var panel := Panel.new()
	panel.position = PANEL_RECT.position
	panel.size = PANEL_RECT.size
	panel.add_theme_stylebox_override("panel", _box(PANEL_COLOR, BORDER_COLOR))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	_hover = ColorRect.new()
	_hover.color = HOVER_COLOR
	_hover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hover)

	# Top: title, level, XP bar, debug XP button.
	_label(tr(&"SHEET_TITLE"), Vector2(LEFT_X, 16), FONT_SIZE + 2, TITLE_COLOR)
	_level_label = _label("", Vector2(150, 17), FONT_SIZE, VALUE_COLOR)
	_xp_bar = preload("res://scenes/ui/stat_bar.tscn").instantiate()
	_xp_bar.fill_color = XP_COLOR
	_xp_bar.back_color = BUTTON_COLOR
	add_child(_xp_bar)
	_xp_bar.position = Vector2(205, 21)
	_xp_bar.size = Vector2(140, 6)
	_xp_label = _label("", Vector2(350, 17), SMALL_FONT_SIZE, TEXT_COLOR)
	var xp_button: Button = _button(tr(&"SHEET_DEBUG_XP").format({"amount": Progression.DEBUG_XP}),
		Vector2(404, 16), Vector2(48, 13))
	xp_button.pressed.connect(func() -> void: player.progression.add_xp(Progression.DEBUG_XP))
	_xp_button = xp_button
	var line := ColorRect.new()
	line.color = BORDER_COLOR.darkened(0.3)
	line.position = Vector2(LEFT_X, 34)
	line.size = Vector2(PANEL_RECT.size.x - 2.0 * (LEFT_X - PANEL_RECT.position.x), 1)
	add_child(line)

	# Left: main stats with debug buttons.
	_label(tr(&"SHEET_STATS"), Vector2(LEFT_X, COLUMN_TITLE_Y), FONT_SIZE + 1, TITLE_COLOR)
	_label("debug", Vector2(LEFT_X + 112, COLUMN_TITLE_Y + 2), SMALL_FONT_SIZE, HINT_COLOR)
	for stat in Stats.Stat.values():
		var y: float = STATS_Y + stat * STAT_ROW_HEIGHT
		_label(StatTexts.stat_name(stat), Vector2(LEFT_X + 2, y), FONT_SIZE, TEXT_COLOR)
		var value: Label = _label("", Vector2(LEFT_X + 70, y), FONT_SIZE, VALUE_COLOR)
		value.size.x = 28
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_stat_values.append(value)
		var x: float = LEFT_X + 106
		for spec in STAT_BUTTONS:
			var width: float = 24.0 if str(spec[0]).length() > 1 else 16.0
			var button: Button = _button(spec[0], Vector2(x, y), Vector2(width, 13))
			button.pressed.connect(player_add_stat.bind(stat, spec[1]))
			_stat_buttons[Vector2i(stat, spec[1])] = button
			x += width + 3.0
		_stat_rows.append(Rect2(LEFT_X - 2, y - 2, 180, STAT_ROW_HEIGHT - 2))

	# Right: derived values.
	_label(tr(&"SHEET_DETAILS"), Vector2(RIGHT_X, COLUMN_TITLE_Y), FONT_SIZE + 1, TITLE_COLOR)
	for i in StatTexts.derived(Stats.new()).size():
		var y: float = DERIVED_Y + i * DERIVED_ROW_HEIGHT
		_derived_names.append(_label("", Vector2(RIGHT_X + 2, y), FONT_SIZE, TEXT_COLOR))
		var value: Label = _label("", Vector2(RIGHT_X, y), FONT_SIZE, VALUE_COLOR)
		value.size.x = RIGHT_WIDTH - 4.0
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_derived_values.append(value)
		_derived_tooltips.append("")
		_derived_rows.append(Rect2(RIGHT_X - 2, y, RIGHT_WIDTH, DERIVED_ROW_HEIGHT))

	_label(tr(&"SHEET_HINT"), Vector2(LEFT_X, PANEL_RECT.end.y - 16), SMALL_FONT_SIZE, HINT_COLOR)

	_tooltip = PanelContainer.new()
	var tooltip_box: StyleBoxFlat = _box(Color(0.03, 0.03, 0.05, 0.97), TITLE_COLOR.darkened(0.2))
	tooltip_box.set_content_margin_all(5)
	_tooltip.add_theme_stylebox_override("panel", tooltip_box)
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_label = Label.new()
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_label.custom_minimum_size.x = TOOLTIP_WIDTH
	_tooltip_label.add_theme_font_size_override("font_size", SMALL_FONT_SIZE)
	_tooltip_label.add_theme_color_override("font_color", TEXT_COLOR)
	_tooltip.add_child(_tooltip_label)
	add_child(_tooltip)
	_tooltip.hide()


## Debug: change a main stat right away (derived values and the HUD follow).
func player_add_stat(stat: Stats.Stat, amount: int) -> void:
	if player != null:
		player.stats.add_stat(stat, amount)


func _label(text: String, at: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _button(text: String, at: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = at
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", SMALL_FONT_SIZE)
	# Every state needs our flat box: the default theme's boxes have margins that make the button tall.
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var color: Color = BUTTON_COLOR
		if state == "hover":
			color = BUTTON_COLOR.lightened(0.25)
		elif state.contains("pressed"):
			color = BUTTON_COLOR.darkened(0.3)
		var box: StyleBoxFlat = _box(color, BORDER_COLOR.darkened(0.2))
		box.set_content_margin_all(0)
		button.add_theme_stylebox_override(state, box)
		button.add_theme_stylebox_override(state + "_mirrored", box)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	add_child(button)
	button.size = button_size
	return button


## Flat box with a 1 px border and square corners (pixel art look).
func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	return box
