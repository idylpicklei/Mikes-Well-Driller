extends CharacterBody2D

const SPEED := 22.0
const JUMP_VELOCITY := -260.0
const STUCK_JUMP_VELOCITY := -340.0
const STUCK_SPEED := 8.0
const BLOCKED_TIME := 0.08
const STUCK_MOVE := 8.0
const STUCK_SECONDS := 2.5
const STUCK_JUMP_COOLDOWN := 0.45
const MAX_HEALTH := 1
const HUB_DAMAGE := 5
const HUB_ATTACK_COOLDOWN := 1.0

var max_health := MAX_HEALTH
var health := MAX_HEALTH
var _blocked_for := 0.0
var _last_x := INF
var _no_move_for := 0.0
var _stuck_jump_cd := 0.0
var _hub_attack_cd := 0.0


func configure(hp: int) -> void:
	max_health = maxi(hp, 1)
	health = max_health


func _ready() -> void:
	add_to_group("enemy")
	z_index = 2
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.texture = PlaceholderEnemy.create_texture()
		sprite.position = PlaceholderEnemy.SPRITE_OFFSET
		if max_health > 1:
			# Tough enemies read slightly darker so 2-HP is noticeable without new art.
			sprite.modulate = Color(0.82, 0.72, 0.72, 1.0)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	var dir := 0.0
	var target := _target()
	if target:
		dir = signf(target.global_position.x - global_position.x)
	velocity.x = dir * SPEED

	move_and_slide()
	if _attack_defend_target(delta):
		velocity.x = 0.0
	else:
		_hop_if_blocked(delta, dir)
		_hop_if_stuck(delta)
	if global_position.y > 4000.0:
		queue_free()


func take_damage(amount: int) -> void:
	if health <= 0:
		return
	health = maxi(health - amount, 0)
	if health <= 0:
		queue_free()


func _hop_if_blocked(delta: float, dir: float) -> void:
	if is_on_floor() and dir != 0.0 and _is_blocked(dir):
		_blocked_for += delta
		if _blocked_for >= BLOCKED_TIME:
			velocity.y = JUMP_VELOCITY
			_blocked_for = 0.0
	else:
		_blocked_for = 0.0


func _hop_if_stuck(delta: float) -> void:
	_stuck_jump_cd = maxf(_stuck_jump_cd - delta, 0.0)
	if _last_x == INF:
		_last_x = global_position.x
		return

	if absf(global_position.x - _last_x) >= STUCK_MOVE:
		_no_move_for = 0.0
		_last_x = global_position.x
		return

	_no_move_for += delta
	if _no_move_for < STUCK_SECONDS or _stuck_jump_cd > 0.0:
		return

	velocity.y = STUCK_JUMP_VELOCITY
	_stuck_jump_cd = STUCK_JUMP_COOLDOWN


func _is_blocked(dir: float) -> bool:
	if is_on_wall() and signf(dir) == -signf(get_wall_normal().x):
		return true
	if absf(get_real_velocity().x) < STUCK_SPEED:
		return true
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var other := col.get_collider()
		if other is Node and (other as Node).is_in_group("enemy"):
			return true
		if absf(col.get_normal().x) > 0.6 and signf(dir) == -signf(col.get_normal().x):
			return true
	return false


func _attack_defend_target(delta: float) -> bool:
	_hub_attack_cd = maxf(_hub_attack_cd - delta, 0.0)
	var hub: Node = null
	for i in get_slide_collision_count():
		var other := get_slide_collision(i).get_collider()
		if other is Node and (other as Node).is_in_group("defend_target"):
			hub = other as Node
			break
	if hub == null:
		return false
	if _hub_attack_cd <= 0.0 and hub.has_method("take_damage"):
		hub.take_damage(HUB_DAMAGE)
		_hub_attack_cd = HUB_ATTACK_COOLDOWN
	return true


func _target() -> Node2D:
	var hub := get_tree().get_first_node_in_group("main_hub")
	if hub is Node2D:
		return hub as Node2D
	var player := get_tree().get_first_node_in_group("player")
	if player is Node2D:
		return player as Node2D
	return null
