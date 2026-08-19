extends Area2D

## Arc-lob energy grenade. Splash hurts enemies, ships, and Mike if he's in the blast.

const LIFETIME := 2.8
const SPLASH_RADIUS := 42.0
const ENEMY_DAMAGE := 4
const SHIP_DAMAGE := 3
const PLAYER_DAMAGE := 6
const TEXTURE_PATH := "res://Assets/sprites/energy_grenade.png"

var velocity := Vector2.ZERO
var _ignore: Node
var _spent := false


func setup(initial_velocity: Vector2, thrower: Node) -> void:
	velocity = initial_velocity
	_ignore = thrower


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.texture = load(TEXTURE_PATH) as Texture2D
		sprite.centered = true
	get_tree().create_timer(LIFETIME).timeout.connect(_detonate)


func _physics_process(delta: float) -> void:
	if _spent:
		return
	velocity.y += float(ProjectSettings.get_setting("physics/2d/default_gravity")) * delta
	var motion := velocity * delta
	if _hit_world(global_position, global_position + motion):
		return
	global_position += motion
	if global_position.y > 4000.0:
		queue_free()


func _hit_world(from: Vector2, to: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = collision_mask
	query.hit_from_inside = true
	if _ignore is CollisionObject2D:
		query.exclude = [(_ignore as CollisionObject2D).get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return false
	global_position = hit.position
	_detonate()
	return true


func _on_body_entered(body: Node2D) -> void:
	if _spent or body == _ignore:
		return
	# Walls / ground / anything solid: explode on contact.
	_detonate()


func _detonate() -> void:
	if _spent:
		return
	_spent = true
	_apply_splash()
	queue_free()


func _apply_splash() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var origin := global_position
	var r2 := SPLASH_RADIUS * SPLASH_RADIUS
	for node in tree.get_nodes_in_group("enemy"):
		_damage_if_in_range(node, origin, r2, ENEMY_DAMAGE)
	for node in tree.get_nodes_in_group("alien_ship"):
		_damage_if_in_range(node, origin, r2, SHIP_DAMAGE)
	for node in tree.get_nodes_in_group("enemy_spawner"):
		_damage_if_in_range(node, origin, r2, SHIP_DAMAGE)
	# Friendly fire: Mike can eat his own blast.
	for node in tree.get_nodes_in_group("player"):
		_damage_if_in_range(node, origin, r2, PLAYER_DAMAGE)


func _damage_if_in_range(node: Node, origin: Vector2, r2: float, amount: int) -> void:
	if node == null or not is_instance_valid(node):
		return
	if not node is Node2D:
		return
	if (node as Node2D).global_position.distance_squared_to(origin) > r2:
		return
	if node.has_method("take_damage"):
		node.take_damage(amount)
