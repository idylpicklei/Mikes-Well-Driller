class_name PlaceholderEnemy
extends RefCounted

## Crab alien walk sheet: 128×32, four 32×32 frames.
const FRAME_COUNT := 4
const SIZE := Vector2i(32, 32)
const SPRITE_OFFSET := Vector2(0, -SIZE.y * 0.5)
const TEXTURE_PATH := "res://Assets/sprites/enemy.png"
const WALK_FPS := 8.0


static func create_texture() -> Texture2D:
	return load(TEXTURE_PATH) as Texture2D
