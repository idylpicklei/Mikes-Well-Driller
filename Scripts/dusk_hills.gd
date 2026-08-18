extends Node2D

## Far + mid rolling hills.
## Draw stack: sky → stars → hills_far → clouds → hills_mid → terrain/Mike.
## This node owns both hill bands (far behind clouds, mid in front).
## Slow horizontal parallax, hop a little less not zero (same dampen as clouds).
##
## Artist drop-ins: hills_far.png (320×48), hills_mid.png (320×40).
## Until mid art lands, far uses the sprite; mid falls back to a simple silhouette.

const HILLS_FAR_PATH := "res://Assets/sprites/hills_far.png"
const HILLS_MID_PATH := "res://Assets/sprites/hills_mid.png"
const HILLS_PATH := "res://Assets/sprites/hills.png"
const MOUNTAINS_PATH := "res://Assets/sprites/mountains.png"

const COL_FAR := Color(0.10, 0.14, 0.22, 0.95)
const COL_NEAR := Color(0.14, 0.12, 0.18, 0.98)
const COL_RIM := Color(0.55, 0.28, 0.22, 0.55)

const SPAN := 3200.0
const FAR_Z := -100
const MID_Z := -70

var _far_tex: Texture2D
var _mid_tex: Texture2D
var _far_sprites: Array[Sprite2D] = []
var _mid_sprites: Array[Sprite2D] = []
var _mid_draw: Node2D
var _y_baseline := 0.0
var _baseline_ready := false
var _phase_far := 0.0
var _phase_mid := 0.0


func _ready() -> void:
	z_index = FAR_Z
	z_as_relative = false
	y_sort_enabled = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_far_tex = _load_far()
	_mid_tex = _load_mid()
	if _far_tex:
		_build_sprite_band(_far_tex, _far_sprites, FAR_Z, Color(0.90, 0.82, 0.78, 0.95), 1.0)
	if _mid_tex:
		_build_sprite_band(_mid_tex, _mid_sprites, MID_Z, Color(0.85, 0.75, 0.70, 0.96), 1.05)
	else:
		_mid_draw = Node2D.new()
		_mid_draw.name = "HillsMidProcedural"
		_mid_draw.z_as_relative = false
		_mid_draw.z_index = MID_Z
		_mid_draw.set_script(load("res://Scripts/dusk_hills_mid_draw.gd"))
		_mid_draw.hills = self
		add_child(_mid_draw)
	set_process(true)
	call_deferred("_capture_y_baseline")
	queue_redraw()


func _load_far() -> Texture2D:
	if ResourceLoader.exists(HILLS_FAR_PATH):
		return load(HILLS_FAR_PATH) as Texture2D
	if ResourceLoader.exists(HILLS_PATH):
		return load(HILLS_PATH) as Texture2D
	if ResourceLoader.exists(MOUNTAINS_PATH):
		return load(MOUNTAINS_PATH) as Texture2D
	return null


func _load_mid() -> Texture2D:
	if ResourceLoader.exists(HILLS_MID_PATH):
		return load(HILLS_MID_PATH) as Texture2D
	return null


func _build_sprite_band(
	tex: Texture2D,
	into: Array[Sprite2D],
	band_z: int,
	modulate: Color,
	scale_base: float
) -> void:
	for i in 6:
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.centered = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.z_as_relative = false
		sprite.z_index = band_z
		sprite.modulate = modulate
		sprite.flip_h = i % 2 == 1
		var scale_mul := scale_base * randf_range(0.95, 1.15)
		sprite.scale = Vector2(scale_mul, scale_mul)
		add_child(sprite)
		into.append(sprite)


func _capture_y_baseline() -> void:
	_y_baseline = _camera_center().y
	_baseline_ready = true
	queue_redraw()


func _process(delta: float) -> void:
	if not _baseline_ready:
		_capture_y_baseline()
	_phase_far += delta * 1.6
	_phase_mid += delta * 2.4
	if _far_tex:
		_update_sprites(_far_sprites, 0.045, -22.0, 0.012, _phase_far)
	if _mid_tex:
		_update_sprites(_mid_sprites, 0.085, 10.0, 0.020, _phase_mid)
	if _far_tex == null:
		queue_redraw()
	if _mid_draw:
		_mid_draw.queue_redraw()


func _camera_center() -> Vector2:
	var cam := get_viewport().get_camera_2d()
	if cam:
		return cam.get_screen_center_position()
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		return player.global_position + Vector2(0, -48)
	return Vector2.ZERO


func _band_y(center: Vector2, y_bias: float, hop_scale: float) -> float:
	var baseline := _y_baseline if _baseline_ready else center.y
	var hop := (center.y - baseline) * hop_scale
	return baseline + 28.0 + y_bias + hop


func _update_sprites(
	sprites: Array[Sprite2D],
	parallax: float,
	y_bias: float,
	hop_scale: float,
	phase: float
) -> void:
	var center := _camera_center()
	var band_y := _band_y(center, y_bias, hop_scale)
	var parallax_x := center.x * parallax
	var width := SPAN
	var spacing := width / float(maxi(sprites.size(), 1))
	for i in sprites.size():
		var sprite: Sprite2D = sprites[i]
		var raw := parallax_x + float(i) * spacing - phase
		var local := fposmod(raw - (center.x - width * 0.5), width)
		sprite.global_position = Vector2(center.x - width * 0.5 + local, band_y)


func _draw() -> void:
	if _far_tex != null:
		return
	var center := _camera_center()
	var band_y := _band_y(center, -18.0, 0.012)
	_draw_ridge(self, center.x, band_y, center.x * 0.04, COL_FAR, 1.0, 0)


func draw_mid_procedural_into(canvas: CanvasItem) -> void:
	if _mid_tex != null:
		return
	var center := _camera_center()
	var mid_y := _band_y(center, 8.0, 0.020)
	_draw_ridge(canvas, center.x, mid_y, center.x * 0.07 + _phase_mid, COL_NEAR, 0.85, 17)


func _draw_ridge(
	canvas: CanvasItem,
	cam_x: float,
	base_y: float,
	scroll: float,
	color: Color,
	height_mul: float,
	seed_off: int
) -> void:
	var width := SPAN
	var origin_x := cam_x - width * 0.5
	var points := PackedVector2Array()
	points.append(Vector2(origin_x - 40.0, base_y + 160.0))
	var steps := 28
	for i in steps + 1:
		var t := float(i) / float(steps)
		var x := origin_x + t * width
		var n := sin((x + scroll) * 0.0042 + float(seed_off)) * 42.0
		n += sin((x + scroll) * 0.011 + float(seed_off) * 0.7) * 22.0 * height_mul
		n += sin((x + scroll) * 0.023 + 1.3) * 10.0
		points.append(Vector2(x, base_y - n * height_mul))
	points.append(Vector2(origin_x + width + 40.0, base_y + 160.0))
	canvas.draw_colored_polygon(points, color)
	var rim := PackedVector2Array()
	for i in range(1, points.size() - 1):
		rim.append(points[i])
	if rim.size() >= 2:
		canvas.draw_polyline(rim, COL_RIM, 2.0, true)
