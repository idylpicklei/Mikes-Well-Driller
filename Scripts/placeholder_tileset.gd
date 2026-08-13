class_name PlaceholderTileset
extends RefCounted

## Colored 16x16 tiles. Swap the atlas later without changing tile order:
## 0 grass, 1 dirt, 2 dirt dark, 3 stone, 4 stone dark, 5 bedrock
const TILE_SIZE := 16
const TILE_COUNT := 6

const GRASS := Vector2i(0, 0)
const DIRT := Vector2i(1, 0)
const DIRT_DARK := Vector2i(2, 0)
const STONE := Vector2i(3, 0)
const STONE_DARK := Vector2i(4, 0)
const BEDROCK := Vector2i(5, 0)

const _COLORS: Array[Color] = [
	Color("5aad3a"),
	Color("8a5a32"),
	Color("6e4728"),
	Color("7a7a82"),
	Color("5c5c64"),
	Color("2a2a30"),
]


static func build(texture: Texture2D = null) -> TileSet:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tileset.add_physics_layer()
	tileset.set_physics_layer_collision_layer(0, 1)
	tileset.set_physics_layer_collision_mask(0, 1)

	var atlas := TileSetAtlasSource.new()
	atlas.texture = texture if texture else ImageTexture.create_from_image(_make_atlas())
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tileset.add_source(atlas, 0)

	var half := TILE_SIZE * 0.5
	var collision := PackedVector2Array([
		Vector2(-half, -half),
		Vector2(half, -half),
		Vector2(half, half),
		Vector2(-half, half),
	])
	for i in TILE_COUNT:
		var coords := Vector2i(i, 0)
		atlas.create_tile(coords)
		var tile: TileData = atlas.get_tile_data(coords, 0)
		tile.add_collision_polygon(0)
		tile.set_collision_polygon_points(0, 0, collision)
	return tileset


static func _make_atlas() -> Image:
	var image := Image.create(TILE_SIZE * TILE_COUNT, TILE_SIZE, false, Image.FORMAT_RGBA8)
	for i in TILE_COUNT:
		_paint_tile(image, i, _COLORS[i])
	return image


static func _paint_tile(image: Image, index: int, color: Color) -> void:
	var ox := index * TILE_SIZE
	var border := color.darkened(0.35)
	var hatch := color.lightened(0.12)
	for y in TILE_SIZE:
		for x in TILE_SIZE:
			var pixel := color
			if x == 0 or y == 0 or x == TILE_SIZE - 1 or y == TILE_SIZE - 1:
				pixel = border
			elif index == 0 and y < 4:
				pixel = Color("7ed957")
			elif ((x + y) % 6) == 0:
				pixel = hatch
			image.set_pixel(ox + x, y, pixel)
