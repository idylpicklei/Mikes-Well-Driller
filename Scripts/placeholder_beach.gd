class_name PlaceholderBeach
extends RefCounted

## Shore strip: dry | wet | scum — three 16×16 tiles, separate from PlaceholderTileset.
## Artist drop-in: binary-replace beach.png (keep 3×16 atlas); load path stays the same.
const TILE := PlaceholderTileset.TILE_SIZE
const TILE_COUNT := 3
const SIZE := Vector2i(TILE * TILE_COUNT, TILE)
const TEXTURE_PATH := "res://Assets/sprites/beach.png"


static func create_texture() -> Texture2D:
	return load(TEXTURE_PATH) as Texture2D
