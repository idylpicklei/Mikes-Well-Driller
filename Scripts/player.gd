extends CharacterBody2D


const SPEED = 130.0
const JUMP_VELOCITY = -300.0
const MAX_JUMPS := 2

var spawn_position: Vector2
var fall_y := 10000.0
var jumps_remaining := MAX_JUMPS
var _restore_camera_smoothing := false
var _move_dir := 0.0
var _jump_queued := false


func _ready() -> void:
	spawn_position = global_position


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
		velocity.y = JUMP_VELOCITY
		jumps_remaining -= 1
	_jump_queued = false

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
