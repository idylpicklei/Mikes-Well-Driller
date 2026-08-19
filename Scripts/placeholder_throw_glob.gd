class_name PlaceholderThrowGlob
extends RefCounted

## Lobbed acid glob: planned 12×12 drop-in at throw_glob.png.
const SIZE := Vector2i(12, 12)
const TEXTURE_PATH := "res://Assets/sprites/throw_glob.png"

static var _cached: Texture2D


static func create_texture() -> Texture2D:
	if _cached:
		return _cached
	if ResourceLoader.exists(TEXTURE_PATH):
		_cached = load(TEXTURE_PATH) as Texture2D
		if _cached:
			return _cached
	_cached = ImageTexture.create_from_image(_make_fallback())
	return _cached


static func _make_fallback() -> Image:
	var image := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var rim := Color(0.18, 0.42, 0.16, 1.0)
	var core := Color(0.45, 0.88, 0.28, 1.0)
	for y in SIZE.y:
		for x in SIZE.x:
			var cx := x - SIZE.x * 0.5 + 0.5
			var cy := y - SIZE.y * 0.5 + 0.5
			var r2 := cx * cx + cy * cy
			if r2 <= 5.5 * 5.5:
				image.set_pixel(x, y, rim if r2 > 3.8 * 3.8 else core)
	return image
