extends Node2D


const BULLET_SCENE := preload("res://Scenes/bullet.tscn")
const FIRE_COOLDOWN := 0.42
const RECOIL := 190.0
const KICK_ANGLE := -0.55
const SHAKE_STRENGTH := 3.2

@onready var _muzzle: Marker2D = $Muzzle
@onready var _flash: Sprite2D = $Muzzle/MuzzleFlash
@onready var _sound: AudioStreamPlayer2D = $ShootSound

var _cooldown := 0.0
var _kick := 0.0
var _shake := 0.0
var _flash_time := 0.0


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_update_flash(delta)
	if BuildMenu.is_open:
		_update_shake(delta)
		return
	_aim(delta)
	_update_shake(delta)

	if Input.is_action_just_pressed("shoot") and _cooldown <= 0.0:
		_shoot()


func _aim(delta: float) -> void:
	var aim := _aim_dir()
	rotation = aim.angle() + _kick
	if absf(aim.x) > 0.05:
		scale.y = -1.0 if aim.x < 0.0 else 1.0
	_kick = move_toward(_kick, 0.0, delta * 9.0)

	var player_sprite := get_parent().get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if player_sprite and absf(aim.x) > 0.12:
		player_sprite.flip_h = aim.x < 0.0


func _aim_dir() -> Vector2:
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length_squared() > 16.0:
		return to_mouse.normalized()
	return Vector2.LEFT if scale.y < 0.0 else Vector2.RIGHT


func _shoot() -> void:
	var aim := _aim_dir()
	_cooldown = FIRE_COOLDOWN
	_kick = KICK_ANGLE
	_shake = SHAKE_STRENGTH
	_flash_time = 0.07
	_flash.visible = true
	_flash.rotation = randf_range(-0.4, 0.4)
	_sound.pitch_scale = randf_range(0.58, 0.72)
	_sound.play()

	var bullet := BULLET_SCENE.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = _muzzle.global_position
	bullet.setup(aim, get_parent())

	var player := get_parent() as CharacterBody2D
	if player:
		player.velocity -= aim * RECOIL


func _update_flash(delta: float) -> void:
	if _flash_time <= 0.0:
		_flash.visible = false
		return
	_flash_time -= delta
	if _flash_time <= 0.0:
		_flash.visible = false


func _update_shake(delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	if _shake <= 0.0:
		camera.offset = Vector2.ZERO
		return
	_shake = move_toward(_shake, 0.0, delta * 26.0)
	camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
