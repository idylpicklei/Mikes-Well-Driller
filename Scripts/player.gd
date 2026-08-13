extends CharacterBody2D


const SPEED = 130.0
const JUMP_VELOCITY = -300.0
const FALL_Y := 180.0
const MAX_JUMPS := 2

var spawn_position: Vector2
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

	if Input.is_action_just_pressed("ui_accept") and jumps_remaining > 0:
		velocity.y = JUMP_VELOCITY
		jumps_remaining -= 1

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

	if global_position.y > FALL_Y:
		respawn()


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
