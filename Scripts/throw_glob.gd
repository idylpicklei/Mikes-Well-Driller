extends Area2D

## Gravity lob from thrower aliens. Hits Mike/hirees harder than the hub tank.

const LIFETIME := 2.5
const PLAYER_DAMAGE := 8
const HUB_DAMAGE := 4

var velocity := Vector2.ZERO
var _ignore: Node
var _spent := false


func setup(initial_velocity: Vector2, shooter: Node) -> void:
	velocity = initial_velocity
	_ignore = shooter


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.texture = PlaceholderThrowGlob.create_texture()
		sprite.centered = true
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)


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
	var collider: Variant = hit.get("collider")
	if collider is Node:
		_apply_hit(collider as Node)
	else:
		queue_free()
	return true


func _on_body_entered(body: Node2D) -> void:
	_apply_hit(body)


func _apply_hit(node: Node) -> void:
	if _spent or node == _ignore:
		return
	if node.is_in_group("enemy") or node.is_in_group("alien_ship") or node.is_in_group("enemy_spawner"):
		return
	_spent = true
	if node.is_in_group("wall"):
		queue_free()
		return
	if node.has_method("take_damage"):
		var amount := HUB_DAMAGE if node.is_in_group("defend_target") else PLAYER_DAMAGE
		node.take_damage(amount)
	queue_free()
