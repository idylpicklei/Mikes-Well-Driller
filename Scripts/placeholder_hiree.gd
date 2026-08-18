class_name PlaceholderHiree
extends RefCounted

const SIZE := Vector2i(16, 32)
const SPRITE_OFFSET := Vector2(0, -SIZE.y * 0.5)
const TEXTURE_PATH := "res://Assets/sprites/hiree.png"


static func create_texture() -> Texture2D:
	return load(TEXTURE_PATH) as Texture2D
