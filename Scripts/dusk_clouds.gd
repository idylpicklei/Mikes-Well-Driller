extends Node2D

## Dusk wasteland clouds. Behind terrain/Mike, in front of clear color.
## Node2D in world space — not ParallaxBackground/CanvasLayer — so z_index
## stays in the dusk stack (sky → stars → hills_far → clouds → hills_mid).
## Slow horizontal drift + gentle X parallax. Vertical follow is heavily
## dampened so jumps don't make the sky lurch (still moves a little).
## Mix A/D low, B/E mid, C/F/G high — a/b/c stay; d/e/f/g add variance.

const CLOUD_A := "res://Assets/sprites/cloud_a.png"
const CLOUD_B := "res://Assets/sprites/cloud_b.png"
const CLOUD_C := "res://Assets/sprites/cloud_c.png"
const CLOUD_D := "res://Assets/sprites/cloud_d.png"
const CLOUD_E := "res://Assets/sprites/cloud_e.png"
const CLOUD_F := "res://Assets/sprites/cloud_f.png"
const CLOUD_G := "res://Assets/sprites/cloud_g.png"

## Depth bands. parallax_y is a small fraction so hop bob is soft, not locked.
## paths: band-specific sheets so plateaus don't repeat one stamp.
const BANDS := [
	{
		"paths": [CLOUD_A, CLOUD_D],
		"parallax_x": 0.18, "parallax_y": 0.035, "drift": 6.5,
		"y_bias": -72.0, "modulate": Color(0.72, 0.58, 0.52, 0.82), "count": 11,
	},
	{
		"paths": [CLOUD_B, CLOUD_E],
		"parallax_x": 0.10, "parallax_y": 0.020, "drift": 3.6,
		"y_bias": -108.0, "modulate": Color(0.55, 0.42, 0.40, 0.60), "count": 10,
	},
	{
		"paths": [CLOUD_C, CLOUD_F, CLOUD_G],
		"parallax_x": 0.04, "parallax_y": 0.010, "drift": 1.6,
		"y_bias": -148.0, "modulate": Color(0.42, 0.32, 0.34, 0.46), "count": 9,
	},
]

const SPAN := 2600.0

var _bands: Array[Dictionary] = []
## Baseline camera Y at spawn — hop delta is measured from this and scaled down.
var _y_baseline := 0.0
var _baseline_ready := false


func _ready() -> void:
	z_index = -80
	z_as_relative = false
	y_sort_enabled = false
	for spec in BANDS:
		_add_band(spec)
	set_process(true)
	call_deferred("_capture_y_baseline")
	_update_bands(0.0)


func _capture_y_baseline() -> void:
	_y_baseline = _camera_center().y
	_baseline_ready = true
	_update_bands(0.0)


func _process(delta: float) -> void:
	if not _baseline_ready:
		_capture_y_baseline()
	_update_bands(delta)


func _load_band_textures(paths: Array) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	for path in paths:
		var tex := load(str(path)) as Texture2D
		if tex:
			textures.append(tex)
		else:
			push_warning("DuskClouds: missing texture %s" % str(path))
	return textures


func _add_band(spec: Dictionary) -> void:
	var textures := _load_band_textures(spec.get("paths", []))
	if textures.is_empty():
		return

	var count: int = int(spec["count"])
	var y_bias: float = float(spec["y_bias"])
	var base_mod: Color = spec["modulate"]
	var sprites: Array[Sprite2D] = []
	var slots: Array[Dictionary] = []

	# Irregular gaps so a plateau never reads as one repeating stamp.
	var cursor := 0.0
	for i in count:
		var tex: Texture2D = textures[(i * 7 + count) % textures.size()]
		# Mix sheets within the band so neighbors rarely match.
		if textures.size() > 1 and i % 2 == 1:
			tex = textures[(i * 5 + 1) % textures.size()]
		elif textures.size() > 2 and i % 3 == 2:
			tex = textures[(i * 3 + 2) % textures.size()]

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
		"parallax_y": float(spec["parallax_y"]),
		"drift": float(spec["drift"]),
		"y_bias": y_bias,
		"width": width,
		"phase": randf() * width,
	})


func _camera_center() -> Vector2:
	var cam := get_viewport().get_camera_2d()
	if cam:
		return cam.get_screen_center_position()
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		return player.global_position + Vector2(0, -48)
	return Vector2.ZERO


func _update_bands(delta: float) -> void:
	var center := _camera_center()
	var cam_x := center.x
	# Soft vertical: keep most of the sky at the spawn baseline, add a little hop follow.
	var baseline := _y_baseline if _baseline_ready else center.y
	var hop_delta := center.y - baseline

	for band in _bands:
		band["phase"] = float(band["phase"]) + float(band["drift"]) * delta
		var width: float = maxf(float(band["width"]), 1.0)
		var phase: float = fposmod(float(band["phase"]), width)
		var parallax_x: float = float(band["parallax_x"])
		var parallax_y: float = float(band["parallax_y"])
		var band_y := baseline + float(band["y_bias"]) + hop_delta * parallax_y
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
