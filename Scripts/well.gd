extends Node2D

const DEPLOY_TIME := 30.0
const PRODUCE_TIME := 15.0
const PRODUCE_AMOUNT := 1
const BAR_SIZE := Vector2(28, 4)
const DRILL_MULTIPLIER := 2.0

var _deployed := false
var _timer := 0.0
var _sprite: Sprite2D
var _efficiency := 1.0
var _produce_time := PRODUCE_TIME
var _drill_multiplier := 1.0
var _attached_drill: Node = null


func _ready() -> void:
	add_to_group("well")
	z_index = 1
	_sprite = get_node_or_null("Sprite2D") as Sprite2D
	if _sprite:
		_sprite.texture = PlaceholderWell.create_texture()
		_sprite.position = PlaceholderWell.SPRITE_OFFSET
		_sprite.modulate = Color(0.7, 0.7, 0.72)
	_timer = 0.0
	call_deferred("_resolve_efficiency")
	set_process(true)


func gallons_per_minute() -> float:
	if not _deployed or _produce_time <= 0.0:
		return 0.0
	return 60.0 * float(PRODUCE_AMOUNT) / _produce_time


func has_drill() -> bool:
	return is_instance_valid(_attached_drill)


func attach_drill(drill: Node) -> bool:
	if drill == null or has_drill():
		return false
	_attached_drill = drill
	_drill_multiplier = DRILL_MULTIPLIER
	_recompute_produce_time()
	return true


func detach_drill(drill: Node) -> void:
	if _attached_drill != drill:
		return
	_attached_drill = null
	_drill_multiplier = 1.0
	_recompute_produce_time()


func _resolve_efficiency() -> void:
	_efficiency = WellEfficiency.at_world(global_position)
	_recompute_produce_time()


func _recompute_produce_time() -> void:
	_produce_time = PRODUCE_TIME / maxf(_efficiency, 0.01) / maxf(_drill_multiplier, 0.01)
	queue_redraw()


func _process(delta: float) -> void:
	_timer += delta
	if _deployed:
		if _timer >= _produce_time:
			_timer -= _produce_time
			GameResources.add_water(PRODUCE_AMOUNT)
	elif _timer >= DEPLOY_TIME:
		_timer = 0.0
		_deployed = true
		if _sprite:
			_sprite.modulate = Color.WHITE
	queue_redraw()


func _draw() -> void:
	var duration := _produce_time if _deployed else DEPLOY_TIME
	if duration <= 0.0:
		duration = DEPLOY_TIME
	var progress := clampf(_timer / duration, 0.0, 1.0)
	var top := PlaceholderWell.SPRITE_OFFSET.y - PlaceholderWell.SIZE.y * 0.5 - 8.0
	var origin := Vector2(-BAR_SIZE.x * 0.5, top)
	draw_rect(Rect2(origin, BAR_SIZE), Color(0.08, 0.09, 0.1, 0.9))
	var fill := Color("3d6ea8") if _deployed else Color("d98a2b")
	draw_rect(Rect2(origin, Vector2(BAR_SIZE.x * progress, BAR_SIZE.y)), fill)
	draw_rect(Rect2(origin, BAR_SIZE), Color(0.05, 0.05, 0.06, 0.9), false, 1.0)
