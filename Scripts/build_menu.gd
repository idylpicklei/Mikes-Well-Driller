class_name BuildMenu
extends Control

signal category_chosen(category_id: StringName)
signal item_chosen(category_id: StringName, item_id: StringName)

static var is_open := false
static var block_shoot := false

const HUB_RADIUS := 56.0
const CATEGORY_INNER := 62.0
const CATEGORY_OUTER := 148.0
const ITEM_INNER := 156.0
const ITEM_OUTER := 222.0
const SLICE_STEPS := 18
const FONT_PATH := "res://Assets/fonts/PixelOperator8-Bold.ttf"
const DETAIL_WIDTH := 280.0

## Dusk-wasteland chrome — matches DefendHud.
const COL_PANEL := Color(0.12, 0.09, 0.08, 0.94)
const COL_PANEL_EDGE := Color(0.55, 0.32, 0.22, 0.95)
const COL_TEAL := Color(0.28, 0.55, 0.58, 1.0)
const COL_TEXT := Color(0.86, 0.78, 0.68, 1.0)
const COL_MUTED := Color(0.62, 0.55, 0.48, 1.0)
const COL_STAT := Color(0.55, 0.78, 0.76, 1.0)

var categories: Array[Dictionary] = []
var selected_category: StringName = &""
var selected_item: StringName = &""

var _font: Font
var _hovered_category := -1
var _hovered_item := -1
var _open_t := 0.0


func _ready() -> void:
	add_to_group("build_menu")
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	if _should_block_toggle():
		return
	_set_open(not is_open)


static func close_menu() -> void:
	for node in Engine.get_main_loop().root.find_children("*", "BuildMenu", true, false):
		(node as BuildMenu).close_menu_instance()
		return


func close_menu_instance() -> void:
	_set_open(false)


func _should_block_toggle() -> bool:
	# Allow closing while we ourselves paused the tree; block only Esc-pause / game over.
	if PauseMenu.is_open:
		return true
	return _game_over_visible()


func _game_over_visible() -> bool:
	for node in get_tree().get_nodes_in_group("game_over"):
		if node is CanvasItem and (node as CanvasItem).visible:
			return true
	return false


func _set_open(open: bool) -> void:
	BuildMenu.is_open = open
	mouse_filter = Control.MOUSE_FILTER_STOP if open else Control.MOUSE_FILTER_IGNORE
	if open:
		_hovered_category = -1
		_hovered_item = -1
		get_tree().paused = true
	else:
		# Keep pause if Esc pause or Game Over owns it; else resume so placement can run.
		if not PauseMenu.is_open and not _game_over_visible():
			get_tree().paused = false
	queue_redraw()


func _input(event: InputEvent) -> void:
	if PauseMenu.is_open or _game_over_visible():
		return
	if event.is_action_pressed("build_menu") and not event.is_echo():
		toggle()
		get_viewport().set_input_as_handled()
		return
	if not is_open:
		return
	if event.is_action_pressed("pause"):
		_set_open(false)
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		block_shoot = true
		accept_event()
		_on_click()


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
	var cats := _visible_categories()
	var n := cats.size()
	if n == 0:
		return

	var slice := _slice_index(local.angle(), n)
	if dist >= CATEGORY_INNER * _open_t and dist <= ITEM_OUTER * _open_t:
		_hovered_category = slice
		var items: Array = _visible_items(cats[slice])
		if dist >= ITEM_INNER * _open_t and not items.is_empty():
			_hovered_item = _item_index(local.angle(), slice, items.size(), n)

	if _hovered_category != old_cat or _hovered_item != old_item:
		queue_redraw()


func _on_click() -> void:
	var cats := _visible_categories()
	if _hovered_item >= 0 and _hovered_category >= 0 and _hovered_category < cats.size():
		var category: Dictionary = cats[_hovered_category]
		var items: Array = _visible_items(category)
		if _hovered_item < items.size():
			selected_category = _id_of(category)
			selected_item = _id_of(items[_hovered_item])
			category_chosen.emit(selected_category)
			item_chosen.emit(selected_category, selected_item)
			_set_open(false)
			return
	if _hovered_category >= 0 and _hovered_category < cats.size():
		selected_category = _id_of(cats[_hovered_category])
		category_chosen.emit(selected_category)
		queue_redraw()
		return
	_set_open(false)


func _draw() -> void:
	if _open_t <= 0.01:
		return

	var center := _center()
	var cats := _visible_categories()
	var n := cats.size()
	if n == 0:
		_draw_empty_hub(center)
		return

	var dim := Color(0.06, 0.04, 0.03, 0.52 * _open_t)
	draw_rect(Rect2(Vector2.ZERO, size), dim)

	var scale_t := _open_t
	for i in n:
		var start := _slice_start(i, n)
		var stop := _slice_start(i + 1, n)
		var color: Color = _color_of(cats[i])
		var hovered: bool = i == _hovered_category
		var chosen: bool = _id_of(cats[i]) == selected_category
		var fill := color
		fill.a = 0.82 if hovered else 0.55
		if chosen:
			fill = fill.lightened(0.12)
		_draw_ring_slice(center, CATEGORY_INNER * scale_t, CATEGORY_OUTER * scale_t, start, stop, fill)

		var show_items: bool = hovered or (_hovered_category < 0 and chosen)
		var items: Array = _visible_items(cats[i])
		if show_items:
			_draw_items(center, i, n, items, scale_t, cats)

		var mid := (start + stop) * 0.5
		var label_pos := center + Vector2(cos(mid), sin(mid)) * ((CATEGORY_INNER + CATEGORY_OUTER) * 0.5 * scale_t)
		_draw_label(label_pos, _label_of(cats[i]), 16, COL_TEXT)

	draw_circle(center, HUB_RADIUS * scale_t, COL_PANEL)
	draw_arc(center, HUB_RADIUS * scale_t, 0.0, TAU, 48, COL_PANEL_EDGE, 2.0, true)
	draw_arc(center, HUB_RADIUS * scale_t - 3.0, 0.0, TAU, 48, COL_TEAL * Color(1, 1, 1, 0.55), 1.0, true)

	var hub_title := "BUILD"
	var hub_sub := "Pick a category"
	var detail_item: StringName = &""
	if _hovered_item >= 0 and _hovered_category >= 0 and _hovered_category < cats.size():
		var items: Array = _visible_items(cats[_hovered_category])
		if _hovered_item < items.size():
			hub_title = _label_of(items[_hovered_item])
			hub_sub = _label_of(cats[_hovered_category])
			detail_item = _id_of(items[_hovered_item])
	elif _hovered_category >= 0 and _hovered_category < cats.size():
		hub_title = _label_of(cats[_hovered_category])
		hub_sub = "Choose an item"
	elif selected_category != &"":
		hub_title = _label_for(selected_category)
		hub_sub = "Selected"

	_draw_label(center + Vector2(0, -8), hub_title, 16, COL_TEXT)
	_draw_label(center + Vector2(0, 12), hub_sub, 8, COL_MUTED)
	_draw_label(Vector2(size.x * 0.5, size.y * 0.5 + ITEM_OUTER * scale_t + 36.0), "B  close", 8, COL_MUTED)

	if detail_item != &"":
		_draw_detail_panel(center, detail_item, scale_t)


func _draw_empty_hub(center: Vector2) -> void:
	var dim := Color(0.06, 0.04, 0.03, 0.52 * _open_t)
	draw_rect(Rect2(Vector2.ZERO, size), dim)
	draw_circle(center, HUB_RADIUS * _open_t, COL_PANEL)
	draw_arc(center, HUB_RADIUS * _open_t, 0.0, TAU, 48, COL_PANEL_EDGE, 2.0, true)
	_draw_label(center + Vector2(0, -4), "BUILD", 16, COL_TEXT)
	_draw_label(center + Vector2(0, 14), "Nothing left to place", 8, COL_MUTED)


func _draw_detail_panel(center: Vector2, item_id: StringName, scale_t: float) -> void:
	if _font == null:
		return
	var blurb := BuildCatalog.item_blurb(item_id)
	var stats := BuildCatalog.item_stats(item_id)
	if blurb.is_empty() and stats.is_empty():
		return

	var title := hub_title_for(item_id)
	var pad := 10.0
	var line_h := 12.0
	var blurb_wrapped := _wrap_text(blurb, DETAIL_WIDTH - pad * 2.0, 8)
	var height := pad + 14.0 + pad * 0.5
	height += float(blurb_wrapped.size()) * line_h
	if not stats.is_empty():
		height += 6.0 + float(stats.size()) * line_h
	height += pad

	var panel_w := DETAIL_WIDTH
	var panel_h := height
	var origin := Vector2(
		center.x - panel_w * 0.5,
		center.y + ITEM_OUTER * scale_t + 52.0
	)
	# Keep on-screen if the wheel is near the bottom.
	if origin.y + panel_h > size.y - 8.0:
		origin.y = center.y - ITEM_OUTER * scale_t - panel_h - 16.0

	var box := Rect2(origin, Vector2(panel_w, panel_h))
	draw_rect(box, COL_PANEL)
	draw_rect(box, COL_PANEL_EDGE, false, 2.0)
	draw_rect(Rect2(box.position + Vector2(2, 2), Vector2(box.size.x - 4, 2)), COL_TEAL * Color(1, 1, 1, 0.7))

	var cursor := origin + Vector2(pad, pad + 10.0)
	draw_string(_font, cursor, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, COL_TEXT)
	cursor.y += 14.0
	for line in blurb_wrapped:
		draw_string(_font, cursor, line, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COL_MUTED)
		cursor.y += line_h
	if not stats.is_empty():
		cursor.y += 4.0
		var stat_line := " · ".join(stats)
		for line in _wrap_text(stat_line, DETAIL_WIDTH - pad * 2.0, 8):
			draw_string(_font, cursor, line, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, COL_STAT)
			cursor.y += line_h


func hub_title_for(item_id: StringName) -> String:
	for category in categories:
		for item in _items_of(category):
			if _id_of(item) == item_id:
				return _label_of(item)
	return str(item_id)


func _wrap_text(text: String, max_width: float, font_size: int) -> PackedStringArray:
	var out: PackedStringArray = []
	if _font == null or text.is_empty():
		return out
	var words := text.split(" ", false)
	var current := ""
	for word in words:
		var trial := word if current.is_empty() else current + " " + word
		var w := _font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if w <= max_width or current.is_empty():
			current = trial
		else:
			out.append(current)
			current = word
	if not current.is_empty():
		out.append(current)
	return out


func _draw_items(center: Vector2, category_index: int, category_count: int, items: Array, scale_t: float, cats: Array) -> void:
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
		var fill := Color(0.14, 0.11, 0.10, 0.9)
		if hovered:
			fill = _color_of(cats[category_index])
			fill.a = 0.92
		_draw_ring_slice(center, ITEM_INNER * scale_t, ITEM_OUTER * scale_t, start, stop, fill)
		var mid := (start + stop) * 0.5
		var pos := center + Vector2(cos(mid), sin(mid)) * ((ITEM_INNER + ITEM_OUTER) * 0.5 * scale_t)
		_draw_label(pos, _label_of(items[i]), 8, COL_TEXT)


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
	draw_polyline(points, Color(0.08, 0.05, 0.04, 0.92), 1.5, true)


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


func _item_index(angle: float, category_index: int, item_count: int, category_count: int = -1) -> int:
	if item_count <= 0:
		return -1
	var n := category_count if category_count > 0 else _visible_categories().size()
	if n <= 0:
		return -1
	var cat_start := _slice_start(category_index, n)
	var cat_span := TAU / float(n)
	var local := fposmod(angle - cat_start, TAU)
	if local > cat_span:
		local = 0.0
	return clampi(int(local / cat_span * item_count), 0, item_count - 1)


func _visible_categories() -> Array:
	var out: Array = []
	for category in categories:
		if not _visible_items(category).is_empty():
			out.append(category)
	return out


func _visible_items(data: Dictionary) -> Array:
	var out: Array = []
	for item in _items_of(data):
		var id := _id_of(item)
		if BuildCatalog.is_available(id, get_tree()):
			out.append(item)
	return out


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
