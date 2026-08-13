class_name PlaceholderWell
extends RefCounted

const WIDTH_TILES := 2
const HEIGHT_TILES := 2
const TILE := PlaceholderTileset.TILE_SIZE
const SIZE := Vector2i(TILE * WIDTH_TILES, TILE * HEIGHT_TILES)
const SPRITE_OFFSET := Vector2(0, -SIZE.y * 0.5)


static func create_texture() -> ImageTexture:
	var image := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	var stone := Color("7a7a82")
	var stone_dark := Color("5c5c64")
	var border := Color("2a2a30")
	var water := Color("3d6ea8")
	var water_dark := Color("2a4d78")
	var wood := Color("8a5a32")

	for y in SIZE.y:
		for x in SIZE.x:
			var pixel := Color(0, 0, 0, 0)
			var in_rim: bool = y >= 8 and y <= SIZE.y - 1
			if in_rim:
				pixel = stone if ((x + y) % 6) != 0 else stone_dark
				if x == 0 or x == SIZE.x - 1 or y == 8 or y == SIZE.y - 1:
					pixel = border
			if x >= 8 and x <= SIZE.x - 9 and y >= 12 and y <= SIZE.y - 5:
				pixel = water_dark if ((x + y) % 4) == 0 else water
			if y >= 0 and y <= 7 and (x == 6 or x == 7 or x == SIZE.x - 8 or x == SIZE.x - 7):
				pixel = wood
			if y >= 0 and y <= 2 and x >= 6 and x <= SIZE.x - 7:
				pixel = wood
			image.set_pixel(x, y, pixel)

	return ImageTexture.create_from_image(image)
