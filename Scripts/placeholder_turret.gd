class_name PlaceholderTurret
extends RefCounted

## Procedural stand-in until turret.png lands. 2x2 footprint like the Basic Drill.
const WIDTH_TILES := 2
const HEIGHT_TILES := 2
const TILE := PlaceholderTileset.TILE_SIZE
const SIZE := Vector2i(TILE * WIDTH_TILES, TILE * HEIGHT_TILES)
const SPRITE_OFFSET := Vector2(0, -SIZE.y * 0.5)


static func create_texture() -> ImageTexture:
	var image := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	var body := Color("3d6ea8")
	var dark := Color("2a4a72")
	var barrel := Color("c8d4e0")
	var border := Color("1a2a3c")
	var accent := Color("7aa0d0")

	for y in SIZE.y:
		for x in SIZE.x:
			var pixel := Color(0, 0, 0, 0)
			var on_base := y >= 24 and x >= 4 and x <= 27
			var on_pedestal := y >= 16 and y < 24 and x >= 10 and x <= 21
			var on_head := y >= 6 and y < 16 and x >= 8 and x <= 23
			var on_barrel := y >= 9 and y <= 12 and x >= 22 and x <= 30
			if on_base:
				pixel = dark
			elif on_pedestal:
				pixel = body
			elif on_head:
				pixel = body
			elif on_barrel:
				pixel = barrel

			if pixel.a <= 0.0:
				image.set_pixel(x, y, pixel)
				continue

			var edge := (
				(on_base and (y == 24 or y == SIZE.y - 1 or x == 4 or x == 27))
				or (on_pedestal and (x == 10 or x == 21 or y == 16))
				or (on_head and (x == 8 or x == 23 or y == 6 or y == 15))
				or (on_barrel and (y == 9 or y == 12 or x == 30))
			)
			if edge:
				pixel = border
			elif on_head and x == 11 and y >= 8 and y <= 13:
				pixel = accent
			elif on_pedestal and (x == 13 or x == 18):
				pixel = dark

			image.set_pixel(x, y, pixel)

	return ImageTexture.create_from_image(image)
