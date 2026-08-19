class_name PlaceholderStore
extends RefCounted

## Found store: 64×48 art at Assets/sprites/store.png.
const WIDTH_TILES := 4
const HEIGHT_TILES := 3
const TILE := PlaceholderTileset.TILE_SIZE
const SIZE := Vector2i(TILE * WIDTH_TILES, TILE * HEIGHT_TILES)
const SPRITE_OFFSET := Vector2(0, -SIZE.y * 0.5)
const TEXTURE_PATH := "res://Assets/sprites/store.png"


static func create_texture() -> Texture2D:
	return load(TEXTURE_PATH) as Texture2D
