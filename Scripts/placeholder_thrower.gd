class_name PlaceholderThrower
extends RefCounted

## Thrower sheet: 192×32 — four 32×32 walk + two throw (windup, release).
## Frames: 0–3 walk, 4 windup hold, 5 release.
const FRAME_COUNT := 6
const WALK_FRAMES := 4
const WINDUP_FRAME := 4
const RELEASE_FRAME := 5
const SIZE := Vector2i(32, 32)
const SPRITE_OFFSET := Vector2(0, -SIZE.y * 0.5)
const TEXTURE_PATH := "res://Assets/sprites/enemy_thrower.png"
const WALK_FPS := 6.0


static func create_texture() -> Texture2D:
	return load(TEXTURE_PATH) as Texture2D
