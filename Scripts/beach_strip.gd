extends StaticBody2D

## Walkable shore at the map edge: dry → wet → scum → shallow-blend, then acid ocean beyond.
## Collision steps down so the approach is a wade ramp, not a flat ledge.
## Artist drop-in: replace Assets/sprites/beach.png (same 4×16 layout); no code change.

## Depth below grass surface for dry | wet | scum | shallow-blend (pixels).
const DEPTHS_PX := [0.0, 4.0, 8.0, 12.0]
## Soft acid wash under wet/scum/shallow-blend so poison blends into sand (current tiles stay on top).
const BLEND_COLOR := Color(0.28, 0.78, 0.18, 0.35)


func setup(outward: float, overlap_px: float = 0.0) -> void:
	## outward: -1 left edge (tiles extend left), +1 right edge.
	## overlap_px tucks dry-sand collision inland under the last grass tile (no pit).
	var tile := float(PlaceholderTileset.TILE_SIZE)
	var tex := PlaceholderBeach.create_texture()
	var count := PlaceholderBeach.TILE_COUNT
	var overlap := maxf(overlap_px, 0.0)

	# Drop any prior shapes/sprites; rebuild ramp immediately (not deferred).
	for child in get_children():
		remove_child(child)
		child.free()

	_build_acid_blend(outward, tile, count)
	_build_ramp_collision(outward, tile, count, overlap)
	_build_sprites(outward, tile, count, tex)


func _build_acid_blend(outward: float, tile: float, count: int) -> void:
	# Wash starts under wet sand and covers scum + shallow-blend so the ocean edge is not a hard rectangle.
	if count < 2:
		return
	var blend := Polygon2D.new()
	blend.name = "AcidBlend"
	var start := 1.0 * tile  # from wet
	var end := float(count) * tile
	var top: float = float(DEPTHS_PX[1])
	var bot: float = float(DEPTHS_PX[mini(count - 1, DEPTHS_PX.size() - 1)]) + tile
	var x0 := outward * start
	var x1 := outward * end
	blend.polygon = PackedVector2Array([
		Vector2(x0, top), Vector2(x1, top), Vector2(x1, bot), Vector2(x0, bot),
	])
	blend.color = BLEND_COLOR
	blend.z_index = -1
	add_child(blend)


func _build_ramp_collision(outward: float, tile: float, count: int, overlap: float) -> void:
	for i in count:
		var depth: float = DEPTHS_PX[mini(i, DEPTHS_PX.size() - 1)]
		var along0 := float(i) * tile
		var along1 := float(i + 1) * tile
		var coll_w := tile
		var center_along := (along0 + along1) * 0.5
		# Dry tile also covers the inland overlap under grass.
		if i == 0 and overlap > 0.0:
			coll_w = tile + overlap
			center_along = (along1 - overlap) * 0.5
		var shape_node := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(coll_w, tile)
		shape_node.shape = rect
		shape_node.position = Vector2(outward * center_along, depth + tile * 0.5)
		add_child(shape_node)


func _build_sprites(outward: float, tile: float, count: int, tex: Texture2D) -> void:
	for i in count:
		var depth: float = DEPTHS_PX[mini(i, DEPTHS_PX.size() - 1)]
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.hframes = count
		sprite.frame = i  # dry → wet → scum → shallow-blend going outward
		sprite.centered = true
		var along := (i + 0.5) * tile
		sprite.position = Vector2(outward * along, depth + tile * 0.5)
		sprite.z_index = 0
		add_child(sprite)
