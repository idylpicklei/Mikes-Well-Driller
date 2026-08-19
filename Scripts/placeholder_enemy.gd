class_name PlaceholderEnemy
extends RefCounted

## Copper-gauge invader walk sheet: 256×64, four 64×64 frames.
const FRAME_COUNT := 4
const SIZE := Vector2i(64, 64)
## No leftover Sprite scale=2 in code — verified. Full-bleed copper fills the
## 64 cell while Mike’s silhouette is ~32–40px inside his 64 cell, so native
## 1:1 reads as a boss. Draw the 64 sheet at half size for peer height (same
## footprint as the old 32×32 crabs / on-screen Mike).
const DISPLAY_SCALE := 0.5
## Art has a few empty rows under the copper feet inside the 64 cell.
## Nudge the centered sprite so those feet sit on the CharacterBody2D origin.
const FOOT_PAD := 4
const SPRITE_OFFSET := Vector2(0, -DISPLAY_SCALE * (SIZE.y * 0.5 - FOOT_PAD))
## Contact/hurtbox = scaled copper body (source ~28×36), feet at origin.
const COLLISION_SIZE := Vector2(14, 18)
const COLLISION_OFFSET := Vector2(0, -COLLISION_SIZE.y * 0.5)
const TEXTURE_PATH := "res://Assets/sprites/enemy.png"
const WALK_FPS := 8.0


static func create_texture() -> Texture2D:
	return load(TEXTURE_PATH) as Texture2D
