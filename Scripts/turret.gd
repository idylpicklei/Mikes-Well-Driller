extends Node2D

## Auto-turret: only fires when staffed by a hire. Strength scales fire rate + damage.

const BULLET_SCENE := preload("res://Scenes/bullet.tscn")
const RANGE_PX := 140.0
const FIRE_COOLDOWN := 0.75
const MUZZLE_HEIGHT := -24.0

var _cooldown := 0.0
var _staff: Node = null
var _staff_strength := 1


func _ready() -> void:
	add_to_group("turret")
	z_index = 1
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.texture = PlaceholderTurret.create_texture()
		sprite.position = PlaceholderTurret.SPRITE_OFFSET


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


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if not is_staffed():
		return
	if _cooldown > 0.0:
		return
	var target := _nearest_enemy()
	if target == null:
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


func _shoot_at(target: Node2D) -> void:
	var rate := float(_staff_strength)
	_cooldown = FIRE_COOLDOWN / maxf(rate, 1.0)
	var muzzle := global_position + Vector2(0.0, MUZZLE_HEIGHT)
	var aim_at := target.global_position + Vector2(0.0, -8.0)
	var dir := (aim_at - muzzle).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.flip_h = dir.x < 0.0

	var bullet := BULLET_SCENE.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle
	# Same bullet + ignore path as the player gun: hub/walls block but take no damage.
	bullet.setup(dir, self, _staff_strength)
