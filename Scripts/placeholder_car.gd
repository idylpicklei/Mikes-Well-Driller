class_name PlaceholderCar
extends RefCounted

## Abandoned cars: car_a 48×20, car_b 52×22. Mix variants in world gen.
enum Variant { A, B }

const TILE := PlaceholderTileset.TILE_SIZE
const SIZE_A := Vector2i(48, 20)
const SIZE_B := Vector2i(52, 22)
## Conservative occupancy box covering both variants.
const SIZE := SIZE_B
const TEXTURE_A := "res://Assets/sprites/car_a.png"
const TEXTURE_B := "res://Assets/sprites/car_b.png"


static func size_for(variant: Variant) -> Vector2i:
	return SIZE_A if variant == Variant.A else SIZE_B


static func width_tiles_for(variant: Variant) -> int:
	var w := size_for(variant).x
	return int(ceili(float(w) / float(TILE)))


static func height_tiles_for(variant: Variant) -> int:
	var h := size_for(variant).y
	return int(ceili(float(h) / float(TILE)))


static func sprite_offset_for(variant: Variant) -> Vector2:
	return Vector2(0, -size_for(variant).y * 0.5)


static func texture_path_for(variant: Variant) -> String:
	return TEXTURE_A if variant == Variant.A else TEXTURE_B


static func create_texture(variant: Variant = Variant.A) -> Texture2D:
	return load(texture_path_for(variant)) as Texture2D
