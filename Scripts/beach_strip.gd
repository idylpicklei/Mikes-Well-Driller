extends StaticBody2D

## Walkable shore at the map edge: dry → wet → scum, then acid ocean beyond.


func setup(outward: float, overlap_px: float = 0.0) -> void:
	## outward: -1 left edge (tiles extend left), +1 right edge.
	## overlap_px tucks collision inland under the last grass tile so the seam has no pit.
	var tile := float(PlaceholderTileset.TILE_SIZE)
	var tex := PlaceholderBeach.create_texture()
	var count := PlaceholderBeach.TILE_COUNT
	var width_px := float(count) * tile
	var overlap := maxf(overlap_px, 0.0)
	var coll_w := width_px + overlap

	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		add_child(shape_node)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(coll_w, tile)
	shape_node.shape = rect
	# Span from inland overlap through the outward beach face (sprites stay at the map edge).
	shape_node.position = Vector2(outward * (width_px - overlap) * 0.5, tile * 0.5)

	for i in count:
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.hframes = count
		sprite.frame = i  # dry → wet → scum going outward
		sprite.centered = true
		var along := (i + 0.5) * tile
		sprite.position = Vector2(outward * along, tile * 0.5)
		sprite.z_index = 0
		add_child(sprite)
