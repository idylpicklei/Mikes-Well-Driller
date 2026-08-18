extends Area2D

## Acid ocean past the beach. Overlap ticks 5 HP/s on Mike and hires; leave to stop.
## Floor descends from shallow-blend depth into deeper water (wade ramp). Artist drop-in:
## replace Assets/sprites/acid_ocean.png (4×2 atlas); paint maps columns deeper outward.

const DPS := PlaceholderAcidOcean.DAMAGE_PER_SECOND
## Character bodies sit above their feet — extend the hurt box above the waterline.
const HURT_ABOVE := 36.0
## Match beach shallow-blend depth, then ramp deeper over the first ocean columns.
const FLOOR_START_DEPTH_PX := 12.0
const FLOOR_DEEP_DEPTH_PX := 24.0
const FLOOR_RAMP_TILES := 6
## Soft inland lip so the ocean rectangle blends under the beach shallow-blend.
const BLEND_INLAND_TILES := 1.0

var _accum: Dictionary = {}  # instance_id -> float damage accumulator


func _ready() -> void:
	add_to_group("acid")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


func setup(size_px: Vector2, inland_overlap_px: float = 0.0, inland: float = 0.0) -> void:
	var tile := float(PlaceholderTileset.TILE_SIZE)
	var overlap := maxf(inland_overlap_px, 0.0)
	var inland_dir := 0.0 if is_zero_approx(inland) else signf(inland)

	_build_ocean_visual(size_px, inland_dir, tile)
	_build_hurt_box(size_px, overlap, inland_dir)
	_build_floor_ramp(size_px, overlap, inland_dir, tile)


func _build_hurt_box(size_px: Vector2, overlap: float, inland_dir: float) -> void:
	var hurt_h := size_px.y + HURT_ABOVE
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return
	var rect := RectangleShape2D.new()
	rect.size = Vector2(size_px.x + overlap, hurt_h)
	shape_node.shape = rect
	# Node origin is visual center; shift hurt box up so it clears the waterline.
	# Overlap extends inland under the beach so footing/DOT stay continuous.
	shape_node.position = Vector2(inland_dir * overlap * 0.5, -HURT_ABOVE * 0.5)


func _build_floor_ramp(size_px: Vector2, overlap: float, inland_dir: float, tile: float) -> void:
	var floor_body := get_node_or_null("Floor") as StaticBody2D
	if floor_body == null:
		return
	# Replace flat floor with stepped ramp segments.
	for child in floor_body.get_children():
		floor_body.remove_child(child)
		child.free()

	var cols := maxi(ceili(size_px.x / tile), 1)
	var half_w := size_px.x * 0.5
	# Outward direction is opposite of inland.
	var outward := -inland_dir if not is_zero_approx(inland_dir) else 1.0
	var inland_edge_x := -outward * half_w
	# Column 0 is the inland-most ocean tile (against the beach).
	for col in cols:
		var t := clampf(float(col) / float(maxi(FLOOR_RAMP_TILES - 1, 1)), 0.0, 1.0)
		var depth := lerpf(FLOOR_START_DEPTH_PX, FLOOR_DEEP_DEPTH_PX, t)
		var along0 := float(col) * tile
		var along1 := float(col + 1) * tile
		# First segment tucks inland under scum so the seam has no pit.
		if col == 0 and overlap > 0.0:
			along0 = -overlap
		var coll_inland_x := inland_edge_x + outward * along0
		var coll_outward_x := inland_edge_x + outward * along1
		var center_x := (coll_inland_x + coll_outward_x) * 0.5
		var coll_w := absf(coll_outward_x - coll_inland_x)

		var shape_node := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(coll_w, tile)
		shape_node.shape = rect
		# Visual top is at -size_px.y * 0.5; floor top sits depth below that.
		var top_y := -size_px.y * 0.5 + depth
		shape_node.position = Vector2(center_x, top_y + tile * 0.5)
		floor_body.add_child(shape_node)


func _build_ocean_visual(size_px: Vector2, inland_dir: float, tile: float) -> void:
	var stale: Array[Node] = []
	for child in get_children():
		if child is Sprite2D or child is Polygon2D or child.name == "AcidUnderlay" or child.name == "AcidBlendLip":
			stale.append(child)
	for child in stale:
		remove_child(child)
		child.free()

	var outward := -inland_dir if not is_zero_approx(inland_dir) else 1.0
	var half := size_px * 0.5
	var blend_w := BLEND_INLAND_TILES * tile

	# Soft lip tucked under beach scum so the acid edge is not a hard rectangle.
	if blend_w > 0.0 and not is_zero_approx(inland_dir):
		var lip := Polygon2D.new()
		lip.name = "AcidBlendLip"
		var inland_edge := -outward * half.x
		var x_in := inland_edge + inland_dir * blend_w
		var x_out := inland_edge
		lip.polygon = PackedVector2Array([
			Vector2(x_in, -half.y + FLOOR_START_DEPTH_PX * 0.35),
			Vector2(x_out, -half.y),
			Vector2(x_out, half.y),
			Vector2(x_in, half.y),
		])
		lip.color = Color(0.28, 0.78, 0.18, 0.55)
		lip.z_index = -2
		add_child(lip)

	# Solid toxic underlay so the shore never reads as empty navy clear-color void.
	var underlay := Polygon2D.new()
	underlay.name = "AcidUnderlay"
	underlay.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])
	underlay.color = Color(0.28, 0.78, 0.18, 0.92)
	underlay.z_index = -1
	add_child(underlay)

	var tex := PlaceholderAcidOcean.create_texture()
	var cols := maxi(ceili(size_px.x / tile), 1)
	var rows := maxi(ceili(size_px.y / tile), 1)
	var atlas_cols := PlaceholderAcidOcean.COLS
	var atlas_rows := PlaceholderAcidOcean.ROWS
	var origin := -size_px * 0.5
	for row in rows:
		for col in cols:
			# col 0 = left of visual; map to inland-most for depth paint + blend fade.
			var from_inland := col if outward > 0.0 else (cols - 1 - col)
			var sprite := Sprite2D.new()
			sprite.texture = tex
			sprite.hframes = atlas_cols
			sprite.vframes = atlas_rows
			# Surface row 0 on the waterline; fill row 1 stacked underneath.
			var atlas_row := 0 if row == 0 else 1
			# Columns deepen outward: shallow → mid → deep → abyss.
			var atlas_col := clampi(from_inland, 0, atlas_cols - 1)
			sprite.frame = atlas_row * atlas_cols + atlas_col
			sprite.centered = true
			var depth_nudge := 0.0
			if from_inland < FLOOR_RAMP_TILES:
				var t := float(from_inland) / float(maxi(FLOOR_RAMP_TILES - 1, 1))
				depth_nudge = lerpf(FLOOR_START_DEPTH_PX, FLOOR_DEEP_DEPTH_PX, t) * 0.25
			sprite.position = origin + Vector2((col + 0.5) * tile, (row + 0.5) * tile + depth_nudge)
			sprite.z_index = 0
			# Soften the inland-most column so acid melts into shallow-blend instead of a hard cut.
			var alpha := 1.0 if from_inland > 0 else 0.72
			sprite.modulate = Color(1.15, 1.35, 1.05, alpha)
			add_child(sprite)


func _physics_process(delta: float) -> void:
	if _accum.is_empty():
		return
	var dead: Array = []
	for id in _accum.keys():
		var body := instance_from_id(id) as Node
		if body == null or not is_instance_valid(body):
			dead.append(id)
			continue
		if not _is_damageable(body):
			continue
		_accum[id] = float(_accum[id]) + DPS * delta
		var dealt := int(_accum[id])
		if dealt > 0 and body.has_method("take_damage"):
			body.take_damage(dealt)
			_accum[id] = float(_accum[id]) - float(dealt)
	for id in dead:
		_accum.erase(id)


func _on_body_entered(body: Node2D) -> void:
	if not _is_damageable(body):
		return
	_accum[body.get_instance_id()] = 0.0
	if body.has_method("notify_acid_entered"):
		body.notify_acid_entered()


func _on_body_exited(body: Node2D) -> void:
	_accum.erase(body.get_instance_id())
	if body.has_method("notify_acid_exited"):
		body.notify_acid_exited()


func _is_damageable(body: Node) -> bool:
	return body.is_in_group("player") or body.is_in_group("hiree")
