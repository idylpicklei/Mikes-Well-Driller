class_name PlaceholderEnemy
extends RefCounted

## Copper-gauge invader walk sheet: 256×64, four 64×64 frames.
const FRAME_COUNT := 4
const SIZE := Vector2i(64, 64)
## Art has a few empty rows under the copper feet inside the 64 cell.
## Nudge the centered sprite so those feet sit on the CharacterBody2D origin.
const FOOT_PAD := 4
const SPRITE_OFFSET := Vector2(0, -SIZE.y * 0.5 + FOOT_PAD)
## Contact/hurtbox = visible copper body, not the empty 64×64 cell air.
const COLLISION_SIZE := Vector2(28, 36)
const COLLISION_OFFSET := Vector2(0, -COLLISION_SIZE.y * 0.5)
const TEXTURE_PATH := "res://Assets/sprites/enemy.png"
const WALK_FPS := 8.0


static func create_texture() -> Texture2D:
	return load(TEXTURE_PATH) as Texture2D
