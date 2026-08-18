extends Node2D

## Auto-turret: only fires when staffed by a hire. Strength scales fire rate + damage.
## Idle / default pose faces outward from the Main Hub (away from the tank).

const BULLET_SCENE := preload("res://Scenes/bullet.tscn")
const RANGE_PX := 140.0
const FIRE_COOLDOWN := 0.75
const MUZZLE_HEIGHT := -24.0

var _cooldown := 0.0
var _staff: Node = null
var _staff_strength := 1
## +1 face right (barrel default), -1 face left. Idle pose only; combat aim still tracks crabs.
var _idle_facing := 1.0
var _has_target := false
var _idle_locked := false


func _ready() -> void:
	add_to_group("turret")
	z_index = 1
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.texture = PlaceholderTurret.create_texture()
		sprite.position = PlaceholderTurret.SPRITE_OFFSET
	call_deferred("_init_idle_facing")


func _init_idle_facing() -> void:
	if _idle_locked:
		_apply_idle_facing()
		return
	var hub := get_tree().get_first_node_in_group("main_hub") as Node2D
	if hub:
		set_idle_facing_from_hub(hub)
	else:
		_apply_idle_facing()


## Face away from the hub. Call on place and when the hub is first built.
func set_idle_facing_from_hub(hub: Node2D) -> void:
	if hub == null or not is_instance_valid(hub):
		return
	set_idle_facing_from_hub_at(hub.global_position, global_position)


## Explicit positions avoid stale global_position on the place frame.
func set_idle_facing_from_hub_at(hub_world: Vector2, turret_world: Vector2) -> void:
	var dx := turret_world.x - hub_world.x
	if is_zero_approx(dx):
		_idle_facing = 1.0
	else:
		# Sign of (turret - hub): right of hub → face right (away); left → face left.
		_idle_facing = signf(dx)
	_idle_locked = true
	if not _has_target:
		_apply_idle_facing()


## No hub yet: face the side Mike placed from (away from placer origin).
func set_idle_facing_from_placer(placer_world: Vector2) -> void:
	var dx := global_position.x - placer_world.x
	if is_zero_approx(dx):
		_idle_facing = 1.0
	else:
		_idle_facing = signf(dx)
	_idle_locked = true
	_apply_idle_facing()


func _apply_idle_facing() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		# Art barrel points right when flip_h is false.
		sprite.flip_h = _idle_facing < 0.0


func is_staffed() -> bool:
	return is_instance_valid(_staff)


func is_staffed_by(hiree: Node) -> bool:
	return is_staffed() and _staff == hiree


func staff(hiree: Node, strength: int = 1) -> bool:
	if hiree == null or is_staffed():
		return false
	_staff = hiree
	_staff_strength = maxi(strength, 1)
	return true


func unstaff(hiree: Node = null) -> void:
	if hiree != null and _staff != hiree:
		return
	_staff = null
	_staff_strength = 1
	_has_target = false
	_apply_idle_facing()


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if not is_staffed():
		if _has_target:
			_has_target = false
			_apply_idle_facing()
		return
	var target := _nearest_enemy()
	if target == null:
		if _has_target:
			_has_target = false
			_apply_idle_facing()
		return
	_has_target = true
	if _cooldown > 0.0:
		# Keep facing the active target while cooling down.
		_face_dir(target.global_position - global_position)
		return
	_shoot_at(target)


func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_dist := RANGE_PX * RANGE_PX
	for node in get_tree().get_nodes_in_group("enemy"):
		if not node is Node2D or not is_instance_valid(node):
			continue
		var enemy := node as Node2D
		if "health" in enemy and int(enemy.health) <= 0:
			continue
		var dist := global_position.distance_squared_to(enemy.global_position)
		if dist <= best_dist:
			best_dist = dist
			best = enemy
	return best


func _face_dir(dir: Vector2) -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite and absf(dir.x) > 0.01:
		sprite.flip_h = dir.x < 0.0


func _shoot_at(target: Node2D) -> void:
	var rate := float(_staff_strength)
	_cooldown = FIRE_COOLDOWN / maxf(rate, 1.0)
	var muzzle := global_position + Vector2(0.0, MUZZLE_HEIGHT)
	var aim_at := target.global_position + Vector2(0.0, -8.0)
	var dir := (aim_at - muzzle).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	_face_dir(dir)

	var bullet := BULLET_SCENE.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle
	# Same bullet + ignore path as the player gun: hub/walls block but take no damage.
	bullet.setup(dir, self, _staff_strength)
