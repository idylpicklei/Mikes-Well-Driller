extends Node2D

## Dusk wasteland cloud bands. Behind terrain/Mike, in front of clear color.
## Uses world-space Node2D (not ParallaxBackground/CanvasLayer) so z_index works
## and clouds stay on-camera at spawn. PC only — slow drift, three depths.

const CLOUD_A := "res://Assets/sprites/cloud_a.png"
const CLOUD_B := "res://Assets/sprites/cloud_b.png"
const CLOUD_C := "res://Assets/sprites/cloud_c.png"

## Closest / lowest → fastest (still slow). Farthest → slowest.
## y_bias: pixels above camera center (sky sits in the upper view with up-cam).
const LAYERS := [
	{"path": CLOUD_A, "parallax": 0.22, "drift": 7.5, "y_bias": -36.0, "modulate": Color(0.72, 0.58, 0.52, 0.82), "spacing": 220.0, "copies": 10},
	{"path": CLOUD_B, "parallax": 0.12, "drift": 4.0, "y_bias": -72.0, "modulate": Color(0.55, 0.42, 0.40, 0.62), "spacing": 260.0, "copies": 9},
	{"path": CLOUD_C, "parallax": 0.05, "drift": 1.8, "y_bias": -108.0, "modulate": Color(0.42, 0.32, 0.34, 0.48), "spacing": 300.0, "copies": 8},
]

var _bands: Array[Dictionary] = []


func _ready() -> void:
	# Behind terrain (0) and Mike; clear color still shows through alpha.
	z_index = -80
	z_as_relative = false
	y_sort_enabled = false
	for spec in LAYERS:
		_add_band(spec)
	set_process(true)
	# Place immediately so the first frame is not an empty navy void.
	_update_bands(0.0)


func _process(delta: float) -> void:
	_update_bands(delta)


func _add_band(spec: Dictionary) -> void:
	var tex := load(str(spec["path"])) as Texture2D
	if tex == null:
		push_warning("DuskClouds: missing texture %s" % str(spec["path"]))
		return

	var spacing: float = float(spec["spacing"])
	var copies: int = int(spec["copies"])
	var y_bias: float = float(spec["y_bias"])
	var modulate: Color = spec["modulate"]
	var sprites: Array[Sprite2D] = []

	for i in copies:
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.centered = true
		sprite.modulate = modulate
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.z_as_relative = false
		sprite.z_index = z_index
		add_child(sprite)
		sprites.append(sprite)

	_bands.append({
		"sprites": sprites,
		"parallax": float(spec["parallax"]),
		"drift": float(spec["drift"]),
		"y_bias": y_bias,
		"spacing": spacing,
		"width": spacing * float(copies),
		"phase": randf() * spacing,
	})


func _update_bands(delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	var center := Vector2.ZERO
	if cam:
		center = cam.get_screen_center_position()
	else:
		var player := get_tree().get_first_node_in_group("player") as Node2D
		if player:
			center = player.global_position + Vector2(0, -48)

	for band in _bands:
		band["phase"] = float(band["phase"]) + float(band["drift"]) * delta
		var spacing: float = float(band["spacing"])
		var width: float = maxf(float(band["width"]), spacing)
		var phase: float = fposmod(float(band["phase"]), width)
		var parallax: float = float(band["parallax"])
		var y_bias: float = float(band["y_bias"])
		# Parallax: distant bands lag behind camera X; Y tracks camera so sky stays filled.
		var base_x := center.x * parallax - phase
		var base_y := center.y + y_bias
		var sprites: Array = band["sprites"]
		for i in sprites.size():
			var sprite: Sprite2D = sprites[i]
			var x := base_x + float(i) * spacing
			# Wrap into a window around the camera so we never run out of copies.
			var local := fposmod(x - (center.x - width * 0.5), width)
			sprite.global_position = Vector2(center.x - width * 0.5 + local, base_y)
