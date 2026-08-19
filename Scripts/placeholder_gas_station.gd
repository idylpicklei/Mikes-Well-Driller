class_name PlaceholderGasStation
extends RefCounted

## Abandoned gas station: 96×64 art at Assets/sprites/gas_station.png.
const WIDTH_TILES := 6
const HEIGHT_TILES := 4
const TILE := PlaceholderTileset.TILE_SIZE
const SIZE := Vector2i(TILE * WIDTH_TILES, TILE * HEIGHT_TILES)
const SPRITE_OFFSET := Vector2(0, -SIZE.y * 0.5)
const TEXTURE_PATH := "res://Assets/sprites/gas_station.png"


static func create_texture() -> Texture2D:
	return load(TEXTURE_PATH) as Texture2D
