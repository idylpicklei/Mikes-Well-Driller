extends CharacterBody2D


const SPEED = 130.0
const JUMP_VELOCITY = -300.0
const MAX_JUMPS := 2

var spawn_position: Vector2
var fall_y := 10000.0
var jumps_remaining := MAX_JUMPS
var _restore_camera_smoothing := false


func _ready() -> void:
	spawn_position = global_position


func _physics_process(delta: float) -> void:
	if _restore_camera_smoothing:
		_set_camera_smoothing(true)
		_restore_camera_smoothing = false

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	if is_on_floor() and velocity.y >= 0:
		jumps_remaining = MAX_JUMPS

	if Input.is_action_just_pressed("jump") and jumps_remaining > 0:
		velocity.y = JUMP_VELOCITY
		jumps_remaining -= 1

	var direction := Input.get_axis("move_left", "move_right")
	if direction:
		velocity.x = direction * SPEED
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
	reset_physics_interpolation()

	var camera := _camera()
	if camera:
		camera.reset_smoothing()
		camera.force_update_scroll()
		camera.reset_physics_interpolation()

	_restore_camera_smoothing = true


func _camera() -> Camera2D:
	return get_viewport().get_camera_2d()


func _set_camera_smoothing(enabled: bool) -> void:
	var camera := _camera()
	if camera:
		camera.position_smoothing_enabled = enabled
