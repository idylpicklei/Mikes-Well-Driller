class_name PlaceholderTank
extends RefCounted

## Clean / poisoned tank overlay on the Main Hub (origin at feet).
const SIZE := Vector2i(16, 24)
const SPRITE_OFFSET := Vector2(0, -SIZE.y * 0.5)
const TEXTURE_PATH := "res://Assets/sprites/tank.png"
const POISONED_TEXTURE_PATH := "res://Assets/sprites/tank_poisoned.png"


static func create_texture() -> Texture2D:
	return load(TEXTURE_PATH) as Texture2D


static func create_poisoned_texture() -> Texture2D:
	return load(POISONED_TEXTURE_PATH) as Texture2D
