extends Area2D

## Acid ocean past the beach. Overlap ticks 5 HP/s on Mike and hires; leave to stop.

const DPS := PlaceholderAcidOcean.DAMAGE_PER_SECOND
## Character bodies sit above their feet — extend the hurt box above the waterline.
const HURT_ABOVE := 36.0

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
	_build_ocean_visual(size_px)
	var tile := float(PlaceholderTileset.TILE_SIZE)
	var overlap := maxf(inland_overlap_px, 0.0)
	var inland_dir := 0.0 if is_zero_approx(inland) else signf(inland)
	# Damage volume covers the water body plus a band above the surface for standing chars.
	var hurt_h := size_px.y + HURT_ABOVE
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node:
		var rect := RectangleShape2D.new()
		rect.size = Vector2(size_px.x + overlap, hurt_h)
		shape_node.shape = rect
		# Node origin is visual center; shift hurt box up so it clears the waterline.
		# Overlap extends inland under the beach so footing/DOT stay continuous.
		shape_node.position = Vector2(inland_dir * overlap * 0.5, -HURT_ABOVE * 0.5)
	# Shallow toxic footing so Mike can walk in and leave (DOT, not a pit).
	var floor_body := get_node_or_null("Floor") as StaticBody2D
	if floor_body:
		var floor_shape := floor_body.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if floor_shape:
			var floor_rect := RectangleShape2D.new()
			floor_rect.size = Vector2(size_px.x + overlap, tile)
			floor_shape.shape = floor_rect
			# Align floor top with the ocean surface (top of the visual).
			floor_shape.position = Vector2(inland_dir * overlap * 0.5, -size_px.y * 0.5 + tile * 0.5)


func _build_ocean_visual(size_px: Vector2) -> void:
	for child in get_children():
		if child is Sprite2D or child is Polygon2D or child.name == "AcidUnderlay":
			child.queue_free()

	# Solid toxic underlay so the shore never reads as empty navy clear-color void.
	var underlay := Polygon2D.new()
	underlay.name = "AcidUnderlay"
	var half := size_px * 0.5
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
	var tile := float(PlaceholderTileset.TILE_SIZE)
	var cols := maxi(ceili(size_px.x / tile), 1)
	var rows := maxi(ceili(size_px.y / tile), 1)
	var origin := -size_px * 0.5
	for row in rows:
		for col in cols:
			var sprite := Sprite2D.new()
			sprite.texture = tex
			sprite.hframes = PlaceholderAcidOcean.TILE_COUNT
			sprite.frame = col % PlaceholderAcidOcean.TILE_COUNT
			sprite.centered = true
			sprite.position = origin + Vector2((col + 0.5) * tile, (row + 0.5) * tile)
			sprite.z_index = 0
			sprite.modulate = Color(1.15, 1.35, 1.05, 1.0)
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


func _on_body_exited(body: Node2D) -> void:
	_accum.erase(body.get_instance_id())


func _is_damageable(body: Node) -> bool:
	return body.is_in_group("player") or body.is_in_group("hiree")
