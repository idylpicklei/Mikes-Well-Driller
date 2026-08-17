extends Area2D


func _ready() -> void:
	add_to_group("acid")
	collision_layer = 0
	collision_mask = 1
	monitorable = false
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func setup(size_px: Vector2) -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.centered = true
		sprite.texture = PlaceholderAcid.create_texture(Vector2i(maxi(int(size_px.x), 2), maxi(int(size_px.y), 2)))
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node:
		var rect := RectangleShape2D.new()
		rect.size = size_px
		shape_node.shape = rect


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("respawn"):
		body.respawn()
	elif body.is_in_group("enemy"):
		body.queue_free()
