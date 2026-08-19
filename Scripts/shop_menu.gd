class_name ShopMenu
extends Control

## Tiny found-store panel. Opening freezes the world like the B catalog.

static var is_open := false
static var block_shoot := false

const FONT_BODY_PATH := "res://Assets/fonts/kenpixel_mini.ttf"
const FONT_TITLE_PATH := "res://Assets/fonts/kenpixel_mini_square.ttf"
const PANEL_W := 280.0
const PANEL_H := 196.0

const COL_PANEL := Color(0.12, 0.09, 0.08, 0.96)
const COL_PANEL_EDGE := Color(0.55, 0.32, 0.22, 0.95)
const COL_TEAL := Color(0.28, 0.55, 0.58, 1.0)
const COL_TEXT := Color(0.86, 0.78, 0.68, 1.0)
const COL_MUTED := Color(0.62, 0.55, 0.48, 1.0)
const COL_STAT := Color(0.55, 0.78, 0.76, 1.0)
const COL_DEAD := Color(0.42, 0.34, 0.30, 1.0)

var _font_body: Font
var _font_title: Font
var _row_rects: Array[Rect2] = []
var _hovered := -1


func _ready() -> void:
	add_to_group("shop_menu")
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	texture_filter = TEXTURE_FILTER_NEAREST
	_font_body = load(FONT_BODY_PATH)
	_font_title = load(FONT_TITLE_PATH)
	set_process(true)
	visible = true
	queue_redraw()


static func open_shop() -> void:
	for node in Engine.get_main_loop().root.find_children("*", "ShopMenu", true, false):
		(node as ShopMenu)._set_open(true)
		return


static func close_menu() -> void:
	for node in Engine.get_main_loop().root.find_children("*", "ShopMenu", true, false):
		(node as ShopMenu)._set_open(false)
		return


func _should_block() -> bool:
	if PauseMenu.is_open:
		return true
	return _game_over_visible()


func _game_over_visible() -> bool:
	for node in get_tree().get_nodes_in_group("game_over"):
		if node is CanvasItem and (node as CanvasItem).visible:
			return true
	return false


func _set_open(open: bool) -> void:
	if open and _should_block():
		return
	is_open = open
	mouse_filter = Control.MOUSE_FILTER_STOP if open else Control.MOUSE_FILTER_IGNORE
	_hovered = -1
	if open:
		if BuildMenu.is_open:
			BuildMenu.close_menu()
		if BuildPlacer.is_placing:
			for node in get_tree().get_nodes_in_group("build_placer"):
				if node.has_method("cancel_from_menu"):
					node.cancel_from_menu()
					break
		get_tree().paused = true
	else:
		block_shoot = true
		if not PauseMenu.is_open and not _game_over_visible() and not BuildMenu.is_open:
			get_tree().paused = false
	queue_redraw()


func _input(event: InputEvent) -> void:
	if _should_block():
		return
	if not is_open:
		return
	# Esc / E / B close the shop. B must not also open the build wheel.
	if event.is_action_pressed("pause") and not event.is_echo():
		_set_open(false)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact") and not event.is_echo():
		_set_open(false)
		get_viewport().set_input_as_handled()
		return
	if InputBindings.is_build_toggle_event(event):
		_set_open(false)
		get_viewport().set_input_as_handled()
		return


func _gui_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		block_shoot = true
		accept_event()
		_on_click()


func _process(_delta: float) -> void:
	if not is_open:
		return
	if not PauseMenu.is_open and not _game_over_visible():
		get_tree().paused = true
	_update_hover()


func _update_hover() -> void:
	var old := _hovered
	_hovered = -1
	var local := get_local_mouse_position()
	for i in _row_rects.size():
		if _row_rects[i].has_point(local):
			_hovered = i
			break
	if _hovered != old:
		queue_redraw()


func _on_click() -> void:
	_update_hover()
	if _hovered < 0:
		# Click outside the panel closes.
		var panel := _panel_rect()
		if not panel.has_point(get_local_mouse_position()):
			_set_open(false)
		return
	var stock := ShopCatalog.stock()
	if _hovered >= stock.size():
		return
	_try_buy(stock[_hovered])


func _try_buy(entry: Dictionary) -> void:
	var item_id: StringName = entry.get("id", &"")
	var cost := int(entry.get("cost", 0))
	var kind: StringName = entry.get("kind", &"")
	if not _can_buy(entry):
		queue_redraw()
		return
	if not GameResources.spend_water(cost):
		queue_redraw()
		return
	match kind:
		&"gun":
			GameResources.own_gun(item_id)
		&"grenade":
			GameResources.add_grenade(1)
		_:
			GameResources.add_water(cost)
	queue_redraw()


func _can_buy(entry: Dictionary) -> bool:
	var cost := int(entry.get("cost", 0))
	if GameResources.water < cost:
		return false
	var kind: StringName = entry.get("kind", &"")
	var item_id: StringName = entry.get("id", &"")
	match kind:
		&"gun":
			return not GameResources.owns_gun(item_id)
		&"grenade":
			return GameResources.grenades < GameResources.GRENADE_MAX
		_:
			return false


func _panel_rect() -> Rect2:
	var origin := (size - Vector2(PANEL_W, PANEL_H)) * 0.5
	return Rect2(origin, Vector2(PANEL_W, PANEL_H))


func _draw() -> void:
	if not is_open:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.04, 0.03, 0.52))
	var panel := _panel_rect()
	draw_rect(panel, COL_PANEL)
	draw_rect(panel, COL_PANEL_EDGE, false, 2.0)
	draw_rect(Rect2(panel.position + Vector2(2, 2), Vector2(panel.size.x - 4, 2)), COL_TEAL * Color(1, 1, 1, 0.55))

	var title_font := _font_title if _font_title else _font_body
	var body_font := _font_body if _font_body else _font_title
	if title_font:
		draw_string(title_font, panel.position + Vector2(12, 22), "FOUND STORE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COL_TEXT)
	if body_font:
		var water_line := "%d / %d gal" % [GameResources.water, GameResources.water_max]
		draw_string(body_font, panel.position + Vector2(12, 38), water_line, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COL_STAT)
		draw_string(
			body_font,
			panel.position + Vector2(12, panel.size.y - 10),
			"E / Esc / B  close",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			8,
			COL_MUTED
		)

	_row_rects.clear()
	var stock := ShopCatalog.stock()
	var row_y := panel.position.y + 48.0
	for i in stock.size():
		var entry: Dictionary = stock[i]
		var row := Rect2(panel.position.x + 10.0, row_y, panel.size.x - 20.0, 40.0)
		_row_rects.append(row)
		_draw_row(row, entry, i == _hovered, body_font, title_font)
		row_y += 44.0


func _draw_row(row: Rect2, entry: Dictionary, hovered: bool, body_font: Font, title_font: Font) -> void:
	var can := _can_buy(entry)
	var fill := Color(0.16, 0.12, 0.10, 0.95)
	if hovered and can:
		fill = Color(0.22, 0.18, 0.14, 0.98)
	elif not can:
		fill = Color(0.10, 0.08, 0.07, 0.9)
	draw_rect(row, fill)
	draw_rect(row, COL_PANEL_EDGE if can else COL_DEAD, false, 1.0)

	var label := str(entry.get("label", ""))
	var cost := int(entry.get("cost", 0))
	var blurb := str(entry.get("blurb", ""))
	var kind: StringName = entry.get("kind", &"")
	var item_id: StringName = entry.get("id", &"")
	var status := "%d gal" % cost
	if kind == &"gun" and GameResources.owns_gun(item_id):
		status = "owned"
	elif kind == &"grenade":
		status = "%d gal  (%d/%d)" % [cost, GameResources.grenades, GameResources.GRENADE_MAX]
	elif not can:
		status = "can't afford"

	var text_col := COL_TEXT if can else COL_DEAD
	var muted := COL_MUTED if can else COL_DEAD
	var font := title_font if title_font else body_font
	if font:
		draw_string(font, row.position + Vector2(8, 14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8 if font == body_font else 16, text_col)
	if body_font:
		draw_string(body_font, row.position + Vector2(row.size.x - 8, 14), status, HORIZONTAL_ALIGNMENT_RIGHT, -1, 8, COL_STAT if can else COL_DEAD)
		draw_string(body_font, row.position + Vector2(8, 28), blurb, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, muted)
