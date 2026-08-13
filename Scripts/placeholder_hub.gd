class_name PlaceholderHub
extends RefCounted

const WIDTH_TILES := 3
const HEIGHT_TILES := 2
const TILE := PlaceholderTileset.TILE_SIZE
const SIZE := Vector2i(TILE * WIDTH_TILES, TILE * HEIGHT_TILES)
const SPRITE_OFFSET := Vector2(0, -SIZE.y * 0.5)


static func create_texture() -> ImageTexture:
	var image := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	var body := Color("2f9e8f")
	var core := Color("7ee8dc")
	var border := Color("163d38")
	var grid := Color("1d524c")
	var accent := Color("ffd166")

	for y in SIZE.y:
		for x in SIZE.x:
			var pixel := body
			if x == 0 or y == 0 or x == SIZE.x - 1 or y == SIZE.y - 1:
				pixel = border
			elif x % TILE == 0 or y % TILE == 0:
				pixel = grid
			elif x >= 18 and x <= 29 and y >= 8 and y <= 19:
				pixel = core
			elif y == 3 and x % 6 == 0:
				pixel = accent
			image.set_pixel(x, y, pixel)

	return ImageTexture.create_from_image(image)
