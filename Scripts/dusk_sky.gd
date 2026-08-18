extends Node2D

## Dusk sky behind everything: gradient + sparse stars.
## Drop-in (optional): Assets/sprites/sky.png or Assets/sprites/stars.png —
## if present, used as a tinted overlay; otherwise code gradient + stars.
## Behind hills, clouds, terrain, Mike. PC only.

const SKY_PATH := "res://Assets/sprites/sky.png"
const STARS_PATH := "res://Assets/sprites/stars.png"

## Navy/teal zenith → warm orange/pink horizon (Artist cloud-preview mood).
const COL_ZENITH := Color(0.04, 0.08, 0.16, 1.0)
const COL_MID := Color(0.08, 0.22, 0.28, 1.0)
const COL_HORIZON := Color(0.72, 0.38, 0.28, 1.0)
const COL_GLOW := Color(0.92, 0.55, 0.42, 1.0)

const STAR_COUNT := 48
const VIEW_W := 1280.0
const VIEW_H := 720.0

var _stars: Array[Dictionary] = []
var _sky_overlay: Texture2D
var _stars_overlay: Texture2D
var _y_baseline := 0.0
var _baseline_ready := false


func _ready() -> void:
	z_index = -120
	z_as_relative = false
	y_sort_enabled = false
	if ResourceLoader.exists(SKY_PATH):
		_sky_overlay = load(SKY_PATH) as Texture2D
	if ResourceLoader.exists(STARS_PATH):
		_stars_overlay = load(STARS_PATH) as Texture2D
	_seed_stars()
	set_process(true)
	call_deferred("_capture_y_baseline")
	queue_redraw()


func _seed_stars() -> void:
	_stars.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xD05C5A17
	for _i in STAR_COUNT:
		_stars.append({
			"x": rng.randf_range(-0.48, 0.48),
			"y": rng.randf_range(-0.48, -0.02),
			"r": rng.randf_range(0.6, 1.6),
			"a": rng.randf_range(0.35, 0.95),
			"twinkle": rng.randf_range(0.0, TAU),
		})


func _capture_y_baseline() -> void:
	_y_baseline = _camera_center().y
	_baseline_ready = true
	queue_redraw()


func _process(delta: float) -> void:
	if not _baseline_ready:
		_capture_y_baseline()
	for star in _stars:
		star["twinkle"] = float(star["twinkle"]) + delta * 1.4
	queue_redraw()


func _camera_center() -> Vector2:
	var cam := get_viewport().get_camera_2d()
	if cam:
		return cam.get_screen_center_position()
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		return player.global_position + Vector2(0, -48)
	return Vector2.ZERO


func _draw() -> void:
	var center := _camera_center()
	# Sky is screen-locked with almost no hop follow (same dampen idea as clouds).
	var baseline := _y_baseline if _baseline_ready else center.y
	var hop := (center.y - baseline) * 0.008
	var origin := Vector2(center.x - VIEW_W * 0.5, baseline - VIEW_H * 0.55 + hop)

	if _sky_overlay:
		draw_texture_rect(_sky_overlay, Rect2(origin, Vector2(VIEW_W, VIEW_H)), false)
	else:
		_draw_gradient(origin)

	if _stars_overlay:
		draw_texture_rect(_stars_overlay, Rect2(origin, Vector2(VIEW_W, VIEW_H)), false, Color(1, 1, 1, 0.85))
	else:
		_draw_stars(origin, center.x)


func _draw_gradient(origin: Vector2) -> void:
	var bands := 24
	var band_h := VIEW_H / float(bands)
	for i in bands:
		var t := float(i) / float(bands - 1)
		var color: Color
		if t < 0.45:
			color = COL_ZENITH.lerp(COL_MID, t / 0.45)
		elif t < 0.75:
			color = COL_MID.lerp(COL_HORIZON, (t - 0.45) / 0.30)
		else:
			color = COL_HORIZON.lerp(COL_GLOW, (t - 0.75) / 0.25)
		var y := origin.y + float(i) * band_h
		draw_rect(Rect2(origin.x, y, VIEW_W, band_h + 1.0), color)


func _draw_stars(origin: Vector2, cam_x: float) -> void:
	# Subtle horizontal drift with camera so stars feel distant, not glued to UI.
	var parallax := cam_x * 0.015
	for star in _stars:
		var tw := 0.55 + 0.45 * sin(float(star["twinkle"]))
		var a := float(star["a"]) * tw
		var pos := Vector2(
			origin.x + VIEW_W * 0.5 + float(star["x"]) * VIEW_W - parallax,
			origin.y + VIEW_H * 0.5 + float(star["y"]) * VIEW_H
		)
		var r := float(star["r"])
		draw_circle(pos, r, Color(0.92, 0.95, 0.98, a))
