class_name BuildPlacer
extends Node2D

signal hub_placed(hub: Node2D)
signal placement_cancelled

const TILE_SIZE := PlaceholderTileset.TILE_SIZE

static var is_placing := false

var _terrain: TileMapLayer
var _structures: Node2D
var _ghost: Sprite2D
var _pending_item: StringName = &""
var _pending: Dictionary = {}
var _valid := false
var _wait_for_release := false


func _ready() -> void:
	add_to_group("build_placer")
	_terrain = get_parent().get_node_or_null("Terrain") as TileMapLayer
	_structures = get_parent().get_node_or_null("Structures") as Node2D
	_create_ghost()
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
	if _is_unique_built(def):
		return
	_pending_item = item_id
	_pending = def
	is_placing = true
	_wait_for_release = true
	_apply_ghost(def)
	_ghost.visible = true
	set_process(true)


func _cancel_placement() -> void:
	if not is_placing:
		return
	is_placing = false
	_pending_item = &""
	_pending = {}
	_wait_for_release = false
	_ghost.visible = false
	global_position = Vector2.ZERO
	set_process(false)
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
	if _structures == null or _pending.is_empty():
		_cancel_placement()
		return

	var scene: PackedScene = _pending.get("scene")
	if scene == null:
		_cancel_placement()
		return

	var node := scene.instantiate()
	node.position = _structures.to_local(global_position)
	_structures.add_child(node)
	if _pending_item == &"main_hub":
		hub_placed.emit(node)
	BuildMenu.block_shoot = true
	global_position = Vector2.ZERO
	_cancel_placement()


func _is_unique_built(def: Dictionary) -> bool:
	var group := str(def.get("unique_group", ""))
	if group.is_empty():
		return false
	return not get_tree().get_nodes_in_group(group).is_empty()


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


func _is_valid_position(world_pos: Vector2) -> bool:
	if _pending.is_empty() or _is_unique_built(_pending):
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
	return true


func _has_tile(cell: Vector2i) -> bool:
	return _terrain.get_cell_source_id(cell) != -1


func _is_grass(cell: Vector2i) -> bool:
	return _has_tile(cell) and _terrain.get_cell_atlas_coords(cell) == PlaceholderTileset.GRASS
