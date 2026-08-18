extends ParallaxBackground

## Dusk wasteland cloud bands. Behind terrain/Mike, in front of clear color.
## PC only — slow drift, three parallax depths. No sky-gradient sprite.

const CLOUD_A := "res://Assets/sprites/cloud_a.png"
const CLOUD_B := "res://Assets/sprites/cloud_b.png"
const CLOUD_C := "res://Assets/sprites/cloud_c.png"

## Closest / lowest → fastest (still slow). Farthest → slowest.
const LAYERS := [
	{"path": CLOUD_A, "motion_scale": Vector2(0.22, 0.04), "drift": 7.5, "y": -28.0, "modulate": Color(0.72, 0.58, 0.52, 0.78), "spacing": 220.0, "copies": 8},
	{"path": CLOUD_B, "motion_scale": Vector2(0.12, 0.02), "drift": 4.0, "y": -78.0, "modulate": Color(0.55, 0.42, 0.40, 0.55), "spacing": 260.0, "copies": 7},
	{"path": CLOUD_C, "motion_scale": Vector2(0.05, 0.01), "drift": 1.8, "y": -130.0, "modulate": Color(0.42, 0.32, 0.34, 0.38), "spacing": 300.0, "copies": 6},
]

var _drifts: Array[float] = []
var _layers: Array[ParallaxLayer] = []


func _ready() -> void:
	scroll_ignore_camera_zoom = true
	z_index = -100
	for spec in LAYERS:
		_add_layer(spec)


func _process(delta: float) -> void:
	for i in _layers.size():
		var layer := _layers[i]
		layer.motion_mirroring.x = maxf(layer.motion_mirroring.x, 1.0)
		layer.motion_offset.x = fposmod(layer.motion_offset.x + _drifts[i] * delta, layer.motion_mirroring.x)


func _add_layer(spec: Dictionary) -> void:
	var tex := load(str(spec["path"])) as Texture2D
	if tex == null:
		return

	var layer := ParallaxLayer.new()
	layer.motion_scale = spec["motion_scale"]
	var spacing: float = float(spec["spacing"])
	var copies: int = int(spec["copies"])
	layer.motion_mirroring = Vector2(spacing * float(copies), 0.0)

	var y: float = float(spec["y"])
	var modulate: Color = spec["modulate"]
	for i in copies:
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.centered = true
		sprite.position = Vector2(float(i) * spacing, y)
		sprite.modulate = modulate
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		layer.add_child(sprite)

	add_child(layer)
	_layers.append(layer)
	_drifts.append(float(spec["drift"]))
