class_name PlaceholderThrowGlob
extends RefCounted

## Lobbed acid glob: 16×16 at throw_glob.png.
const SIZE := Vector2i(16, 16)
const TEXTURE_PATH := "res://Assets/sprites/throw_glob.png"


static func create_texture() -> Texture2D:
	return load(TEXTURE_PATH) as Texture2D
