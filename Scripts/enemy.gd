extends CharacterBody2D

const SPEED := 22.0
const JUMP_VELOCITY := -260.0
const MAX_HEALTH := 1

var health := MAX_HEALTH


func _ready() -> void:
	add_to_group("enemy")
	z_index = 2
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.texture = PlaceholderEnemy.create_texture()
		sprite.position = PlaceholderEnemy.SPRITE_OFFSET


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	var target := _target()
	if target:
		var dir := signf(target.global_position.x - global_position.x)
		velocity.x = dir * SPEED
	else:
		velocity.x = 0.0

	move_and_slide()
	if is_on_floor() and is_on_wall() and _walking_into_wall():
		velocity.y = JUMP_VELOCITY
	if global_position.y > 4000.0:
		queue_free()


func take_damage(amount: int) -> void:
	if health <= 0:
		return
	health = maxi(health - amount, 0)
	if health <= 0:
		queue_free()


func _walking_into_wall() -> bool:
	return signf(velocity.x) == -signf(get_wall_normal().x)


func _target() -> Node2D:
	var hub := get_tree().get_first_node_in_group("main_hub")
	if hub is Node2D:
		return hub as Node2D
	var player := get_tree().get_first_node_in_group("player")
	if player is Node2D:
		return player as Node2D
	return null
