class_name PlaceholderAcidOcean
extends RefCounted

## Acid ocean strip: three 16×16 tiles for map-edge water, separate from PlaceholderTileset.
const TILE := PlaceholderTileset.TILE_SIZE
const TILE_COUNT := 3
const SIZE := Vector2i(TILE * TILE_COUNT, TILE)
const TEXTURE_PATH := "res://Assets/sprites/acid_ocean.png"
const DAMAGE_PER_SECOND := 5.0


static func create_texture() -> Texture2D:
	return load(TEXTURE_PATH) as Texture2D
