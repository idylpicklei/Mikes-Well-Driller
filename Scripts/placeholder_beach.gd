class_name PlaceholderBeach
extends RefCounted

## Shore strip: dry | wet | scum | shallow-blend — four 16×16 tiles.
## Artist drop-in: binary-replace beach.png (keep 4×16 atlas); load path stays the same.
const TILE := PlaceholderTileset.TILE_SIZE
const TILE_COUNT := 4
const SIZE := Vector2i(TILE * TILE_COUNT, TILE)
const TEXTURE_PATH := "res://Assets/sprites/beach.png"


static func create_texture() -> Texture2D:
	return load(TEXTURE_PATH) as Texture2D
