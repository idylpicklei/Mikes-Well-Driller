class_name BuildMenu
extends Control

signal category_chosen(category_id: StringName)
signal item_chosen(category_id: StringName, item_id: StringName)

static var is_open := false

const HUB_RADIUS := 56.0
const CATEGORY_INNER := 62.0
const CATEGORY_OUTER := 148.0
const ITEM_INNER := 156.0
const ITEM_OUTER := 222.0
const SLICE_STEPS := 18
const FONT_PATH := "res://Assets/fonts/PixelOperator8-Bold.ttf"

var categories: Array[Dictionary] = []
var selected_category: StringName = &""
var selected_item: StringName = &""

var _font: Font
var _hovered_category := -1
var _hovered_item := -1
var _open_t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = load(FONT_PATH)
	if categories.is_empty():
		categories = BuildCatalog.default_categories()
	set_process(true)


func add_category(id: StringName, label: String, color: Color, items: Array = []) -> void:
	categories.append({
		"id": id,
		"label": label,
		"color": color,
		"items": items,
	})
	queue_redraw()


func toggle() -> void:
	_set_open(not is_open)


func _set_open(open: bool) -> void:
	BuildMenu.is_open = open
	mouse_filter = Control.MOUSE_FILTER_STOP if open else Control.MOUSE_FILTER_IGNORE
	if open:
		_hovered_category = -1
		_hovered_item = -1
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("build_menu") and not event.is_echo():
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel"):
		_set_open(false)
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_click()
		accept_event()


func _process(delta: float) -> void:
	var target := 1.0 if is_open else 0.0
	var next := move_toward(_open_t, target, delta * 8.0)
	if not is_equal_approx(next, _open_t):
		_open_t = next
		queue_redraw()
	if is_open:
		_update_hover()


func _update_hover() -> void:
	var old_cat := _hovered_category
	var old_item := _hovered_item
	_hovered_category = -1
	_hovered_item = -1

	var local := get_local_mouse_position() - _center()
	var dist := local.length()
	var n := categories.size()
	if n == 0:
		return

	var slice := _slice_index(local.angle(), n)
	if dist >= CATEGORY_INNER * _open_t and dist <= ITEM_OUTER * _open_t:
		_hovered_category = slice
		var items: Array = _items_of(categories[slice])
		if dist >= ITEM_INNER * _open_t and not items.is_empty():
			_hovered_item = _item_index(local.angle(), slice, items.size())

	if _hovered_category != old_cat or _hovered_item != old_item:
		queue_redraw()


func _on_click() -> void:
	if _hovered_item >= 0 and _hovered_category >= 0:
		var category: Dictionary = categories[_hovered_category]
		var items: Array = _items_of(category)
		if _hovered_item < items.size():
			selected_category = _id_of(category)
			selected_item = _id_of(items[_hovered_item])
			category_chosen.emit(selected_category)
			item_chosen.emit(selected_category, selected_item)
			_set_open(false)
			return
	if _hovered_category >= 0:
		selected_category = _id_of(categories[_hovered_category])
		category_chosen.emit(selected_category)
		queue_redraw()
		return
	_set_open(false)


func _draw() -> void:
	if _open_t <= 0.01:
		return

	var center := _center()
	var n := categories.size()
	if n == 0:
		return

	var dim := Color(0.02, 0.03, 0.04, 0.48 * _open_t)
	draw_rect(Rect2(Vector2.ZERO, size), dim)

	var scale_t := _open_t
	for i in n:
		var start := _slice_start(i, n)
		var stop := _slice_start(i + 1, n)
		var color: Color = _color_of(categories[i])
		var hovered: bool = i == _hovered_category
		var chosen: bool = _id_of(categories[i]) == selected_category
		var fill := color
		fill.a = 0.82 if hovered else 0.55
		if chosen:
			fill = fill.lightened(0.12)
		_draw_ring_slice(center, CATEGORY_INNER * scale_t, CATEGORY_OUTER * scale_t, start, stop, fill)

		var show_items: bool = hovered or (_hovered_category < 0 and chosen)
		var items: Array = _items_of(categories[i])
		if show_items:
			_draw_items(center, i, n, items, scale_t)

		var mid := (start + stop) * 0.5
		var label_pos := center + Vector2(cos(mid), sin(mid)) * ((CATEGORY_INNER + CATEGORY_OUTER) * 0.5 * scale_t)
		_draw_label(label_pos, _label_of(categories[i]), 16, Color.WHITE)

	draw_circle(center, HUB_RADIUS * scale_t, Color(0.08, 0.09, 0.1, 0.94))
	draw_arc(center, HUB_RADIUS * scale_t, 0.0, TAU, 48, Color(0.9, 0.9, 0.92, 0.85), 2.0, true)

	var hub_title := "BUILD"
	var hub_sub := "Pick a category"
	if _hovered_item >= 0 and _hovered_category >= 0:
		var items: Array = _items_of(categories[_hovered_category])
		if _hovered_item < items.size():
			hub_title = _label_of(items[_hovered_item])
			hub_sub = _label_of(categories[_hovered_category])
	elif _hovered_category >= 0:
		hub_title = _label_of(categories[_hovered_category])
		hub_sub = "Choose an item"
	elif selected_category != &"":
		hub_title = _label_for(selected_category)
		hub_sub = "Selected"

	_draw_label(center + Vector2(0, -8), hub_title, 16, Color.WHITE)
	_draw_label(center + Vector2(0, 12), hub_sub, 8, Color(0.8, 0.82, 0.85))
	_draw_label(Vector2(size.x * 0.5, size.y * 0.5 + ITEM_OUTER * scale_t + 36.0), "B  close", 8, Color(0.75, 0.78, 0.8, 0.9))


func _draw_items(center: Vector2, category_index: int, category_count: int, items: Array, scale_t: float) -> void:
	if items.is_empty():
		return
	var cat_start := _slice_start(category_index, category_count)
	var cat_span := TAU / float(category_count)
	var count := items.size()
	var pad := 0.08
	for i in count:
		var start := cat_start + cat_span * (float(i) / count) + pad * cat_span
		var stop := cat_start + cat_span * (float(i + 1) / count) - pad * cat_span
		var hovered: bool = category_index == _hovered_category and i == _hovered_item
		var fill := Color(0.12, 0.13, 0.15, 0.88)
		if hovered:
			fill = _color_of(categories[category_index])
			fill.a = 0.9
		_draw_ring_slice(center, ITEM_INNER * scale_t, ITEM_OUTER * scale_t, start, stop, fill)
		var mid := (start + stop) * 0.5
		var pos := center + Vector2(cos(mid), sin(mid)) * ((ITEM_INNER + ITEM_OUTER) * 0.5 * scale_t)
		_draw_label(pos, _label_of(items[i]), 8, Color.WHITE)


func _draw_ring_slice(center: Vector2, inner_r: float, outer_r: float, start: float, stop: float, color: Color) -> void:
	if stop <= start:
		return
	var points := PackedVector2Array()
	for i in SLICE_STEPS + 1:
		var a := lerpf(start, stop, float(i) / SLICE_STEPS)
		points.append(center + Vector2(cos(a), sin(a)) * outer_r)
	for i in SLICE_STEPS + 1:
		var a := lerpf(stop, start, float(i) / SLICE_STEPS)
		points.append(center + Vector2(cos(a), sin(a)) * inner_r)
	draw_colored_polygon(points, color)
	points.append(points[0])
	draw_polyline(points, Color(0.05, 0.05, 0.06, 0.9), 1.5, true)


func _draw_label(pos: Vector2, text: String, font_size: int, color: Color) -> void:
	if _font == null:
		return
	var text_size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(_font, pos - text_size * 0.5 + Vector2(0, text_size.y * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _center() -> Vector2:
	return size * 0.5


func _slice_start(index: int, count: int) -> float:
	return -PI * 0.5 + TAU * float(index) / float(count)


func _slice_index(angle: float, count: int) -> int:
	var turned := fposmod(angle + PI * 0.5, TAU)
	return clampi(int(turned / (TAU / float(count))), 0, count - 1)


func _item_index(angle: float, category_index: int, item_count: int) -> int:
	if item_count <= 0:
		return -1
	var cat_start := _slice_start(category_index, categories.size())
	var cat_span := TAU / float(categories.size())
	var local := fposmod(angle - cat_start, TAU)
	if local > cat_span:
		local = 0.0
	return clampi(int(local / cat_span * item_count), 0, item_count - 1)


func _label_for(category_id: StringName) -> String:
	for category in categories:
		if _id_of(category) == category_id:
			return _label_of(category)
	return "BUILD"


func _id_of(data: Variant) -> StringName:
	if data is Dictionary:
		return StringName(str((data as Dictionary).get("id", "")))
	return &""


func _label_of(data: Variant) -> String:
	if data is Dictionary:
		return str((data as Dictionary).get("label", ""))
	return ""


func _color_of(data: Dictionary) -> Color:
	var value: Variant = data.get("color", Color.WHITE)
	if value is Color:
		return value as Color
	return Color.WHITE


func _items_of(data: Dictionary) -> Array:
	var value: Variant = data.get("items", [])
	if value is Array:
		return value as Array
	return []
