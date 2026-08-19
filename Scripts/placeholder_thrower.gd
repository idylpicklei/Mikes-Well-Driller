class_name PlaceholderThrower
extends RefCounted

## Thrower sheet: 384×64 — four 64×64 walk + two throw (windup, release).
## Frames: 0–3 walk, 4 windup hold, 5 release.
const FRAME_COUNT := 6
const WALK_FRAMES := 4
const WINDUP_FRAME := 4
const RELEASE_FRAME := 5
const SIZE := Vector2i(64, 64)
## Match melee peer height (see PlaceholderEnemy.DISPLAY_SCALE).
const DISPLAY_SCALE := 0.5
## Same feet-origin pad as melee so both types stand on dirt.
const FOOT_PAD := 4
const SPRITE_OFFSET := Vector2(0, -DISPLAY_SCALE * (SIZE.y * 0.5 - FOOT_PAD))
## Contact/hurtbox = scaled copper body (source ~30×36), not release-frame arms.
const COLLISION_SIZE := Vector2(15, 18)
const COLLISION_OFFSET := Vector2(0, -COLLISION_SIZE.y * 0.5)
const TEXTURE_PATH := "res://Assets/sprites/enemy_thrower.png"
const WALK_FPS := 6.0


static func create_texture() -> Texture2D:
	return load(TEXTURE_PATH) as Texture2D
