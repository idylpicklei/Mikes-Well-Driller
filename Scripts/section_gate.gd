extends StaticBody2D

## Solid section gate past an alien ship. Freed when that ship dies.


func _ready() -> void:
	add_to_group("section_gate")
	z_index = 1
	collision_layer = 1
	collision_mask = 1
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.texture = _make_texture()
		sprite.centered = true
		sprite.position = Vector2(0, -40)


func _make_texture() -> ImageTexture:
	var size := Vector2i(16, 80)
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var body := Color("4a3a2a")
	var border := Color("1a1410")
	var stripe := Color("6a5238")
	for y in size.y:
		for x in size.x:
			var pixel := body
			if x == 0 or y == 0 or x == size.x - 1 or y == size.y - 1:
				pixel = border
			elif (y % 10) < 2:
				pixel = stripe
			image.set_pixel(x, y, pixel)
	return ImageTexture.create_from_image(image)
