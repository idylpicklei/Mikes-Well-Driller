extends Node2D


func _ready() -> void:
	add_to_group("well")
	z_index = 1
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.texture = PlaceholderWell.create_texture()
		sprite.position = PlaceholderWell.SPRITE_OFFSET
