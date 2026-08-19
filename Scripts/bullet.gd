extends Area2D


const SPEED := 460.0
const LIFETIME := 1.25

var direction := Vector2.RIGHT
var _ignore: Node
var _spent := false
var _damage := 1
var _speed := SPEED
var _lifetime := LIFETIME


func setup(
	dir: Vector2,
	shooter: Node,
	damage: int = 1,
	speed: float = SPEED,
	lifetime: float = LIFETIME
) -> void:
	direction = dir.normalized()
	rotation = direction.angle()
	_ignore = shooter
	_damage = maxi(damage, 1)
	_speed = maxf(speed, 1.0)
	_lifetime = maxf(lifetime, 0.05)


func apply_look(modulate_color: Color, size: Vector2) -> void:
	modulate = modulate_color
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite and size.x > 0.0 and size.y > 0.0:
		var tex := sprite.texture
		if tex:
			var base := Vector2(tex.get_width(), tex.get_height())
			if base.x > 0.0 and base.y > 0.0:
				sprite.scale = Vector2(size.x / base.x, size.y / base.y)
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node and shape_node.shape is RectangleShape2D:
		(shape_node.shape as RectangleShape2D).size = size


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(_lifetime).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	var motion := direction * _speed * delta
	if _hit_world(global_position, global_position + motion):
		return
	global_position += motion


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
	_spent = true
	# Friendly structures / hires block shots but are not damaged by the player.
	if node.is_in_group("defend_target") or node.is_in_group("wall") or node.is_in_group("hiree"):
		queue_free()
		return
	if node.has_method("take_damage"):
		node.take_damage(_damage)
	queue_free()
