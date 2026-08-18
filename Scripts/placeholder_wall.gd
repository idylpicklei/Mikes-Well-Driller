class_name PlaceholderWall
extends RefCounted

const WIDTH_TILES := 1
const HEIGHT_TILES := 2
const TILE := PlaceholderTileset.TILE_SIZE
const SIZE := Vector2i(TILE * WIDTH_TILES, TILE * HEIGHT_TILES)
const SPRITE_OFFSET := Vector2(0, -SIZE.y * 0.5)


static func create_texture() -> ImageTexture:
	var image := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	var body := Color("5a6a7a")
	var mortar := Color("3a4450")
	var border := Color("1e262e")
	var highlight := Color("8a9aaa")

	for y in SIZE.y:
		for x in SIZE.x:
			var pixel := body
			if x == 0 or y == 0 or x == SIZE.x - 1 or y == SIZE.y - 1:
				pixel = border
			elif y % 8 == 0 or (y / 8) % 2 == 0 and x % 8 == 0 or (y / 8) % 2 == 1 and x % 8 == 4:
				pixel = mortar
			elif x == 2 or y == 2:
				pixel = highlight
			image.set_pixel(x, y, pixel)

	return ImageTexture.create_from_image(image)
