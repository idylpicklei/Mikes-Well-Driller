extends StaticBody2D


func _ready() -> void:
	add_to_group("wall")
	z_index = 1
	collision_layer = 1
	collision_mask = 1
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.texture = PlaceholderWall.create_texture()
		sprite.position = PlaceholderWall.SPRITE_OFFSET
