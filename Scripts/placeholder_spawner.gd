class_name PlaceholderSpawner
extends RefCounted

const WIDTH_TILES := 2
const HEIGHT_TILES := 2
const TILE := PlaceholderTileset.TILE_SIZE
const SIZE := Vector2i(TILE * WIDTH_TILES, TILE * HEIGHT_TILES)
const SPRITE_OFFSET := Vector2(0, -SIZE.y * 0.5)


static func create_texture() -> ImageTexture:
	var image := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	var body := Color("8a2d2d")
	var pit := Color("1a0c0c")
	var border := Color("3a1010")
	var accent := Color("e85d5d")

	for y in SIZE.y:
		for x in SIZE.x:
			var pixel := body
			if x == 0 or y == 0 or x == SIZE.x - 1 or y == SIZE.y - 1:
				pixel = border
			elif x >= 10 and x <= SIZE.x - 11 and y >= 10 and y <= SIZE.y - 11:
				pixel = pit
			elif (x + y) % 8 == 0:
				pixel = accent
			image.set_pixel(x, y, pixel)

	return ImageTexture.create_from_image(image)
