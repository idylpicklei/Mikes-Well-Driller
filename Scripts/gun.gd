extends Node2D

## Player gun. Glock is free default; shop guns unlock via GameResources.

const BULLET_SCENE := preload("res://Scenes/bullet.tscn")
const GRENADE_SCENE := preload("res://Scenes/energy_grenade.tscn")

const GLOCK_TEX := "res://Assets/sprites/desert_eagle.png"
const SAWN_TEX := "res://Assets/sprites/gun_shotgun.png"
const COIL_TEX := "res://Assets/sprites/gun_coil.png"

## Modest firerate bump (~25% shorter than 0.42); Glock only — not turret cadence.
const GLOCK_COOLDOWN := 0.315
const SAWN_COOLDOWN := 0.55
const COIL_COOLDOWN := 0.62

const GLOCK_RECOIL := 190.0
const SAWN_RECOIL := 280.0
const COIL_RECOIL := 140.0

const KICK_ANGLE := -0.55
const SHAKE_STRENGTH := 3.2
const GRENADE_THROW_SPEED := 220.0
const GRENADE_LOB_UP := -180.0

@onready var _muzzle: Marker2D = $Muzzle
@onready var _flash: Sprite2D = $Muzzle/MuzzleFlash
@onready var _sound: AudioStreamPlayer2D = $ShootSound
@onready var _sprite: Sprite2D = $Sprite2D

var _cooldown := 0.0
var _kick := 0.0
var _shake := 0.0
var _flash_time := 0.0
var _sprite_base_pos := Vector2.ZERO
var _muzzle_base_pos := Vector2.ZERO


func _ready() -> void:
	if _sprite:
		_sprite_base_pos = _sprite.position
	if _muzzle:
		_muzzle_base_pos = _muzzle.position
	if not GameResources.arsenal_changed.is_connected(_on_arsenal_changed):
		GameResources.arsenal_changed.connect(_on_arsenal_changed)
	_apply_equipped_visual()


func _on_arsenal_changed() -> void:
	_apply_equipped_visual()


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_update_flash(delta)
	if BuildMenu.block_shoot and not Input.is_action_pressed("shoot"):
		BuildMenu.block_shoot = false
	if ShopMenu.block_shoot and not Input.is_action_pressed("shoot"):
		ShopMenu.block_shoot = false
	if (
		BuildMenu.is_open
		or ShopMenu.is_open
		or BuildMenu.block_shoot
		or ShopMenu.block_shoot
		or BuildPlacer.is_placing
		or PauseMenu.is_open
	):
		_update_shake(delta)
		return
	_aim(delta)
	_update_shake(delta)

	if Input.is_action_just_pressed("cycle_weapon"):
		GameResources.cycle_gun()
		_apply_equipped_visual()

	if Input.is_action_just_pressed("throw_grenade"):
		_try_throw_grenade()

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
	var gun_id := GameResources.equipped_gun
	var aim := _aim_dir()
	_cooldown = _cooldown_for(gun_id)
	_kick = KICK_ANGLE
	_shake = SHAKE_STRENGTH
	_flash_time = 0.07
	_flash.visible = true
	_flash.rotation = randf_range(-0.4, 0.4)
	_sound.pitch_scale = randf_range(0.58, 0.72)
	_sound.play()

	match gun_id:
		GameResources.GUN_SAWN:
			_fire_sawn(aim)
		GameResources.GUN_COIL:
			_fire_coil(aim)
		_:
			_fire_glock(aim)

	var player := get_parent() as CharacterBody2D
	if player:
		player.velocity -= aim * _recoil_for(gun_id)


func _fire_glock(aim: Vector2) -> void:
	_spawn_bullet(aim, 1, 460.0, 1.25, Color.WHITE, Vector2(7, 3))


func _fire_sawn(aim: Vector2) -> void:
	# 3 pellets, tighter spread, twice the range (same speed).
	var spreads := [-0.12, 0.0, 0.12]
	for spread in spreads:
		var dir := aim.rotated(spread)
		_spawn_bullet(dir, 1, 300.0, 0.56, Color(0.92, 0.82, 0.62), Vector2(5, 2))


func _fire_coil(aim: Vector2) -> void:
	# Single fat energy bolt: slower fire, longer range, harder hit than Glock.
	_spawn_bullet(aim, 3, 520.0, 1.85, Color(0.45, 0.85, 1.0), Vector2(12, 5))


func _spawn_bullet(
	aim: Vector2,
	damage: int,
	speed: float,
	lifetime: float,
	modulate_color: Color,
	size: Vector2
) -> void:
	var bullet := BULLET_SCENE.instantiate()
	bullet.setup(aim, get_parent(), damage, speed, lifetime)
	if bullet.has_method("apply_look"):
		bullet.apply_look(modulate_color, size)
	elif bullet is CanvasItem:
		(bullet as CanvasItem).modulate = modulate_color
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = _muzzle.global_position


func _try_throw_grenade() -> void:
	if not GameResources.spend_grenade():
		return
	var aim := _aim_dir()
	var grenade := GRENADE_SCENE.instantiate()
	var velocity := aim * GRENADE_THROW_SPEED + Vector2(0.0, GRENADE_LOB_UP)
	if grenade.has_method("setup"):
		grenade.setup(velocity, get_parent())
	get_tree().current_scene.add_child(grenade)
	grenade.global_position = _muzzle.global_position


func _cooldown_for(gun_id: StringName) -> float:
	match gun_id:
		GameResources.GUN_SAWN:
			return SAWN_COOLDOWN
		GameResources.GUN_COIL:
			return COIL_COOLDOWN
		_:
			return GLOCK_COOLDOWN


func _recoil_for(gun_id: StringName) -> float:
	match gun_id:
		GameResources.GUN_SAWN:
			return SAWN_RECOIL
		GameResources.GUN_COIL:
			return COIL_RECOIL
		_:
			return GLOCK_RECOIL


func _apply_equipped_visual() -> void:
	if _sprite == null:
		return
	var path := GLOCK_TEX
	var muzzle_pos := _muzzle_base_pos
	var sprite_pos := _sprite_base_pos
	match GameResources.equipped_gun:
		GameResources.GUN_SAWN:
			path = SAWN_TEX
			muzzle_pos = Vector2(18, -2)
			sprite_pos = Vector2(6, -1)
		GameResources.GUN_COIL:
			path = COIL_TEX
			muzzle_pos = Vector2(16, -2)
			sprite_pos = Vector2(5, -1)
		_:
			path = GLOCK_TEX
			muzzle_pos = _muzzle_base_pos
			sprite_pos = _sprite_base_pos
	_sprite.texture = load(path) as Texture2D
	_sprite.position = sprite_pos
	if _muzzle:
		_muzzle.position = muzzle_pos


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
