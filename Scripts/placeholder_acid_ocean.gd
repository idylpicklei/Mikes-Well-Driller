class_name PlaceholderAcidOcean
extends RefCounted

## Acid ocean atlas: 4 cols × 2 rows of 16×16 (64×32).
## Row 0: surface shallow → mid → deep → abyss. Row 1: fill (no foam).
## Artist drop-in: binary-replace acid_ocean.png; load path stays the same.
## Source art is dark; brighten at load so it reads as poison water against the sky clear color.
const TILE := PlaceholderTileset.TILE_SIZE
const COLS := 4
const ROWS := 2
const TILE_COUNT := COLS ## Surface-row column count (shallow→abyss).
const SIZE := Vector2i(TILE * COLS, TILE * ROWS)
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
		Color(0.18, 0.55, 0.14, 1.0),
		Color(0.08, 0.28, 0.10, 1.0),
	]
	for row in ROWS:
		for col in COLS:
			var ox := col * TILE
			var oy := row * TILE
			var base: Color = colors[col]
			if row == 1:
				base = base.darkened(0.25)
			for y in TILE:
				for x in TILE:
					var pixel := base.lightened(0.08) if ((x + y + col * 3) % 5) == 0 else base
					if row == 0 and y < 2:
						pixel = pixel.lightened(0.2)
					image.set_pixel(ox + x, oy + y, pixel)
	return image
