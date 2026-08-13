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
	global_position += direction * SPEED * delta


func _on_body_entered(body: Node2D) -> void:
	if body == _ignore:
		return
	queue_free()
