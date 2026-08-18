class_name PlaceholderHiree
extends RefCounted

## Simple person silhouette — swap for hiree.png when art lands.
const SIZE := Vector2i(10, 16)
const SPRITE_OFFSET := Vector2(0, -SIZE.y * 0.5)
const BODY := Color("c4a574")
const SHIRT := Color("3d6ea8")
const BORDER := Color("1a1c1e")


static func create_texture() -> ImageTexture:
	var image := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	# Head
	_fill_rect(image, Rect2i(3, 1, 4, 4), BODY)
	# Torso
	_fill_rect(image, Rect2i(2, 5, 6, 6), SHIRT)
	# Legs
	_fill_rect(image, Rect2i(2, 11, 2, 4), Color("2a2e34"))
	_fill_rect(image, Rect2i(6, 11, 2, 4), Color("2a2e34"))
	# Outline
	for x in SIZE.x:
		for y in SIZE.y:
			var c := image.get_pixel(x, y)
			if c.a < 0.1:
				continue
			var edge := false
			for ox in range(-1, 2):
				for oy in range(-1, 2):
					if ox == 0 and oy == 0:
						continue
					var nx := x + ox
					var ny := y + oy
					if nx < 0 or ny < 0 or nx >= SIZE.x or ny >= SIZE.y:
						edge = true
						break
					if image.get_pixel(nx, ny).a < 0.1:
						edge = true
						break
				if edge:
					break
			if edge:
				image.set_pixel(x, y, BORDER)
	return ImageTexture.create_from_image(image)


static func _fill_rect(image: Image, rect: Rect2i, color: Color) -> void:
	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
				continue
			image.set_pixel(x, y, color)
