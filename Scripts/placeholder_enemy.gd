class_name PlaceholderEnemy
extends RefCounted

const SIZE := Vector2i(12, 16)
const SPRITE_OFFSET := Vector2(0, -SIZE.y * 0.5)


static func create_texture() -> ImageTexture:
	var image := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	var body := Color("c44c4c")
	var border := Color("4a1414")
	var eye := Color("f2e6a0")

	for y in SIZE.y:
		for x in SIZE.x:
			var pixel := body
			if x == 0 or y == 0 or x == SIZE.x - 1 or y == SIZE.y - 1:
				pixel = border
			elif y == 5 and (x == 3 or x == 8):
				pixel = eye
			image.set_pixel(x, y, pixel)

	return ImageTexture.create_from_image(image)
