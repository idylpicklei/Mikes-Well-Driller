extends CharacterBody2D


signal health_changed(current: int, maximum: int)
signal died

const SPEED = 130.0
const JUMP_VELOCITY = -300.0
const MAX_JUMPS := 2
const MAX_HEALTH := 50
## While overlapping acid ocean: body sits lower and jumps shorter.
const ACID_JUMP_SCALE := 0.65
const ACID_JUMP_DRAG := 420.0
const ACID_SINK_VISUAL_PX := 6.0
const ACID_SINK_COLLISION_PX := 3.0

var spawn_position: Vector2
var fall_y := 10000.0
var jumps_remaining := MAX_JUMPS
var health := MAX_HEALTH
var _restore_camera_smoothing := false
var _move_dir := 0.0
var _jump_queued := false
var _dead := false
var _acid_overlaps := 0
var _sprite_base_pos := Vector2.ZERO
var _collision_base_pos := Vector2.ZERO
var _gun_base_pos := Vector2.ZERO


func _ready() -> void:
	add_to_group("player")
	spawn_position = global_position
	var sprite := get_node_or_null("AnimatedSprite2D") as Node2D
	if sprite:
		_sprite_base_pos = sprite.position
	var shape := get_node_or_null("CollisionShape2D") as Node2D
	if shape:
		_collision_base_pos = shape.position
	var gun := get_node_or_null("Gun") as Node2D
	if gun:
		_gun_base_pos = gun.position
	health_changed.emit(health, MAX_HEALTH)


func take_damage(amount: int) -> void:
	if _dead or amount <= 0:
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health, MAX_HEALTH)
	if health <= 0:
		_dead = true
		died.emit()
		set_physics_process(false)
		set_process_input(false)


func notify_acid_entered() -> void:
	_acid_overlaps += 1
	_apply_acid_pose()


func notify_acid_exited() -> void:
	_acid_overlaps = maxi(_acid_overlaps - 1, 0)
	_apply_acid_pose()


func is_in_acid() -> bool:
	return _acid_overlaps > 0


func _apply_acid_pose() -> void:
	var sink_v := ACID_SINK_VISUAL_PX if is_in_acid() else 0.0
	var sink_c := ACID_SINK_COLLISION_PX if is_in_acid() else 0.0
	var sprite := get_node_or_null("AnimatedSprite2D") as Node2D
	if sprite:
		sprite.position = _sprite_base_pos + Vector2(0.0, sink_v)
	var shape := get_node_or_null("CollisionShape2D") as Node2D
	if shape:
		shape.position = _collision_base_pos + Vector2(0.0, sink_c)
	var gun := get_node_or_null("Gun") as Node2D
	if gun:
		gun.position = _gun_base_pos + Vector2(0.0, sink_v)


func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("move_left"):
		_move_dir = -1.0
	elif event.is_action_pressed("move_right"):
		_move_dir = 1.0
	elif event.is_action_released("move_left"):
		_move_dir = 1.0 if Input.is_action_pressed("move_right") else 0.0
	elif event.is_action_released("move_right"):
		_move_dir = -1.0 if Input.is_action_pressed("move_left") else 0.0
	if event.is_action_pressed("jump"):
		_jump_queued = true


func _physics_process(delta: float) -> void:
	if _restore_camera_smoothing:
		_set_camera_smoothing(true)
		_restore_camera_smoothing = false

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	if is_on_floor() and velocity.y >= 0:
		jumps_remaining = MAX_JUMPS

	if _jump_queued and jumps_remaining > 0:
		var jump_v := JUMP_VELOCITY
		if is_in_acid():
			jump_v *= ACID_JUMP_SCALE
		velocity.y = jump_v
		jumps_remaining -= 1
	_jump_queued = false

	# Extra upward drag in acid so jumps feel short even mid-air.
	if is_in_acid() and velocity.y < 0.0:
		velocity.y = move_toward(velocity.y, 0.0, ACID_JUMP_DRAG * delta)

	if _move_dir != 0.0:
		velocity.x = _move_dir * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
	_free_from_solids()

	if global_position.y > fall_y:
		respawn()


func _free_from_solids() -> void:
	if not _overlaps_solids():
		return
	var start := global_position
	for _i in 48:
		global_position.y -= 2.0
		if not _overlaps_solids():
			velocity.y = minf(velocity.y, 0.0)
			reset_physics_interpolation()
			return
	global_position = start


func _overlaps_solids() -> bool:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or shape_node.shape == null:
		return false
	var space := get_world_2d().direct_space_state
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape_node.shape
	params.transform = shape_node.global_transform
	params.collision_mask = collision_mask
	params.exclude = [get_rid()]
	return not space.intersect_shape(params, 1).is_empty()


func respawn() -> void:
	_set_camera_smoothing(false)

	global_position = spawn_position
	velocity = Vector2.ZERO
	jumps_remaining = MAX_JUMPS
	_jump_queued = false
	_acid_overlaps = 0
	_apply_acid_pose()
	_refresh_move_dir()
	reset_physics_interpolation()

	var camera := _camera()
	if camera:
		camera.reset_smoothing()
		camera.force_update_scroll()
		camera.reset_physics_interpolation()

	_restore_camera_smoothing = true


func _refresh_move_dir() -> void:
	var left := Input.is_action_pressed("move_left")
	var right := Input.is_action_pressed("move_right")
	if left and not right:
		_move_dir = -1.0
	elif right and not left:
		_move_dir = 1.0
	elif not left and not right:
		_move_dir = 0.0


func _camera() -> Camera2D:
	return get_viewport().get_camera_2d()


func _set_camera_smoothing(enabled: bool) -> void:
	var camera := _camera()
	if camera:
		camera.position_smoothing_enabled = enabled
