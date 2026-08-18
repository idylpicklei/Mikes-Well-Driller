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
const PLAYER_CHASE_RANGE := 100.0
const PLAYER_DAMAGE := 10
const PLAYER_ATTACK_COOLDOWN := 0.8
const PLAYER_TOUCH_RANGE := 22.0

var max_health := MAX_HEALTH
var health := MAX_HEALTH
var _blocked_for := 0.0
var _last_x := INF
var _no_move_for := 0.0
var _stuck_jump_cd := 0.0
var _hub_attack_cd := 0.0
var _player_attack_cd := 0.0


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
	_apply_footprint_collision()


func _apply_footprint_collision() -> void:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return
	var rect := RectangleShape2D.new()
	rect.size = Vector2(PlaceholderEnemy.SIZE)
	shape_node.shape = rect
	shape_node.position = PlaceholderEnemy.SPRITE_OFFSET


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	var dir := 0.0
	var target := _target()
	if target:
		dir = signf(target.global_position.x - global_position.x)
	velocity.x = dir * SPEED

	move_and_slide()
	_reject_wall_ledges()
	if _attack_player(delta) or _attack_defend_target(delta):
		velocity.x = 0.0
	else:
		_hop_if_blocked(delta, dir)
		_hop_if_stuck(delta, dir)
	if global_position.y > 4000.0:
		queue_free()


func take_damage(amount: int) -> void:
	if health <= 0:
		return
	health = maxi(health - amount, 0)
	if health <= 0:
		queue_free()


func _hop_if_blocked(delta: float, dir: float) -> void:
	# Placed walls are a hard stop — never vault them.
	if _wall_blocks(dir):
		_blocked_for = 0.0
		return
	if is_on_floor() and dir != 0.0 and _is_blocked(dir):
		_blocked_for += delta
		if _blocked_for >= BLOCKED_TIME:
			velocity.y = JUMP_VELOCITY
			_blocked_for = 0.0
	else:
		_blocked_for = 0.0


func _hop_if_stuck(delta: float, dir: float) -> void:
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
	# Stuck against a wall must not trigger the bigger vault jump.
	if _wall_blocks(dir):
		return

	velocity.y = STUCK_JUMP_VELOCITY
	_stuck_jump_cd = STUCK_JUMP_COOLDOWN


func _wall_blocks(dir: float) -> bool:
	if dir == 0.0:
		return false
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var other := col.get_collider()
		if other is Node and (other as Node).is_in_group("wall"):
			# Touching a wall on the travel side is always a hard stop.
			if absf(col.get_normal().x) > 0.3 and signf(dir) == -signf(col.get_normal().x):
				return true
			if other is Node2D and signf((other as Node2D).global_position.x - global_position.x) == signf(dir):
				return true

	# Probe ahead within hop clearance so a short vault cannot clear a 16×32 wall.
	var space := get_world_2d().direct_space_state
	var probe := RectangleShape2D.new()
	var body_h := float(PlaceholderEnemy.SIZE.y)
	var body_w := float(PlaceholderEnemy.SIZE.x)
	probe.size = Vector2(36.0, maxf(body_h - 4.0, 8.0))
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = probe
	params.transform = Transform2D(
		0.0,
		global_position + Vector2(dir * (body_w * 0.5 + 20.0), -body_h * 0.5)
	)
	params.collision_mask = collision_mask
	params.exclude = [get_rid()]
	params.collide_with_areas = false
	params.collide_with_bodies = true
	for result in space.intersect_shape(params, 8):
		var collider: Variant = result.get("collider")
		if collider is Node and (collider as Node).is_in_group("wall"):
			return true
	return false


## Walls are hard stops, not platforms — don't walk across their tops.
func _reject_wall_ledges() -> void:
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var other := col.get_collider()
		if not (other is Node and (other as Node).is_in_group("wall")):
			continue
		if col.get_normal().y < -0.5:
			velocity.y = maxf(velocity.y, 120.0)
			# Nudge off the ledge toward the side we came from.
			if other is Node2D:
				var away := signf(global_position.x - (other as Node2D).global_position.x)
				if away == 0.0:
					away = -1.0
				global_position.x += away * 2.0
			return


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


func _attack_player(delta: float) -> bool:
	_player_attack_cd = maxf(_player_attack_cd - delta, 0.0)
	var victim := _touching_player_or_hiree()
	if victim == null:
		return false
	if _player_attack_cd <= 0.0 and victim.has_method("take_damage"):
		victim.take_damage(PLAYER_DAMAGE)
		_player_attack_cd = PLAYER_ATTACK_COOLDOWN
	return true


func _touching_player_or_hiree() -> Node:
	for i in get_slide_collision_count():
		var other := get_slide_collision(i).get_collider()
		if other is Node:
			var n := other as Node
			if n.is_in_group("player") or n.is_in_group("hiree"):
				return n
	var player := get_tree().get_first_node_in_group("player")
	if player is Node2D and global_position.distance_to((player as Node2D).global_position) <= PLAYER_TOUCH_RANGE:
		return player
	for node in get_tree().get_nodes_in_group("hiree"):
		if node is Node2D and global_position.distance_to((node as Node2D).global_position) <= PLAYER_TOUCH_RANGE:
			return node
	return null


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
	var player := get_tree().get_first_node_in_group("player")
	if player is Node2D:
		var p := player as Node2D
		if global_position.distance_to(p.global_position) <= PLAYER_CHASE_RANGE:
			return p
	var hub := get_tree().get_first_node_in_group("main_hub")
	if hub is Node2D:
		return hub as Node2D
	if player is Node2D:
		return player as Node2D
	return null
