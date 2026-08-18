class_name PlaceholderDrill
extends RefCounted

const WIDTH_TILES := 2
const HEIGHT_TILES := 2
const TILE := PlaceholderTileset.TILE_SIZE
const SIZE := Vector2i(TILE * WIDTH_TILES, TILE * HEIGHT_TILES)
const SPRITE_OFFSET := Vector2(0, -SIZE.y * 0.5)


static func create_texture() -> ImageTexture:
	var image := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	var body := Color("c4862a")
	var dark := Color("7a4e16")
	var border := Color("2a1c0c")
	var highlight := Color("e8b45a")
	var bit := Color("5a6570")

	for y in SIZE.y:
		for x in SIZE.x:
			var pixel := body
			if x == 0 or y == 0 or x == SIZE.x - 1 or y == SIZE.y - 1:
				pixel = border
			elif y >= SIZE.y - 6 and x >= 12 and x <= 19:
				pixel = bit if (x + y) % 2 == 0 else dark
			elif x == 2 or y == 2:
				pixel = highlight
			elif y % 8 == 0 or x == SIZE.x / 2:
				pixel = dark
			image.set_pixel(x, y, pixel)

	return ImageTexture.create_from_image(image)
