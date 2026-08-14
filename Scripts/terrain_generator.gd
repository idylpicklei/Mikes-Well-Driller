extends TileMapLayer

## Wide heightmap terrain. Tweak in the inspector; art can replace the
## placeholder atlas without changing these tile ids.
@export var world_seed: int = 0
@export var width: int = 480
@export var bedrock_y: int = 42
@export var base_surface_y: int = 10
@export var hill_amplitude: int = 7
@export var dirt_depth: int = 8
@export var tileset_texture: Texture2D

const PLACEHOLDER_ATLAS := "res://Assets/sprites/terrain_tileset.png"

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

	for y in range(-12, bedrock_y + 1):
		set_cell(Vector2i(-1, y), 0, PlaceholderTileset.BEDROCK)
		set_cell(Vector2i(width, y), 0, PlaceholderTileset.BEDROCK)

	var spawn_x := int(width / 2.0)
	var spawn_cell := Vector2i(spawn_x, _surface_y(spawn_x))
	spawn_position = map_to_local(spawn_cell) + Vector2(0, -8)


func _surface_y(x: int) -> int:
	var n := _height_noise.get_noise_1d(x)
	return base_surface_y + roundi(n * hill_amplitude)


func _atlas_at(x: int, y: int, surface: int) -> Vector2i:
	if y == bedrock_y:
		return PlaceholderTileset.BEDROCK
	if y == surface:
		return PlaceholderTileset.GRASS

	var depth := y - surface
	var speck := _fill_noise.get_noise_2d(x, y)
	if depth <= dirt_depth:
		return PlaceholderTileset.DIRT_DARK if speck > 0.2 else PlaceholderTileset.DIRT
	if speck > 0.25:
		return PlaceholderTileset.STONE_DARK
	return PlaceholderTileset.STONE


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
		player.fall_y = float((bedrock_y + 6) * PlaceholderTileset.TILE_SIZE)

		var camera := player.get_node_or_null("Camera2D") as Camera2D
		if camera:
			var world_right := (width + 1) * PlaceholderTileset.TILE_SIZE
			camera.limit_left = -PlaceholderTileset.TILE_SIZE
			camera.limit_right = world_right
			camera.limit_top = -320
			camera.limit_bottom = (bedrock_y + 4) * PlaceholderTileset.TILE_SIZE
			camera.reset_smoothing()
			camera.force_update_scroll()

	var killzone := game.get_node_or_null("Killzone") as Area2D
	if killzone:
		killzone.position = Vector2(width * PlaceholderTileset.TILE_SIZE * 0.5, (bedrock_y + 5) * PlaceholderTileset.TILE_SIZE)
		var shape_node := killzone.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape_node:
			var rect := RectangleShape2D.new()
			rect.size = Vector2((width + 8) * PlaceholderTileset.TILE_SIZE, 80)
			shape_node.shape = rect
