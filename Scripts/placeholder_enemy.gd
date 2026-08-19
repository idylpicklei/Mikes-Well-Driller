class_name PlaceholderEnemy
extends RefCounted

## Copper-gauge invader walk sheet: 256×64, four 64×64 frames.
const FRAME_COUNT := 4
const SIZE := Vector2i(64, 64)
const SPRITE_OFFSET := Vector2(0, -SIZE.y * 0.5)
const TEXTURE_PATH := "res://Assets/sprites/enemy.png"
const WALK_FPS := 8.0


static func create_texture() -> Texture2D:
	return load(TEXTURE_PATH) as Texture2D
