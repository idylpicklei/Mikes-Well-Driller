class_name BuildPlacer
extends Node2D

signal hub_placed(hub: Node2D)
signal placement_cancelled
signal structure_placed(item_id: StringName, node: Node)

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
## Ignore the catalog LMB that armed us — never blocks cancel (RMB / B).
var _wait_for_release := false
var _popup_boost := 0
var _show_efficiency := false


func _ready() -> void:
	add_to_group("build_placer")
	# Keep ghost + cancel responsive even if a pause edge-case flickers.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_terrain = get_parent().get_node_or_null("Terrain") as TileMapLayer
	_structures = get_parent().get_node_or_null("Structures") as Node2D
	_create_ghost()
	_font = load(FONT_PATH)
	set_process(false)
	call_deferred("_connect_build_menu")
	call_deferred("_resolve_terrain")


func _resolve_terrain() -> void:
	if _terrain == null:
		_terrain = get_tree().get_first_node_in_group("terrain") as TileMapLayer
	if _structures == null and get_parent():
		_structures = get_parent().get_node_or_null("Structures") as Node2D


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
	_resolve_terrain()
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
	# Snap ghost under the cursor immediately — don't wait a process tick.
	_refresh_ghost_at_mouse()


func _cancel_placement() -> void:
	if not is_placing and _pending_item == &"":
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


## BuildMenu opens via handled B-key; placer never sees that input — menu calls this.
func cancel_from_menu() -> void:
	_cancel_placement()


func _create_ghost() -> void:
	_ghost = Sprite2D.new()
	_ghost.centered = true
	_ghost.modulate = Color(1, 1, 1, 0.55)
	_ghost.visible = false
	_ghost.z_index = 1
	add_child(_ghost)


func _apply_ghost(def: Dictionary) -> void:
	var tex := def.get("texture") as Texture2D
	if tex == null and def.has("scene"):
		# Last-resort: still show a footprint so place mode is never "invisible".
		tex = _make_fallback_ghost(int(def.get("width", 1)), int(def.get("height", 1)))
	_ghost.texture = tex
	_ghost.position = def.get("sprite_offset", Vector2.ZERO)
	_ghost.visible = is_placing


func _make_fallback_ghost(width_tiles: int, height_tiles: int) -> Texture2D:
	var w := maxi(width_tiles, 1) * TILE_SIZE
	var h := maxi(height_tiles, 1) * TILE_SIZE
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.45, 0.85, 0.55, 0.55))
	return ImageTexture.create_from_image(img)


func _process(_delta: float) -> void:
	if not is_placing:
		return
	# Placement itself must not run while the B-catalog owns the pause freeze.
	if BuildMenu.is_open or PauseMenu.is_open:
		return
	_resolve_terrain()
	if _terrain == null:
		return
	if _wait_for_release and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_wait_for_release = false

	_refresh_ghost_at_mouse()


func _refresh_ghost_at_mouse() -> void:
	if _terrain == null or _pending.is_empty():
		return
	var mouse := get_global_mouse_position()
	global_position = _snap_position(mouse)
	# Validate at the snapped origin (same point place uses) so occupancy goes red immediately.
	_valid = _is_valid_position(mouse) and _is_valid_origin(global_position)
	_apply_ghost_tint()
	_update_efficiency_popup()
	if _ghost:
		_ghost.visible = true
	queue_redraw()


func _apply_ghost_tint() -> void:
	if _ghost == null:
		return
	# Strong red when blocked (occupancy / no grass / can't afford) so refuse is never silent.
	if _valid:
		_ghost.modulate = Color(0.45, 1.0, 0.55, 0.7)
	else:
		_ghost.modulate = Color(1.0, 0.25, 0.25, 0.85)
	_ghost.visible = is_placing


func _mark_invalid_ghost() -> void:
	_valid = false
	_apply_ghost_tint()
	if _ghost:
		_ghost.visible = true
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not is_placing:
		return
	if BuildMenu.is_open or PauseMenu.is_open:
		_cancel_placement()
		return

	# Cancel always works — even before the arming LMB is released.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_cancel_placement()
		get_viewport().set_input_as_handled()
		return
	if InputBindings.is_build_toggle_event(event) or event.is_action_pressed("pause"):
		_cancel_placement()
		get_viewport().set_input_as_handled()
		return

	if _wait_for_release:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Re-snap + re-validate at click time so ghost never lies green on a refused click.
		_refresh_ghost_at_mouse()
		if _valid:
			_place_item()
		else:
			_mark_invalid_ghost()
		get_viewport().set_input_as_handled()


func _place_item() -> void:
	if _structures == null or _pending.is_empty() or _is_at_cap(_pending):
		_mark_invalid_ghost()
		return
	# Re-check occupancy at snap origin so invalid clicks never spend water.
	if not _is_valid_origin(global_position) or not _can_afford(_pending):
		_mark_invalid_ghost()
		return

	var scene: PackedScene = _pending.get("scene")
	if scene == null:
		_mark_invalid_ghost()
		return

	var cost := int(_pending.get("cost_water", 0))
	if cost > 0 and not GameResources.spend_water(cost):
		_mark_invalid_ghost()
		return

	var place_origin := global_position
	var node := scene.instantiate()
	if node == null:
		if cost > 0:
			GameResources.add_water(cost)
		_mark_invalid_ghost()
		return

	node.position = _structures.to_local(place_origin)
	_structures.add_child(node)
	# Ensure the placed structure is actually in-tree and visible before we keep the spend.
	if not is_instance_valid(node) or not node.is_inside_tree():
		if cost > 0:
			GameResources.add_water(cost)
		_mark_invalid_ghost()
		return
	if node is CanvasItem:
		(node as CanvasItem).visible = true
		(node as CanvasItem).z_index = maxi((node as CanvasItem).z_index, 1)

	if _pending_item == &"main_hub":
		hub_placed.emit(node)
	elif _pending_item == &"turret":
		_orient_new_turret(node, place_origin)
	elif _pending_item == &"basic_drill":
		var well := _find_attachable_well(place_origin)
		if well == null or not node.has_method("attach_to_well") or not node.attach_to_well(well):
			node.queue_free()
			if cost > 0:
				GameResources.add_water(cost)
			_mark_invalid_ghost()
			return
	elif _pending_item == &"well":
		_ensure_well_visible(node)

	structure_placed.emit(_pending_item, node)
	BuildMenu.block_shoot = true
	# Keep placing repeatables (walls/turrets/wells/drills); unique hub ends the mode.
	if _pending_item == &"main_hub" or _is_at_cap(_pending):
		global_position = Vector2.ZERO
		_cancel_placement()
	else:
		_wait_for_release = true
		_refresh_ghost_at_mouse()


func _ensure_well_visible(node: Node) -> void:
	if node == null:
		return
	if node is Node2D:
		(node as Node2D).z_index = 2
	var sprite := node.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	if sprite.texture == null:
		sprite.texture = PlaceholderWell.create_texture()
	sprite.visible = true
	sprite.centered = true
	sprite.position = PlaceholderWell.SPRITE_OFFSET
	sprite.modulate = Color(0.7, 0.7, 0.72, 1.0)


func _orient_new_turret(turret: Node, place_origin: Vector2) -> void:
	if turret == null:
		return
	var hub := get_tree().get_first_node_in_group("main_hub") as Node2D
	if hub and turret.has_method("set_idle_facing_from_hub_at"):
		# Use place_origin — turret.global_position can still be stale the frame of add_child.
		turret.set_idle_facing_from_hub_at(hub.global_position, place_origin)
	elif hub and turret.has_method("set_idle_facing_from_hub"):
		turret.set_idle_facing_from_hub(hub)
	elif turret.has_method("set_idle_facing_from_placer"):
		var player := get_tree().get_first_node_in_group("player") as Node2D
		var from := player.global_position if player else place_origin
		turret.set_idle_facing_from_placer(from)


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
	var cost := int(def.get("cost_water", 0))
	return cost <= 0 or GameResources.water >= cost


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
	return _is_valid_origin(_origin_on_grass(grass))


## Occupancy + drill adjacency at a snapped foot origin (no water spend on fail).
func _is_valid_origin(origin: Vector2) -> bool:
	if _pending.is_empty() or _is_at_cap(_pending):
		return false
	var size := _pending_footprint_size()
	if _overlaps_any_structure(origin, size):
		return false
	if _pending_item == &"basic_drill" and _find_attachable_well(origin) == null:
		return false
	return true


func _pending_footprint_size() -> Vector2i:
	match _pending_item:
		&"main_hub":
			return PlaceholderHub.SIZE
		&"well":
			return PlaceholderWell.SIZE
		&"basic_drill":
			return PlaceholderDrill.SIZE
		&"wall":
			return PlaceholderWall.SIZE
		&"turret":
			return PlaceholderTurret.SIZE
		_:
			var w := int(_pending.get("width", 1))
			var h := int(_pending.get("height", 1))
			return Vector2i(w * TILE_SIZE, h * TILE_SIZE)


func _overlaps_any_structure(origin: Vector2, size: Vector2i) -> bool:
	var proposed := _footprint_rect(origin, size)
	for other in _occupied_footprints():
		if proposed.intersects(other):
			return true
	return false


func _occupied_footprints() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	_append_group_footprints(rects, "main_hub", PlaceholderHub.SIZE)
	# Hub tank overlay is its own blocked footprint (even if mostly inside the hub sprite).
	for node in get_tree().get_nodes_in_group("main_hub"):
		if node is Node2D:
			rects.append(_footprint_rect((node as Node2D).global_position, PlaceholderTank.SIZE))
	_append_group_footprints(rects, "well", PlaceholderWell.SIZE)
	_append_group_footprints(rects, "drill", PlaceholderDrill.SIZE)
	_append_group_footprints(rects, "wall", PlaceholderWall.SIZE)
	_append_group_footprints(rects, "turret", PlaceholderTurret.SIZE)
	return rects


func _append_group_footprints(rects: Array[Rect2], group: String, size: Vector2i) -> void:
	for node in get_tree().get_nodes_in_group(group):
		if not node is Node2D:
			continue
		rects.append(_footprint_rect((node as Node2D).global_position, size))


## 8-way adjacency: footprints must touch on an edge or corner (no gap), never overlap.
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
	# Tiny inset so edge-adjacent walls still place, but any real overlap is caught.
	var rect := Rect2(origin + Vector2(-size.x * 0.5, -float(size.y)), Vector2(size))
	return rect.grow(-0.01)


func _has_tile(cell: Vector2i) -> bool:
	return _terrain.get_cell_source_id(cell) != -1


func _is_grass(cell: Vector2i) -> bool:
	return _has_tile(cell) and PlaceholderTileset.is_grass(_terrain.get_cell_atlas_coords(cell))


func _update_efficiency_popup() -> void:
	_show_efficiency = _pending_item == &"well"
	if _show_efficiency:
		var efficiency := WellEfficiency.at_world(global_position)
		_popup_boost = WellEfficiency.boost_percent(efficiency)
	queue_redraw()


func _draw() -> void:
	# Occupancy / invalid: draw a clear red footprint so refuse is never silent.
	if is_placing and not _valid and not _pending.is_empty():
		var size := _pending_footprint_size()
		var rect := Rect2(Vector2(-size.x * 0.5, -float(size.y)), Vector2(size))
		draw_rect(rect, Color(1.0, 0.2, 0.2, 0.22))
		draw_rect(rect, Color(1.0, 0.35, 0.3, 0.95), false, 2.0)

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
