extends Node2D

## Far rolling hills / mountains — dusk silhouettes behind clouds? No: behind
## clouds is wrong; hills sit behind clouds (farther). z < clouds.
## Slow parallax, almost no jump lurch (same dampen as clouds).
##
## Artist drop-in: Assets/sprites/hills.png (or mountains.png).
## Until art lands, draw simple dusk silhouettes — not invented pixel art.

const HILLS_PATH := "res://Assets/sprites/hills.png"
const MOUNTAINS_PATH := "res://Assets/sprites/mountains.png"

const COL_FAR := Color(0.10, 0.14, 0.22, 0.95)
const COL_NEAR := Color(0.14, 0.12, 0.18, 0.98)
const COL_RIM := Color(0.55, 0.28, 0.22, 0.55)

const SPAN := 3200.0

var _tex: Texture2D
var _sprites: Array[Sprite2D] = []
var _y_baseline := 0.0
var _baseline_ready := false
var _phase := 0.0


func _ready() -> void:
	z_index = -100
	z_as_relative = false
	y_sort_enabled = false
	_tex = _load_drop_in()
	if _tex:
		_build_sprite_band()
	set_process(true)
	call_deferred("_capture_y_baseline")
	queue_redraw()


func _load_drop_in() -> Texture2D:
	if ResourceLoader.exists(HILLS_PATH):
		return load(HILLS_PATH) as Texture2D
	if ResourceLoader.exists(MOUNTAINS_PATH):
		return load(MOUNTAINS_PATH) as Texture2D
	return null


func _build_sprite_band() -> void:
	for i in 6:
		var sprite := Sprite2D.new()
		sprite.texture = _tex
		sprite.centered = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.z_as_relative = false
		sprite.z_index = z_index
		sprite.modulate = Color(0.85, 0.75, 0.7, 0.92)
		sprite.flip_h = i % 2 == 1
		var scale_mul := randf_range(0.95, 1.25)
		sprite.scale = Vector2(scale_mul, scale_mul)
		add_child(sprite)
		_sprites.append(sprite)


func _capture_y_baseline() -> void:
	_y_baseline = _camera_center().y
	_baseline_ready = true
	queue_redraw()


func _process(delta: float) -> void:
	if not _baseline_ready:
		_capture_y_baseline()
	_phase += delta * 2.2
	if _tex:
		_update_sprites()
	else:
		queue_redraw()


func _camera_center() -> Vector2:
	var cam := get_viewport().get_camera_2d()
	if cam:
		return cam.get_screen_center_position()
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		return player.global_position + Vector2(0, -48)
	return Vector2.ZERO


func _band_y(center: Vector2) -> float:
	var baseline := _y_baseline if _baseline_ready else center.y
	var hop := (center.y - baseline) * 0.012
	return baseline + 28.0 + hop


func _update_sprites() -> void:
	var center := _camera_center()
	var band_y := _band_y(center)
	var parallax_x := center.x * 0.06
	var width := SPAN
	var spacing := width / float(maxi(_sprites.size(), 1))
	for i in _sprites.size():
		var sprite: Sprite2D = _sprites[i]
		var raw := parallax_x + float(i) * spacing - _phase
		var local := fposmod(raw - (center.x - width * 0.5), width)
		sprite.global_position = Vector2(center.x - width * 0.5 + local, band_y)


func _draw() -> void:
	if _tex:
		return
	# Procedural dusk silhouettes until Artist hills/mountains PNG lands.
	var center := _camera_center()
	var band_y := _band_y(center)
	var parallax_x := center.x * 0.05
	_draw_ridge(center.x, band_y - 18.0, parallax_x * 0.7, COL_FAR, 1.0, 0)
	_draw_ridge(center.x, band_y + 6.0, parallax_x, COL_NEAR, 0.85, 17)


func _draw_ridge(cam_x: float, base_y: float, scroll: float, color: Color, height_mul: float, seed_off: int) -> void:
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
	draw_colored_polygon(points, color)
	# Warm dusk rim along the crest.
	var rim := PackedVector2Array()
	for i in range(1, points.size() - 1):
		rim.append(points[i])
	if rim.size() >= 2:
		draw_polyline(rim, COL_RIM, 2.0, true)
