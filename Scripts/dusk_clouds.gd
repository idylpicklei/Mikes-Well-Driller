extends Node2D

## Dusk wasteland clouds. Behind terrain/Mike, in front of clear color.
## Slow horizontal drift + gentle X parallax. Cloud Y is world-locked so
## jumps do not lurch the sky (almost no vertical motion on hop).

const CLOUD_PATHS: PackedStringArray = [
	"res://Assets/sprites/cloud_a.png",
	"res://Assets/sprites/cloud_b.png",
	"res://Assets/sprites/cloud_c.png",
]

## Depth bands: X parallax only. Y is locked to spawn altitude + band bias.
const BANDS := [
	{"parallax_x": 0.18, "drift": 6.5, "y": -36.0, "modulate": Color(0.72, 0.58, 0.52, 0.82), "count": 11},
	{"parallax_x": 0.10, "drift": 3.6, "y": -72.0, "modulate": Color(0.55, 0.42, 0.40, 0.60), "count": 10},
	{"parallax_x": 0.04, "drift": 1.6, "y": -112.0, "modulate": Color(0.42, 0.32, 0.34, 0.46), "count": 9},
]

const SPAN := 2600.0

var _textures: Array[Texture2D] = []
var _bands: Array[Dictionary] = []
## Stable sky altitude — set once from spawn; never tracks jump/camera Y.
var _sky_anchor_y := 0.0
var _anchor_ready := false


func _ready() -> void:
	z_index = -80
	z_as_relative = false
	y_sort_enabled = false
	_load_textures()
	for spec in BANDS:
		_add_band(spec)
	set_process(true)
	call_deferred("_lock_sky_anchor")
	_update_bands(0.0)


func _load_textures() -> void:
	_textures.clear()
	for path in CLOUD_PATHS:
		var tex := load(path) as Texture2D
		if tex:
			_textures.append(tex)
		else:
			push_warning("DuskClouds: missing texture %s" % path)


func _lock_sky_anchor() -> void:
	var terrain := get_tree().get_first_node_in_group("terrain")
	if terrain != null and "spawn_position" in terrain:
		_sky_anchor_y = float(terrain.spawn_position.y)
		_anchor_ready = true
		_update_bands(0.0)
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		_sky_anchor_y = player.global_position.y
		_anchor_ready = true
		_update_bands(0.0)
		return
	var cam := get_viewport().get_camera_2d()
	if cam:
		_sky_anchor_y = cam.get_screen_center_position().y
		_anchor_ready = true


func _process(delta: float) -> void:
	if not _anchor_ready:
		_lock_sky_anchor()
	_update_bands(delta)


func _add_band(spec: Dictionary) -> void:
	if _textures.is_empty():
		return

	var count: int = int(spec["count"])
	var band_y: float = float(spec["y"])
	var base_mod: Color = spec["modulate"]
	var sprites: Array[Sprite2D] = []
	var slots: Array[Dictionary] = []

	# Irregular gaps so a plateau never reads as one repeating stamp.
	var cursor := 0.0
	for i in count:
		var path_i := (i * 7 + int(band_y) + count) % _textures.size()
		var tex: Texture2D = _textures[path_i]
		# Mix cloud_a/b/c so bands aren't mono-texture.
		if i % 3 == 1:
			tex = _textures[(path_i + 1) % _textures.size()]
		elif i % 3 == 2:
			tex = _textures[(path_i + 2) % _textures.size()]

		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.centered = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.z_as_relative = false
		sprite.z_index = z_index

		var scale_mul := randf_range(0.72, 1.45)
		if float(spec["parallax_x"]) < 0.08:
			scale_mul *= randf_range(0.85, 1.05)
		sprite.scale = Vector2(scale_mul, scale_mul * randf_range(0.9, 1.1))
		sprite.flip_h = randf() < 0.45
		sprite.flip_v = false
		var mod := base_mod
		mod.a = clampf(base_mod.a * randf_range(0.85, 1.12), 0.28, 0.9)
		mod.r = clampf(mod.r * randf_range(0.92, 1.06), 0.0, 1.0)
		mod.g = clampf(mod.g * randf_range(0.92, 1.06), 0.0, 1.0)
		sprite.modulate = mod

		var gap := randf_range(160.0, 320.0)
		cursor += gap
		var y_jitter := randf_range(-14.0, 14.0)
		slots.append({"x": cursor, "y_off": y_jitter})
		add_child(sprite)
		sprites.append(sprite)

	var width := maxf(cursor + 200.0, SPAN)
	_bands.append({
		"sprites": sprites,
		"slots": slots,
		"parallax_x": float(spec["parallax_x"]),
		"drift": float(spec["drift"]),
		"y": band_y,
		"width": width,
		"phase": randf() * width,
	})


func _camera_x() -> float:
	var cam := get_viewport().get_camera_2d()
	if cam:
		return cam.get_screen_center_position().x
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		return player.global_position.x
	return 0.0


func _update_bands(delta: float) -> void:
	var cam_x := _camera_x()
	# Locked world Y — camera/player hop never moves the sky vertically.
	var sky_y := _sky_anchor_y if _anchor_ready else 0.0

	for band in _bands:
		band["phase"] = float(band["phase"]) + float(band["drift"]) * delta
		var width: float = maxf(float(band["width"]), 1.0)
		var phase: float = fposmod(float(band["phase"]), width)
		var parallax_x: float = float(band["parallax_x"])
		var band_y: float = sky_y + float(band["y"])
		# Gentle horizontal follow only (distant layers lag).
		var follow_x := cam_x * parallax_x
		var sprites: Array = band["sprites"]
		var slots: Array = band["slots"]
		for i in sprites.size():
			var sprite: Sprite2D = sprites[i]
			var slot: Dictionary = slots[i]
			var raw_x := follow_x + float(slot["x"]) - phase
			var local := fposmod(raw_x - (cam_x - width * 0.5), width)
			var x := cam_x - width * 0.5 + local
			var y := band_y + float(slot["y_off"])
			sprite.global_position = Vector2(x, y)
