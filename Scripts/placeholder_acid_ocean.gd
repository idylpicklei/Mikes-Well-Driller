class_name PlaceholderAcidOcean
extends RefCounted

## Acid ocean strip: three 16×16 tiles for map-edge water, separate from PlaceholderTileset.
## Artist drop-in: binary-replace acid_ocean.png (keep 3×16 atlas); load path stays the same.
## Source art is dark; brighten at load so it reads as poison water against the sky clear color.
const TILE := PlaceholderTileset.TILE_SIZE
const TILE_COUNT := 3
const SIZE := Vector2i(TILE * TILE_COUNT, TILE)
const TEXTURE_PATH := "res://Assets/sprites/acid_ocean.png"
const DAMAGE_PER_SECOND := 5.0
## Punch dark art into toxic green so it cannot read as empty navy/void.
const CONTRAST_LIFT := Color(1.55, 2.35, 1.15, 1.0)
const CONTRAST_ADD := Color(0.08, 0.22, 0.04, 0.0)

static var _cached: Texture2D


static func create_texture() -> Texture2D:
	if _cached:
		return _cached
	var src := load(TEXTURE_PATH) as Texture2D
	if src == null:
		_cached = ImageTexture.create_from_image(_make_fallback())
		return _cached
	var image := src.get_image()
	if image == null:
		_cached = src
		return _cached
	image.convert(Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			c = Color(
				clampf(c.r * CONTRAST_LIFT.r + CONTRAST_ADD.r, 0.0, 1.0),
				clampf(c.g * CONTRAST_LIFT.g + CONTRAST_ADD.g, 0.0, 1.0),
				clampf(c.b * CONTRAST_LIFT.b + CONTRAST_ADD.b, 0.0, 1.0),
				c.a
			)
			image.set_pixel(x, y, c)
	_cached = ImageTexture.create_from_image(image)
	return _cached


static func _make_fallback() -> Image:
	var image := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	var colors: Array[Color] = [
		Color(0.35, 0.85, 0.22, 1.0),
		Color(0.22, 0.72, 0.18, 1.0),
		Color(0.45, 0.95, 0.28, 1.0),
	]
	for i in TILE_COUNT:
		var ox := i * TILE
		var base: Color = colors[i]
		for y in TILE:
			for x in TILE:
				var pixel := base.lightened(0.08) if ((x + y + i * 3) % 5) == 0 else base
				if y < 2:
					pixel = pixel.lightened(0.2)
				image.set_pixel(ox + x, y, pixel)
	return image
