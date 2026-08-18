class_name BuildPlacer
extends Node2D

signal hub_placed(hub: Node2D)
signal placement_cancelled

const TILE_SIZE := PlaceholderTileset.TILE_SIZE
const FONT_PATH := "res://Assets/fonts/PixelOperator8-Bold.ttf"

static var is_placing := false

var _terrain: TileMapLayer
var _structures: Node2D
var _ghost: Sprite2D
var _font: Font
var _pending_item: StringName = &""
var _pending: Dictionary = {}
var _valid := false
var _wait_for_release := false
var _popup_boost := 0
var _show_efficiency := false


func _ready() -> void:
	add_to_group("build_placer")
	_terrain = get_parent().get_node_or_null("Terrain") as TileMapLayer
	_structures = get_parent().get_node_or_null("Structures") as Node2D
	_create_ghost()
	_font = load(FONT_PATH)
	set_process(false)
	call_deferred("_connect_build_menu")


func _connect_build_menu() -> void:
	var menu := get_tree().get_first_node_in_group("build_menu") as BuildMenu
	if menu and not menu.item_chosen.is_connected(_on_item_chosen):
		menu.item_chosen.connect(_on_item_chosen)


func _on_item_chosen(_category_id: StringName, item_id: StringName) -> void:
	var def := BuildCatalog.placeable(item_id)
	if def.is_empty():
		return
	_start_placement(item_id, def)


func _start_placement(item_id: StringName, def: Dictionary) -> void:
	if _is_at_cap(def):
		return
	_pending_item = item_id
	_pending = def
	is_placing = true
	_wait_for_release = true
	_apply_ghost(def)
	_ghost.visible = true
	z_index = 20
	set_process(true)


func _cancel_placement() -> void:
	if not is_placing:
		return
	is_placing = false
	_pending_item = &""
	_pending = {}
	_wait_for_release = false
	_ghost.visible = false
	_show_efficiency = false
	global_position = Vector2.ZERO
	z_index = 0
	set_process(false)
	queue_redraw()
	placement_cancelled.emit()


func _create_ghost() -> void:
	_ghost = Sprite2D.new()
	_ghost.centered = true
	_ghost.modulate = Color(1, 1, 1, 0.55)
	_ghost.visible = false
	add_child(_ghost)


func _apply_ghost(def: Dictionary) -> void:
	_ghost.texture = def.get("texture") as Texture2D
	_ghost.position = def.get("sprite_offset", Vector2.ZERO)


func _process(_delta: float) -> void:
	if not is_placing or _terrain == null:
		return
	if _wait_for_release and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_wait_for_release = false

	var mouse := get_global_mouse_position()
	global_position = _snap_position(mouse)
	_valid = _is_valid_position(mouse)
	_ghost.modulate = Color(0.45, 1, 0.55, 0.65) if _valid else Color(1, 0.4, 0.4, 0.65)
	_update_efficiency_popup()


func _unhandled_input(event: InputEvent) -> void:
	if not is_placing:
		return
	if BuildMenu.is_open or PauseMenu.is_open:
		_cancel_placement()
		return
	if _wait_for_release:
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and _valid:
			_place_item()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_placement()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("pause") or event.is_action_pressed("build_menu"):
		_cancel_placement()
		get_viewport().set_input_as_handled()


func _place_item() -> void:
	if _structures == null or _pending.is_empty() or _is_at_cap(_pending):
		_cancel_placement()
		return
	if not _can_afford(_pending):
		_valid = false
		_ghost.modulate = Color(1, 0.4, 0.4, 0.65)
		return

	var scene: PackedScene = _pending.get("scene")
	if scene == null:
		_cancel_placement()
		return

	var water_cost := int(_pending.get("cost_water", 0))
	var gold_cost := int(_pending.get("cost_gold", 0))
	if water_cost > 0 and not GameResources.spend_water(water_cost):
		_valid = false
		_ghost.modulate = Color(1, 0.4, 0.4, 0.65)
		return
	if gold_cost > 0 and not GameResources.spend_gold(gold_cost):
		if water_cost > 0:
			GameResources.add_water(water_cost)
		_valid = false
		_ghost.modulate = Color(1, 0.4, 0.4, 0.65)
		return

	var place_origin := global_position
	var node := scene.instantiate()
	node.position = _structures.to_local(place_origin)
	_structures.add_child(node)
	if _pending_item == &"main_hub":
		hub_placed.emit(node)
	elif _pending_item == &"basic_drill":
		var well := _find_attachable_well(place_origin)
		if well == null or not node.has_method("attach_to_well") or not node.attach_to_well(well):
			node.queue_free()
			if water_cost > 0:
				GameResources.add_water(water_cost)
			if gold_cost > 0:
				GameResources.add_gold(gold_cost)
			_valid = false
			_ghost.modulate = Color(1, 0.4, 0.4, 0.65)
			return
	BuildMenu.block_shoot = true
	global_position = Vector2.ZERO
	_cancel_placement()


func _is_at_cap(def: Dictionary) -> bool:
	var group := str(def.get("unique_group", ""))
	if group.is_empty():
		return false
	var max_count := int(def.get("max_count", 1))
	return get_tree().get_nodes_in_group(group).size() >= max_count


func _snap_position(world_pos: Vector2) -> Vector2:
	var grass := _surface_grass_at(_world_to_cell(world_pos))
	if grass == Vector2i(-999999, -999999):
		var fallback := _world_to_cell(world_pos)
		return _terrain.to_global(_terrain.map_to_local(fallback))
	return _origin_on_grass(grass)


func _world_to_cell(world_pos: Vector2) -> Vector2i:
	return _terrain.local_to_map(_terrain.to_local(world_pos))


func _origin_on_grass(anchor_grass: Vector2i) -> Vector2:
	var width: int = int(_pending.get("width", 1))
	var left_x := _left_column(anchor_grass.x, width)
	var left_center := _terrain.map_to_local(Vector2i(left_x, anchor_grass.y))
	var right_center := _terrain.map_to_local(Vector2i(left_x + width - 1, anchor_grass.y))
	var foot := Vector2((left_center.x + right_center.x) * 0.5, left_center.y - TILE_SIZE * 0.5)
	return _terrain.to_global(foot)


func _left_column(anchor_x: int, width: int) -> int:
	if width <= 1:
		return anchor_x
	if width % 2 == 1:
		return anchor_x - int(width / 2.0)
	return anchor_x


func _surface_grass_at(cell: Vector2i) -> Vector2i:
	var probe := cell
	if _has_tile(probe):
		while _has_tile(probe + Vector2i(0, -1)):
			probe += Vector2i(0, -1)
		if _is_grass(probe):
			return probe
		return Vector2i(-999999, -999999)

	for _i in 32:
		probe += Vector2i(0, 1)
		if _has_tile(probe):
			if _is_grass(probe):
				return probe
			return Vector2i(-999999, -999999)
	return Vector2i(-999999, -999999)


func _can_afford(def: Dictionary) -> bool:
	var water_cost := int(def.get("cost_water", 0))
	if water_cost > 0 and GameResources.water < water_cost:
		return false
	var gold_cost := int(def.get("cost_gold", 0))
	if gold_cost > 0 and GameResources.gold < gold_cost:
		return false
	return true


func _is_valid_position(world_pos: Vector2) -> bool:
	if _pending.is_empty() or _is_at_cap(_pending) or not _can_afford(_pending):
		return false

	var grass := _surface_grass_at(_world_to_cell(world_pos))
	if grass == Vector2i(-999999, -999999):
		return false

	var width: int = int(_pending.get("width", 1))
	var height: int = int(_pending.get("height", 1))
	var left_x := _left_column(grass.x, width)
	for dx in width:
		var ground := Vector2i(left_x + dx, grass.y)
		if not _is_grass(ground):
			return false
		for dy in range(1, height + 1):
			if _has_tile(ground + Vector2i(0, -dy)):
				return false
	var origin := _origin_on_grass(grass)
	if _pending_item == &"well":
		if _overlaps_group_footprints(origin, PlaceholderWell.SIZE, "well", PlaceholderWell.SIZE):
			return false
		if _overlaps_group_footprints(origin, PlaceholderWell.SIZE, "drill", PlaceholderDrill.SIZE):
			return false
	elif _pending_item == &"basic_drill":
		if _overlaps_group_footprints(origin, PlaceholderDrill.SIZE, "well", PlaceholderWell.SIZE):
			return false
		if _overlaps_group_footprints(origin, PlaceholderDrill.SIZE, "drill", PlaceholderDrill.SIZE):
			return false
		if _find_attachable_well(origin) == null:
			return false
	return true


func _overlaps_group_footprints(origin: Vector2, size: Vector2i, group: String, other_size: Vector2i) -> bool:
	var proposed := _footprint_rect(origin, size)
	for node in get_tree().get_nodes_in_group(group):
		if not node is Node2D:
			continue
		var other := _footprint_rect((node as Node2D).global_position, other_size)
		if proposed.intersects(other):
			return true
	return false


## 8-way adjacency: footprints must touch on an edge or corner (no gap).
func _find_attachable_well(origin: Vector2) -> Node2D:
	var proposed := _footprint_rect(origin, PlaceholderDrill.SIZE)
	var best: Node2D = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("well"):
		if not node is Node2D:
			continue
		var well := node as Node2D
		if well.has_method("has_drill") and well.has_drill():
			continue
		var well_rect := _footprint_rect(well.global_position, PlaceholderWell.SIZE)
		if well_rect.intersects(proposed):
			continue
		if not well_rect.grow(1.0).intersects(proposed):
			continue
		var dist := origin.distance_squared_to(well.global_position)
		if dist < best_dist:
			best_dist = dist
			best = well
	return best


func _footprint_rect(origin: Vector2, size: Vector2i) -> Rect2:
	return Rect2(origin + Vector2(-size.x * 0.5, -float(size.y)), Vector2(size))


func _has_tile(cell: Vector2i) -> bool:
	return _terrain.get_cell_source_id(cell) != -1


func _is_grass(cell: Vector2i) -> bool:
	return _has_tile(cell) and _terrain.get_cell_atlas_coords(cell) == PlaceholderTileset.GRASS


func _update_efficiency_popup() -> void:
	_show_efficiency = _pending_item == &"well"
	if _show_efficiency:
		var efficiency := WellEfficiency.at_world(global_position)
		_popup_boost = WellEfficiency.boost_percent(efficiency)
	queue_redraw()


func _draw() -> void:
	if not _show_efficiency or _font == null:
		return

	var boost_text := "+%d%%" % _popup_boost if _popup_boost >= 0 else "%d%%" % _popup_boost
	var good: bool = _popup_boost >= 0
	var fill := Color(0.18, 0.42, 0.2, 0.94) if good else Color(0.48, 0.14, 0.14, 0.94)
	var accent := Color("7ed957") if good else Color("e85d5d")

	var boost_size := _font.get_string_size(boost_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8)
	var width := boost_size.x + 8.0
	var height := 12.0
	var ghost_top := float(_pending.get("sprite_offset", Vector2.ZERO).y) - 10.0
	var box := Rect2(Vector2(-width * 0.5, ghost_top - height - 3.0), Vector2(width, height))
	draw_rect(box, fill)
	draw_rect(box, accent, false, 1.0)
	draw_string(_font, box.position + Vector2(4, 9), boost_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, accent)
