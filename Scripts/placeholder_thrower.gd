class_name PlaceholderThrower
extends RefCounted

## Thrower sheet: 192×32 — four 32×32 walk + two throw (windup, release).
## Artist drop-in: binary-replace enemy_thrower.png; load path stays the same.
const FRAME_COUNT := 6
const WALK_FRAMES := 4
const WINDUP_FRAME := 4
const RELEASE_FRAME := 5
const SIZE := Vector2i(32, 32)
const SPRITE_OFFSET := Vector2(0, -SIZE.y * 0.5)
const TEXTURE_PATH := "res://Assets/sprites/enemy_thrower.png"
const WALK_FPS := 6.0

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
	## Solid-color placeholder: teal body, darker rim, windup/release pose hints.
	var image := Image.create(SIZE.x * FRAME_COUNT, SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var body := Color(0.28, 0.62, 0.48, 1.0)
	var rim := Color(0.12, 0.32, 0.26, 1.0)
	var accent := Color(0.72, 0.86, 0.42, 1.0)
	for frame in FRAME_COUNT:
		var ox := frame * SIZE.x
		_fill_rect(image, ox, 0, SIZE.x, SIZE.y, rim)
		_fill_rect(image, ox + 1, 1, SIZE.x - 2, SIZE.y - 2, body)
		# Walking shift: a small foot block that steps across frames 0–3.
		if frame < WALK_FRAMES:
			var step := 4 + (frame % 2) * 8
			_fill_rect(image, ox + step, SIZE.y - 8, 10, 6, rim)
			_fill_rect(image, ox + 18 - (frame % 2) * 6, SIZE.y - 8, 8, 6, rim.darkened(0.15))
		elif frame == WINDUP_FRAME:
			# Raised lob arm (windup hold).
			_fill_rect(image, ox + 20, 2, 8, 14, accent)
			_fill_rect(image, ox + 22, 2, 4, 4, rim)
		else:
			# Forward release pose.
			_fill_rect(image, ox + 22, 10, 10, 6, accent)
			_fill_rect(image, ox + 28, 10, 3, 6, rim)
	return image


static func _fill_rect(image: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for py in range(y, y + h):
		for px in range(x, x + w):
			if px >= 0 and py >= 0 and px < image.get_width() and py < image.get_height():
				image.set_pixel(px, py, color)
