class_name PlaceholderTileset
extends RefCounted

## Colored 16x16 tiles. Atlas is 6 columns × 3 rows (96×48).
## Columns (do not reorder): 0 grass, 1 dirt, 2 dirt dark, 3 stone, 4 stone dark, 5 bedrock
## Rows 1–2 are visual variants of the same type; row 0 alone matches legacy ids.
const TILE_SIZE := 16
const TILE_COUNT := 6
const VARIANT_ROWS := 3

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
	for row in VARIANT_ROWS:
		for i in TILE_COUNT:
			var coords := Vector2i(i, row)
			atlas.create_tile(coords)
			var tile: TileData = atlas.get_tile_data(coords, 0)
			tile.add_collision_polygon(0)
			tile.set_collision_polygon_points(0, 0, collision)
	return tileset


## Atlas column id 0–5; ignores variant row.
static func type_id(coords: Vector2i) -> int:
	return coords.x


static func is_grass(coords: Vector2i) -> bool:
	return coords.x == GRASS.x


## Deterministic blend across rows 0–2 from world position + seed.
## Uses coarse cell blocks so variants form patches (reads as blend, not wallpaper).
static func variant_coords(column: int, cell_x: int, cell_y: int, world_seed: int) -> Vector2i:
	var block_x := int(floor(float(cell_x) / 3.0))
	var block_y := int(floor(float(cell_y) / 2.0))
	var h := int(hash(Vector3i(block_x, block_y, world_seed ^ (column * 131))))
	var row := absi(h) % VARIANT_ROWS
	# Neighbor jitter: occasional flip to an adjacent row so seams soften.
	var jitter := int(hash(Vector3i(cell_x, cell_y, world_seed + 17)))
	if absi(jitter) % 5 == 0:
		row = (row + 1) % VARIANT_ROWS
	return Vector2i(column, row)


static func _make_atlas() -> Image:
	var image := Image.create(TILE_SIZE * TILE_COUNT, TILE_SIZE * VARIANT_ROWS, false, Image.FORMAT_RGBA8)
	for row in VARIANT_ROWS:
		for i in TILE_COUNT:
			_paint_tile(image, i, row, _COLORS[i])
	return image


static func _paint_tile(image: Image, index: int, row: int, color: Color) -> void:
	var ox := index * TILE_SIZE
	var oy := row * TILE_SIZE
	var border := color.darkened(0.35)
	var hatch := color.lightened(0.12)
	var shift := row * 3
	for y in TILE_SIZE:
		for x in TILE_SIZE:
			var pixel := color
			if x == 0 or y == 0 or x == TILE_SIZE - 1 or y == TILE_SIZE - 1:
				pixel = border
			elif index == 0 and y < 4:
				pixel = Color("7ed957")
			elif ((x + y + shift) % 6) == 0:
				pixel = hatch
			image.set_pixel(ox + x, oy + y, pixel)
