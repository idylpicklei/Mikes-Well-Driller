extends Node2D

## Far + mid rolling hills — seamless horizontal tiles, not random stamps.
## Draw stack: sky → stars → hills_far → clouds → hills_mid → terrain/Mike.
## Horizontal parallax from camera X only (no autonomous scroll).
## Hop dampened (a little, not locked).
##
## Drop-ins: Assets/sprites/hills_far.png, hills_mid.png
## Recut sheets: 320×96 / 320×72 (tileable X, opaque ridge→bottom).
## Tile step = texture width; height is read from the sheet.

const HILLS_FAR_PATH := "res://Assets/sprites/hills_far.png"
const HILLS_MID_PATH := "res://Assets/sprites/hills_mid.png"
const HILLS_PATH := "res://Assets/sprites/hills.png"
const MOUNTAINS_PATH := "res://Assets/sprites/mountains.png"

const COL_FAR := Color(0.10, 0.14, 0.22, 0.95)
const COL_NEAR := Color(0.14, 0.12, 0.18, 0.98)
const COL_RIM := Color(0.55, 0.28, 0.22, 0.55)
## Fallback fill = dark mountain teal/brown (matches sheet bottoms), never sky navy.
const FILL_FAR := Color(40.0 / 255.0, 54.0 / 255.0, 73.0 / 255.0, 1.0)
const FILL_MID := Color(57.0 / 255.0, 34.0 / 255.0, 26.0 / 255.0, 1.0)

const VIEW_W := 1280.0
const VIEW_H := 720.0
## Extra fill below the strip so sky never peeks under the range.
const FILL_DOWN := 900.0
const FAR_Z := -100
const MID_Z := -70
## Sit strip bottoms on/near ground (camera baseline + this ≈ player feet).
const GROUND_FROM_BASELINE := 52.0

var _far_tex: Texture2D
var _mid_tex: Texture2D
var _far_band: Dictionary = {}
var _mid_band: Dictionary = {}
var _mid_draw: Node2D
var _y_baseline := 0.0
var _baseline_ready := false


func _ready() -> void:
	z_index = FAR_Z
	z_as_relative = false
	y_sort_enabled = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var far_path := _resolve_far_path()
	var mid_path := HILLS_MID_PATH if ResourceLoader.exists(HILLS_MID_PATH) else ""
	_far_tex = load(far_path) as Texture2D if far_path != "" else null
	_mid_tex = load(mid_path) as Texture2D if mid_path != "" else null
	if _far_tex:
		_far_band = _build_tile_band(_far_tex, far_path, FAR_Z, FILL_FAR)
	if _mid_tex:
		_mid_band = _build_tile_band(_mid_tex, mid_path, MID_Z, FILL_MID)
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


func _resolve_far_path() -> String:
	if ResourceLoader.exists(HILLS_FAR_PATH):
		return HILLS_FAR_PATH
	if ResourceLoader.exists(HILLS_PATH):
		return HILLS_PATH
	if ResourceLoader.exists(MOUNTAINS_PATH):
		return MOUNTAINS_PATH
	return ""


## Edge-to-edge copies at scale 1. Count covers the viewport + wrap margin.
## Fill polygon sits under the strip so everything below the ridge stays opaque.
func _build_tile_band(tex: Texture2D, source_path: String, band_z: int, fallback_fill: Color) -> Dictionary:
	var tile_w := maxf(float(tex.get_width()), 1.0)
	var tile_h := maxf(float(tex.get_height()), 1.0)
	var count := int(ceil(VIEW_W / tile_w)) + 3
	var sprites: Array[Sprite2D] = []
	var fill := Polygon2D.new()
	fill.z_as_relative = false
	fill.z_index = band_z
	fill.color = _sample_bottom_fill(tex, source_path, fallback_fill)
	add_child(fill)

	for _i in count:
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.z_as_relative = false
		sprite.z_index = band_z
		sprite.flip_h = false
		sprite.scale = Vector2.ONE
		add_child(sprite)
		sprites.append(sprite)

	return {
		"tex": tex,
		"sprites": sprites,
		"fill": fill,
		"tile_w": tile_w,
		"tile_h": tile_h,
	}


func _sample_bottom_fill(tex: Texture2D, source_path: String, fallback: Color) -> Color:
	# CompressedTexture2D.get_image() is often null — load the PNG bytes instead.
	var img: Image = null
	if tex:
		img = tex.get_image()
	if img == null and source_path != "" and ResourceLoader.exists(source_path):
		img = Image.new()
		if img.load(source_path) != OK:
			img = null
	if img == null and tex and tex.resource_path != "":
		img = Image.new()
		if img.load(tex.resource_path) != OK:
			img = null
	if img == null:
		return fallback
	var y := img.get_height() - 1
	if y < 0:
		return fallback
	var x := mini(img.get_width() - 1, img.get_width() / 2)
	var c := img.get_pixel(maxi(x, 0), y)
	if c.a < 0.05:
		return fallback
	c.a = 1.0
	return c


func _capture_y_baseline() -> void:
	_y_baseline = _camera_center().y
	_baseline_ready = true
	queue_redraw()


func _process(_delta: float) -> void:
	if not _baseline_ready:
		_capture_y_baseline()
	# Camera X only — no time-based phase drift / autonomous scroll.
	if not _far_band.is_empty():
		_update_tile_band(_far_band, 0.045, 0.0, 0.012)
	if not _mid_band.is_empty():
		_update_tile_band(_mid_band, 0.085, 14.0, 0.020)
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


func _band_top_y(center: Vector2, y_bias: float, hop_scale: float, tile_h: float) -> float:
	# Sit the opaque strip bottom on/near the ground line so the mountain
	# body meets the dirt; fill continues below for any remaining gap.
	var baseline := _y_baseline if _baseline_ready else center.y
	var hop := (center.y - baseline) * hop_scale
	var ground_y := baseline + GROUND_FROM_BASELINE + y_bias + hop
	return ground_y - tile_h


func _update_tile_band(
	band: Dictionary,
	parallax: float,
	y_bias: float,
	hop_scale: float
) -> void:
	var center := _camera_center()
	var tile_w: float = float(band["tile_w"])
	var tile_h: float = float(band["tile_h"])
	var sprites: Array = band["sprites"]
	var fill: Polygon2D = band["fill"]
	var top_y := _band_top_y(center, y_bias, hop_scale, tile_h)
	var scroll := center.x * parallax
	var view_left := center.x - VIEW_W * 0.5
	# Snap the first tile so copies sit edge-to-edge and wrap seamlessly.
	var first_x := view_left - fposmod(view_left - scroll, tile_w)
	for i in sprites.size():
		var sprite: Sprite2D = sprites[i]
		sprite.global_position = Vector2(first_x + float(i) * tile_w, top_y)

	var cover_w := float(sprites.size()) * tile_w + 4.0
	var bottom_y := top_y + tile_h
	fill.global_position = Vector2(first_x - 2.0, bottom_y)
	fill.polygon = PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(cover_w, 0.0),
		Vector2(cover_w, FILL_DOWN),
		Vector2(0.0, FILL_DOWN),
	])


func _draw() -> void:
	if _far_tex != null:
		return
	var center := _camera_center()
	var band_y := _band_top_y(center, -4.0, 0.012, 48.0) + 24.0
	_draw_ridge(self, center.x, band_y, center.x * 0.04, COL_FAR, 1.0, 0)


func draw_mid_procedural_into(canvas: CanvasItem) -> void:
	if _mid_tex != null:
		return
	var center := _camera_center()
	var band_y := _band_top_y(center, 10.0, 0.020, 40.0) + 20.0
	_draw_ridge(canvas, center.x, band_y, center.x * 0.07, COL_NEAR, 0.85, 17)


func _draw_ridge(
	canvas: CanvasItem,
	cam_x: float,
	base_y: float,
	scroll: float,
	color: Color,
	height_mul: float,
	seed_off: int
) -> void:
	var width := VIEW_W + 400.0
	var origin_x := cam_x - width * 0.5
	var points := PackedVector2Array()
	# Solid fill from ridge down past the playfield (same job as the sprite fill).
	points.append(Vector2(origin_x - 40.0, base_y + FILL_DOWN))
	var steps := 28
	for i in steps + 1:
		var t := float(i) / float(steps)
		var x := origin_x + t * width
		var n := sin((x + scroll) * 0.0042 + float(seed_off)) * 42.0
		n += sin((x + scroll) * 0.011 + float(seed_off) * 0.7) * 22.0 * height_mul
		n += sin((x + scroll) * 0.023 + 1.3) * 10.0
		points.append(Vector2(x, base_y - n * height_mul))
	points.append(Vector2(origin_x + width + 40.0, base_y + FILL_DOWN))
	canvas.draw_colored_polygon(points, color)
	var rim := PackedVector2Array()
	for i in range(1, points.size() - 1):
		rim.append(points[i])
	if rim.size() >= 2:
		canvas.draw_polyline(rim, COL_RIM, 2.0, true)
