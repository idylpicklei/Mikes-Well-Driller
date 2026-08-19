extends TileMapLayer

## Wide heightmap terrain. Tweak in the inspector; art can replace the
## placeholder atlas without changing these tile ids.
@export var world_seed: int = 0
## Extra-wide land strip: near ships for 1-min contact, far ships for the long walk.
## Sized for FAR_SPAWNER_TILES (~900) + jitter + ship footprint + a long run past each far ship.
@export var width: int = 2880
@export var bedrock_y: int = 42
@export var base_surface_y: int = 10
@export var hill_amplitude: int = 7
@export var dirt_depth: int = 8
@export var tileset_texture: Texture2D

const PLACEHOLDER_ATLAS := "res://Assets/sprites/terrain_tileset.png"

## Near ships: close enough that crabs reach the plateau ~1 minute after the 60s land.
const MIN_SPAWNER_TILES := 90
## Far ships: deep on the big map so there is still a long walk after first contact.
const FAR_SPAWNER_TILES := 900
## One found store on walkable ground, roughly this far from the start plateau.
const FOUND_STORE_TILES := 220
## Abandoned gas station further out than the store (~400–500 tiles).
const GAS_STATION_TILES := 450
## Scattered abandoned cars on grass (mix of two variants).
const ABANDONED_CAR_COUNT := 5
const SPAWNER_SIDE_CLEAR := 2
## Beach (dry|wet|scum|shallow-blend) then acid ocean past the map edge.
## Ocean is long enough to continue past the camera limit (no navy void at the edge).
const BEACH_TILES := 4
const OCEAN_TILES := 28
const OCEAN_DEPTH_TILES := 6
## Extra camera pad into the ocean — camera stops before the far water edge.
const CAMERA_SHORE_PAD_TILES := 4
## Ocean continues this many tiles past what the camera can reach.
const OCEAN_OFFSCREEN_TAIL_TILES := 8
const SHORE_MARGIN_TILES := BEACH_TILES + OCEAN_TILES
## Flat approach onto each shore so the last grass column meets beach at the same Y.
const EDGE_FLATTEN_TILES := 8
## Tuck beach/ocean floor collision under the prior strip so physics cannot fall through the seam.
const SHORE_OVERLAP_TILES := 1

var spawn_position := Vector2.ZERO

var _height_noise := FastNoiseLite.new()
var _fill_noise := FastNoiseLite.new()
var _cave_noise := FastNoiseLite.new()


func _ready() -> void:
	add_to_group("terrain")
	tile_set = PlaceholderTileset.build(_atlas_texture())
	_configure_noise()
	_generate()
	_setup_world()


func _atlas_texture() -> Texture2D:
	if tileset_texture:
		return tileset_texture
	if ResourceLoader.exists(PLACEHOLDER_ATLAS):
		return load(PLACEHOLDER_ATLAS)
	return null


func _configure_noise() -> void:
	var seed_value := world_seed if world_seed != 0 else randi()
	_height_noise.seed = seed_value
	_height_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_height_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_height_noise.fractal_octaves = 3
	_height_noise.frequency = 0.012

	_fill_noise.seed = seed_value + 17
	_fill_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_fill_noise.frequency = 0.08

	_cave_noise.seed = seed_value + 91
	_cave_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_cave_noise.fractal_octaves = 2
	_cave_noise.frequency = 0.06


func _generate() -> void:
	clear()
	for x in width:
		var surface := _surface_y(x)
		for y in range(surface, bedrock_y + 1):
			if _is_cave(x, y, surface):
				continue
			set_cell(Vector2i(x, y), 0, _atlas_at(x, y, surface))

	var spawn_x := int(width / 2.0)
	var spawn_cell := Vector2i(spawn_x, _surface_y(spawn_x))
	spawn_position = map_to_local(spawn_cell) + Vector2(0, -8)


func _raw_surface_y(x: int) -> int:
	var n := _height_noise.get_noise_1d(x)
	return base_surface_y + roundi(n * hill_amplitude)


func _surface_y(x: int) -> int:
	# Keep the last few columns flat and flush with the beach strip (no cliff into void).
	if x < EDGE_FLATTEN_TILES:
		return _raw_surface_y(0)
	if x >= width - EDGE_FLATTEN_TILES:
		return _raw_surface_y(width - 1)
	return _raw_surface_y(x)


func _atlas_at(x: int, y: int, surface: int) -> Vector2i:
	var column: int
	if y == bedrock_y:
		column = PlaceholderTileset.BEDROCK.x
	elif y == surface:
		column = PlaceholderTileset.GRASS.x
	else:
		var depth := y - surface
		var speck := _fill_noise.get_noise_2d(x, y)
		# Soft grass→dirt blend in the top dirt band (not a hard wallpaper stamp).
		if depth == 1:
			# Near-surface: mix dirt shades so the cut under grass reads blended.
			column = PlaceholderTileset.DIRT.x if speck > -0.05 else PlaceholderTileset.DIRT_DARK.x
		elif depth <= dirt_depth:
			column = PlaceholderTileset.DIRT_DARK.x if speck > 0.15 else PlaceholderTileset.DIRT.x
		elif speck > 0.25:
			column = PlaceholderTileset.STONE_DARK.x
		else:
			column = PlaceholderTileset.STONE.x
	# Coherent variant patches across rows 0–2 (not per-tile salt-and-pepper).
	return PlaceholderTileset.variant_coords(column, x, y, _height_noise.seed)


func _is_cave(x: int, y: int, surface: int) -> bool:
	if y <= surface + 3 or y >= bedrock_y - 1:
		return false
	return _cave_noise.get_noise_2d(x, y) > 0.55


func surface_cell_at(world_pos: Vector2) -> Vector2i:
	var cell := local_to_map(to_local(world_pos))
	if get_cell_source_id(cell) != -1:
		while get_cell_source_id(cell + Vector2i(0, -1)) != -1:
			cell += Vector2i(0, -1)
		return cell
	var probe := cell
	for _i in 32:
		probe += Vector2i(0, 1)
		if get_cell_source_id(probe) != -1:
			return probe
	return Vector2i(-999999, -999999)


func _setup_world() -> void:
	var game := get_parent()
	if game == null:
		return

	var player := game.get_node_or_null("Player")
	if player:
		player.global_position = spawn_position
		player.spawn_position = spawn_position
		# Below bedrock + ocean depth so shore / acid-floor walkers never trip fall_y.
		player.fall_y = float((bedrock_y + OCEAN_DEPTH_TILES + 8) * PlaceholderTileset.TILE_SIZE)

		var camera := player.get_node_or_null("Camera2D") as Camera2D
		if camera:
			var tile := PlaceholderTileset.TILE_SIZE
			# Camera reaches into the ocean but stops before the far water edge,
			# so acid continues off-screen (no navy void at the limit).
			var visible_ocean := maxi(OCEAN_TILES - OCEAN_OFFSCREEN_TAIL_TILES, BEACH_TILES + 4)
			var cam_pad := (BEACH_TILES + visible_ocean + CAMERA_SHORE_PAD_TILES) * tile
			camera.limit_enabled = true
			camera.limit_left = -cam_pad
			camera.limit_right = width * tile + cam_pad
			camera.limit_top = -320
			camera.limit_bottom = (bedrock_y + 4) * tile
			camera.reset_smoothing()
			camera.force_update_scroll()

	var killzone := game.get_node_or_null("Killzone") as Area2D
	if killzone:
		# Deep under bedrock only — do not raise into the shore walk band.
		var tile := PlaceholderTileset.TILE_SIZE
		var shore_pad := SHORE_MARGIN_TILES * tile
		killzone.position = Vector2(width * tile * 0.5, (bedrock_y + OCEAN_DEPTH_TILES + 6) * tile)
		var shape_node := killzone.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape_node:
			var rect := RectangleShape2D.new()
			# Cover land + shores horizontally; Y stays far below walkable beach/ocean floor.
			rect.size = Vector2(width * tile + shore_pad * 2.0 + 8.0 * tile, 80)
			shape_node.shape = rect

	_place_shores()
	_place_enemy_spawners(game)
	_place_found_store(game)
	_place_gas_station(game)
	_place_abandoned_cars(game)
	_place_stranded_hirees(game)


func _place_shores() -> void:
	# Left edge: land ends at x=0 → beach outward → acid ocean.
	_add_shore(0, -1.0)
	# Right edge: land ends at width → beach outward → acid ocean.
	_add_shore(width, 1.0)


func _add_shore(edge_cell_x: int, outward: float) -> void:
	var tile := float(PlaceholderTileset.TILE_SIZE)
	var beach_w := float(BEACH_TILES) * tile
	var ocean_w := float(OCEAN_TILES) * tile
	var overlap := float(SHORE_OVERLAP_TILES) * tile
	# Align to TileMapLayer local space (tile centers), not raw cell*size.
	var edge_cell := clampi(edge_cell_x, 0, width - 1)
	var surface := _surface_y(edge_cell)
	var edge_center := map_to_local(Vector2i(edge_cell, surface))
	# Outer face of the edge tile (left: x=0, right: x=width*tile).
	var edge_px := 0.0 if outward < 0.0 else float(width) * tile
	var surface_top := edge_center.y - tile * 0.5

	# Fill under beach + near-ocean columns so the cross-section is solid to bedrock.
	_fill_under_shore(edge_cell_x, outward, surface)

	# Parent under this TileMapLayer so shore coords share terrain space (no Game transform drift).
	var beach := preload("res://Scenes/beach_strip.tscn").instantiate()
	add_child(beach)
	beach.z_index = 0
	# Beach sits on the grass surface, extending outward from the map edge.
	beach.position = Vector2(edge_px, surface_top)
	if beach.has_method("setup"):
		beach.setup(outward, overlap)

	var ocean_center_x := edge_px + outward * (beach_w + ocean_w * 0.5)
	var ocean := preload("res://Scenes/acid_pool.tscn").instantiate()
	add_child(ocean)
	ocean.z_index = 0
	# Visual depth reaches bedrock so there is no empty void under the water body.
	var fill_depth_tiles := maxi(bedrock_y - surface, OCEAN_DEPTH_TILES)
	var fill_h := float(fill_depth_tiles) * tile
	ocean.position = Vector2(ocean_center_x, surface_top + fill_h * 0.5)
	if ocean.has_method("setup"):
		# inland is opposite of outward: tuck floor under the scum tile.
		ocean.setup(Vector2(ocean_w, fill_h), overlap, -outward)


## Solid cross-section under beach (and a lip of ocean) down to bedrock.
## Uses terrain dirt/stone/bedrock — rectangular caves elsewhere stay caves.
func _fill_under_shore(_edge_cell_x: int, outward: float, surface: int) -> void:
	var dir := -1 if outward < 0.0 else 1
	# Beach columns + a short ocean lip get TileMap fill under the walk strip.
	var fill_cols := BEACH_TILES + 3
	for i in fill_cols:
		var x := (-1 - i) if dir < 0 else (width + i)
		for y in range(surface, bedrock_y + 1):
			if get_cell_source_id(Vector2i(x, y)) != -1:
				continue
			var depth := y - surface
			var column: int
			if y == bedrock_y:
				column = PlaceholderTileset.BEDROCK.x
			elif depth <= dirt_depth:
				column = PlaceholderTileset.DIRT_DARK.x if ((x + y) % 3) == 0 else PlaceholderTileset.DIRT.x
			elif depth <= dirt_depth + 6:
				column = PlaceholderTileset.STONE.x
			else:
				column = PlaceholderTileset.STONE_DARK.x if ((x + y) % 2) == 0 else PlaceholderTileset.STONE.x
			set_cell(Vector2i(x, y), 0, PlaceholderTileset.variant_coords(column, x, y, _height_noise.seed))


func _place_enemy_spawners(game: Node) -> void:
	var structures := game.get_node_or_null("Structures") as Node2D
	if structures == null:
		return

	var spawn_x := int(width / 2.0)
	# Near pair (~90 tiles): 1-minute first contact after ships land at 60s.
	_add_spawner(structures, _find_open_spawner_on_side(spawn_x, -1, MIN_SPAWNER_TILES))
	_add_spawner(structures, _find_open_spawner_on_side(spawn_x, 1, MIN_SPAWNER_TILES))
	# Far pair (~900 tiles): reason to walk the extra-wide map.
	_add_spawner(structures, _find_open_spawner_on_side(spawn_x, -1, FAR_SPAWNER_TILES))
	_add_spawner(structures, _find_open_spawner_on_side(spawn_x, 1, FAR_SPAWNER_TILES))


func _place_stranded_hirees(game: Node) -> void:
	var structures := game.get_node_or_null("Structures") as Node2D
	if structures == null:
		return
	# One stranded recruit near each alien ship — walk out from the hub to hire.
	for ship in structures.get_children():
		if not ship.is_in_group("alien_ship") and not ship.is_in_group("enemy_spawner"):
			continue
		if not ship is Node2D:
			continue
		_add_hiree_near(structures, ship as Node2D)


func _add_hiree_near(structures: Node2D, ship: Node2D) -> void:
	var ship_cell := local_to_map(to_local(ship.global_position))
	var side := -1 if ship_cell.x < int(width / 2.0) else 1
	# Stand on grass a few tiles toward the hub from the ship so Mike must walk out.
	var tile_x := clampi(ship_cell.x - side * 6, 4, width - 5)
	var surface := _surface_y(tile_x)
	var foot := map_to_local(Vector2i(tile_x, surface)) + Vector2(0, -PlaceholderTileset.TILE_SIZE * 0.5)
	var hiree := preload("res://Scenes/hiree.tscn").instantiate()
	structures.add_child(hiree)
	hiree.global_position = to_global(foot)
	if hiree.has_method("roll_stats"):
		hiree.roll_stats()


func _add_spawner(structures: Node2D, left_x: int) -> void:
	var surface := _surface_y(left_x)
	var width_tiles := PlaceholderSpawner.WIDTH_TILES
	var left_center := map_to_local(Vector2i(left_x, surface))
	var right_center := map_to_local(Vector2i(left_x + width_tiles - 1, surface))
	var foot := Vector2((left_center.x + right_center.x) * 0.5, left_center.y - PlaceholderTileset.TILE_SIZE * 0.5)
	var spawner := preload("res://Scenes/enemy_spawner.tscn").instantiate()
	structures.add_child(spawner)
	spawner.global_position = to_global(foot)


func _place_found_store(game: Node) -> void:
	var structures := game.get_node_or_null("Structures") as Node2D
	if structures == null:
		return
	var spawn_x := int(width / 2.0)
	# One side only (right of plateau), ~220 tiles out, not on a ship / hub overlap.
	var left_x := _find_open_prop_on_side(
		spawn_x, 1, FOUND_STORE_TILES, PlaceholderStore.WIDTH_TILES, PlaceholderStore.HEIGHT_TILES, 7
	)
	_add_found_store(structures, left_x)


func _add_found_store(structures: Node2D, left_x: int) -> void:
	var surface := _surface_y(left_x)
	var width_tiles := PlaceholderStore.WIDTH_TILES
	var left_center := map_to_local(Vector2i(left_x, surface))
	var right_center := map_to_local(Vector2i(left_x + width_tiles - 1, surface))
	var foot := Vector2((left_center.x + right_center.x) * 0.5, left_center.y - PlaceholderTileset.TILE_SIZE * 0.5)
	var store := preload("res://Scenes/store.tscn").instantiate()
	structures.add_child(store)
	store.global_position = to_global(foot)


func _place_gas_station(game: Node) -> void:
	var structures := game.get_node_or_null("Structures") as Node2D
	if structures == null:
		return
	var spawn_x := int(width / 2.0)
	# Further than the store (~450), right side, walkable grass — not on ship/store/hub.
	var left_x := _find_open_prop_on_side(
		spawn_x,
		1,
		GAS_STATION_TILES,
		PlaceholderGasStation.WIDTH_TILES,
		PlaceholderGasStation.HEIGHT_TILES,
		13
	)
	_add_gas_station(structures, left_x)


func _add_gas_station(structures: Node2D, left_x: int) -> void:
	var surface := _surface_y(left_x)
	var width_tiles := PlaceholderGasStation.WIDTH_TILES
	var left_center := map_to_local(Vector2i(left_x, surface))
	var right_center := map_to_local(Vector2i(left_x + width_tiles - 1, surface))
	var foot := Vector2((left_center.x + right_center.x) * 0.5, left_center.y - PlaceholderTileset.TILE_SIZE * 0.5)
	var station := preload("res://Scenes/gas_station.tscn").instantiate()
	structures.add_child(station)
	station.global_position = to_global(foot)


func _place_abandoned_cars(game: Node) -> void:
	var structures := game.get_node_or_null("Structures") as Node2D
	if structures == null:
		return
	var spawn_x := int(width / 2.0)
	var placed: Array[int] = []
	# Mix of both sides, beyond the near ships, clear of store/station/ships/acid.
	var targets: Array[Dictionary] = [
		{"side": -1, "min_tiles": 140, "shift": 17, "variant": PlaceholderCar.Variant.A},
		{"side": 1, "min_tiles": 160, "shift": 19, "variant": PlaceholderCar.Variant.B},
		{"side": -1, "min_tiles": 280, "shift": 21, "variant": PlaceholderCar.Variant.B},
		{"side": 1, "min_tiles": 320, "shift": 23, "variant": PlaceholderCar.Variant.A},
		{"side": -1, "min_tiles": 520, "shift": 29, "variant": PlaceholderCar.Variant.A},
	]
	for i in mini(ABANDONED_CAR_COUNT, targets.size()):
		var t: Dictionary = targets[i]
		var variant: PlaceholderCar.Variant = t["variant"]
		var w_tiles := PlaceholderCar.width_tiles_for(variant)
		var h_tiles := PlaceholderCar.height_tiles_for(variant)
		var left_x := _find_open_prop_on_side(
			spawn_x, int(t["side"]), int(t["min_tiles"]), w_tiles, h_tiles, int(t["shift"]), placed, 10, false
		)
		# Require a verified open grass site (no forced fallback for cars).
		if left_x == -999999:
			continue
		if not _prop_site_open(left_x, w_tiles, h_tiles):
			continue
		if not _prop_clear_of_structures(left_x, w_tiles):
			continue
		placed.append(left_x)
		_add_abandoned_car(structures, left_x, variant)


func _add_abandoned_car(structures: Node2D, left_x: int, variant: PlaceholderCar.Variant) -> void:
	var surface := _surface_y(left_x)
	var width_tiles := PlaceholderCar.width_tiles_for(variant)
	var left_center := map_to_local(Vector2i(left_x, surface))
	var right_center := map_to_local(Vector2i(left_x + width_tiles - 1, surface))
	var foot := Vector2((left_center.x + right_center.x) * 0.5, left_center.y - PlaceholderTileset.TILE_SIZE * 0.5)
	var car := preload("res://Scenes/abandoned_car.tscn").instantiate()
	structures.add_child(car)
	car.global_position = to_global(foot)
	if car.has_method("set_variant"):
		car.set_variant(variant)


func _find_open_prop_on_side(
	spawn_x: int,
	side: int,
	min_tiles: int,
	footprint: int,
	height: int,
	shift: int,
	avoid_xs: Array[int] = [],
	avoid_gap: int = 8,
	allow_fallback: bool = true
) -> int:
	var extra := absi((_height_noise.seed >> (shift % 30))) % 18
	var start := spawn_x + side * (min_tiles + extra)
	start = clampi(start, 8, width - footprint - 8)
	var found := _scan_open_prop_on_side(
		spawn_x, start, side, min_tiles, footprint, height, avoid_xs, avoid_gap
	)
	if found != -999999:
		return found
	if not allow_fallback:
		return -999999
	return clampi(spawn_x + side * min_tiles, 8, width - footprint - 8)


func _scan_open_prop_on_side(
	spawn_x: int,
	start: int,
	side: int,
	min_tiles: int,
	footprint: int,
	height: int,
	avoid_xs: Array[int],
	avoid_gap: int
) -> int:
	for offset in width:
		for candidate in [start + offset, start - offset]:
			if side < 0 and candidate >= spawn_x:
				continue
			if side > 0 and candidate <= spawn_x:
				continue
			if absi(candidate - spawn_x) < min_tiles - 8:
				continue
			var too_close := false
			for other_x in avoid_xs:
				if absi(candidate - other_x) < avoid_gap:
					too_close = true
					break
			if too_close:
				continue
			if not _prop_clear_of_structures(candidate, footprint):
				continue
			if _prop_site_open(candidate, footprint, height):
				return candidate
	return -999999


func _prop_clear_of_structures(left_x: int, footprint: int) -> bool:
	var min_gap := maxi(PlaceholderSpawner.WIDTH_TILES, footprint) + SPAWNER_SIDE_CLEAR * 2 + 4
	var structures := get_parent().get_node_or_null("Structures") as Node2D
	if structures == null:
		return true
	for child in structures.get_children():
		if not (
			child.is_in_group("alien_ship")
			or child.is_in_group("enemy_spawner")
			or child.is_in_group("found_store")
			or child.is_in_group("gas_station")
			or child.is_in_group("abandoned_car")
			or child.is_in_group("main_hub")
		):
			continue
		if not child is Node2D:
			continue
		var other_cell := local_to_map(to_local((child as Node2D).global_position))
		if absi(other_cell.x - left_x) < min_gap:
			return false
	return true


func _prop_site_open(left_x: int, footprint: int, height: int) -> bool:
	var first := left_x
	var last := left_x + footprint - 1
	if first < 2 or last >= width - 2:
		return false
	var surface := _surface_y(left_x)
	for x in range(first, last + 1):
		if _surface_y(x) != surface:
			return false
		if not _is_grass_cell(Vector2i(x, surface)):
			return false
		for dy in range(1, height + 1):
			if _has_cell(Vector2i(x, surface - dy)):
				return false
	return true


func _find_open_spawner_on_side(spawn_x: int, side: int, min_tiles: int) -> int:
	# Jitter differs by band so near/far sites on the same side don't share one offset.
	var band := 1 if min_tiles >= FAR_SPAWNER_TILES else 0
	var shift := (1 if side > 0 else 3) + band * 5
	var extra := absi((_height_noise.seed >> shift)) % 24
	var start := spawn_x + side * (min_tiles + extra)
	start = clampi(start, 6, width - 7)
	var found := _scan_open_spawner_on_side(spawn_x, start, side, min_tiles)
	if found != -999999:
		return found
	return clampi(spawn_x + side * min_tiles, 6, width - 7)


func _scan_open_spawner_on_side(spawn_x: int, start: int, side: int, min_tiles: int) -> int:
	for offset in width:
		for candidate in [start + offset, start - offset]:
			if side < 0 and candidate >= spawn_x:
				continue
			if side > 0 and candidate <= spawn_x:
				continue
			if absi(candidate - spawn_x) < min_tiles:
				continue
			# Keep near and far footprints from stacking on the same flat.
			if not _spawner_far_enough_from_others(candidate):
				continue
			if _spawner_site_open(candidate):
				return candidate
	return -999999


func _spawner_far_enough_from_others(left_x: int) -> bool:
	var footprint := PlaceholderSpawner.WIDTH_TILES
	var min_gap := footprint + SPAWNER_SIDE_CLEAR * 2 + 8
	var structures := get_parent().get_node_or_null("Structures") as Node2D
	if structures == null:
		return true
	for child in structures.get_children():
		if not child.is_in_group("alien_ship") and not child.is_in_group("enemy_spawner"):
			continue
		if not child is Node2D:
			continue
		var other_cell := local_to_map(to_local((child as Node2D).global_position))
		if absi(other_cell.x - left_x) < min_gap:
			return false
	return true


func _spawner_site_open(left_x: int) -> bool:
	var footprint := PlaceholderSpawner.WIDTH_TILES
	var height := PlaceholderSpawner.HEIGHT_TILES
	var first := left_x - SPAWNER_SIDE_CLEAR
	var last := left_x + footprint + SPAWNER_SIDE_CLEAR - 1
	if first < 1 or last >= width - 1:
		return false

	var surface := _surface_y(left_x)
	for x in range(first, last + 1):
		if _surface_y(x) != surface:
			return false
		if not _is_grass_cell(Vector2i(x, surface)):
			return false
		for dy in range(1, height + 1):
			if _has_cell(Vector2i(x, surface - dy)):
				return false
	return true


func _has_cell(cell: Vector2i) -> bool:
	return get_cell_source_id(cell) != -1


func _is_grass_cell(cell: Vector2i) -> bool:
	return _has_cell(cell) and PlaceholderTileset.is_grass(get_cell_atlas_coords(cell))
