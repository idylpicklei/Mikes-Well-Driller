extends Area2D


const SPEED := 460.0
const LIFETIME := 1.25

var direction := Vector2.RIGHT
var _ignore: Node


func setup(dir: Vector2, shooter: Node) -> void:
	direction = dir.normalized()
	rotation = direction.angle()
	_ignore = shooter


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	var motion := direction * SPEED * delta
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
	queue_free()
	return true


func _on_body_entered(body: Node2D) -> void:
	if body == _ignore:
		return
	queue_free()
