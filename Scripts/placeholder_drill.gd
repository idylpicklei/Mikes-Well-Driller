class_name PlaceholderDrill
extends RefCounted

const WIDTH_TILES := 2
const HEIGHT_TILES := 2
const TILE := PlaceholderTileset.TILE_SIZE
const SIZE := Vector2i(TILE * WIDTH_TILES, TILE * HEIGHT_TILES)
const SPRITE_OFFSET := Vector2(0, -SIZE.y * 0.5)
const TEXTURE_PATH := "res://Assets/sprites/drill.png"


static func create_texture() -> Texture2D:
	return load(TEXTURE_PATH) as Texture2D
