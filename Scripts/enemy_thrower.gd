extends CharacterBody2D

## Ranged thrower: slower than crabs, plants and lobs with a long windup.

const SPEED := 14.0
const JUMP_VELOCITY := -260.0
const STUCK_JUMP_VELOCITY := -340.0
const STUCK_SPEED := 8.0
const BLOCKED_TIME := 0.08
const STUCK_MOVE := 8.0
const STUCK_SECONDS := 2.5
const STUCK_JUMP_COOLDOWN := 0.45
const MAX_HEALTH := 2
const PLAYER_CHASE_RANGE := 100.0
const BASE_THROW_RANGE := 140.0
const HEIGHT_BONUS_PER_TILE := 24.0
const HEIGHT_TILE_PX := 16.0
const HEIGHT_BONUS_CAP := 80.0
const WINDUP_TIME := 0.9
const THROW_COOLDOWN := 1.1
const GLOB_SCENE := preload("res://Scenes/throw_glob.tscn")

var max_health := MAX_HEALTH
var health := MAX_HEALTH
var _blocked_for := 0.0
var _last_x := INF
var _no_move_for := 0.0
var _stuck_jump_cd := 0.0
var _throw_cd := 0.0
var _windup_left := 0.0
var _winding_up := false
var _windup_target: Node2D
var _sprite: Sprite2D
var _walk_phase := 0.0
var _release_flash := 0.0


func configure(hp: int) -> void:
	max_health = maxi(hp, 1)
	health = max_health


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("enemy_thrower")
	z_index = 2
	_sprite = get_node_or_null("Sprite2D") as Sprite2D
	if _sprite:
		_sprite.texture = PlaceholderThrower.create_texture()
		_sprite.centered = true
		_sprite.scale = Vector2(PlaceholderThrower.DISPLAY_SCALE, PlaceholderThrower.DISPLAY_SCALE)
		_sprite.position = PlaceholderThrower.SPRITE_OFFSET
		_sprite.hframes = PlaceholderThrower.FRAME_COUNT
		_sprite.vframes = 1
		_sprite.frame = 0
		_sprite.visible = true
	_apply_footprint_collision()

	_walk_phase = randf() * float(PlaceholderThrower.WALK_FRAMES)
	if _sprite:
		_sprite.frame = int(_walk_phase) % PlaceholderThrower.WALK_FRAMES


func _apply_footprint_collision() -> void:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return
	# Body-sized rect with feet at the CharacterBody2D origin (not the 64 cell).
	var rect := RectangleShape2D.new()
	rect.size = PlaceholderThrower.COLLISION_SIZE
	shape_node.shape = rect
	shape_node.position = PlaceholderThrower.COLLISION_OFFSET


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	_throw_cd = maxf(_throw_cd - delta, 0.0)
	_release_flash = maxf(_release_flash - delta, 0.0)

	if _winding_up:
		_process_windup(delta)
		velocity.x = 0.0
		move_and_slide()
		_reject_wall_ledges()
		_update_anim(delta, 0.0)
		_cull_if_fallen()
		return

	var dir := 0.0
	var target := _target()
	if target:
		var dx := target.global_position.x - global_position.x
		var dist := global_position.distance_to(target.global_position)
		var throw_range := _effective_throw_range(target)
		if dist <= throw_range:
			# In range: plant and start windup when cooled down.
			dir = 0.0
			if absf(dx) > 1.0 and _sprite:
				_sprite.flip_h = dx < 0.0
			if _throw_cd <= 0.0:
				_begin_windup(target)
		elif absf(dx) > 6.0:
			dir = signf(dx)

	velocity.x = dir * SPEED
	move_and_slide()
	_reject_wall_ledges()
	if not _winding_up:
		_hop_if_blocked(delta, dir)
		_hop_if_stuck(delta, dir)
	_update_anim(delta, dir)
	_cull_if_fallen()


func _cull_if_fallen() -> void:
	if global_position.y > 4000.0:
		queue_free()


func _begin_windup(target: Node2D) -> void:
	_winding_up = true
	_windup_left = WINDUP_TIME
	_windup_target = target
	velocity.x = 0.0


func _process_windup(delta: float) -> void:
	# Stay planted. Cancel only if the aim target leaves throw range (not on damage).
	if not _is_windup_target_valid():
		_cancel_windup()
		return
	var aim := _windup_target
	var dx := aim.global_position.x - global_position.x
	if _sprite and absf(dx) > 1.0:
		_sprite.flip_h = dx < 0.0
	if global_position.distance_to(aim.global_position) > _effective_throw_range(aim):
		_cancel_windup()
		return
	_windup_left -= delta
	if _windup_left <= 0.0:
		_release_throw(aim)


func _cancel_windup() -> void:
	_winding_up = false
	_windup_left = 0.0
	_windup_target = null


func _is_windup_target_valid() -> bool:
	return _windup_target != null and is_instance_valid(_windup_target)


func _release_throw(aim: Node2D) -> void:
	_winding_up = false
	_windup_left = 0.0
	_windup_target = null
	_throw_cd = THROW_COOLDOWN
	_release_flash = 0.12
	if _sprite:
		_sprite.frame = PlaceholderThrower.RELEASE_FRAME
	var host := get_parent()
	if host == null:
		return
	var glob := GLOB_SCENE.instantiate()
	host.add_child(glob)
	# Muzzle near upper torso of the copper body (feet-origin collision).
	var muzzle := global_position + Vector2(0.0, -PlaceholderThrower.COLLISION_SIZE.y + 2.0)
	glob.global_position = muzzle
	var aim_point := aim.global_position + Vector2(0.0, -12.0)
	if glob.has_method("setup"):
		glob.setup(_lob_velocity(muzzle, aim_point), self)


func _lob_velocity(from: Vector2, to: Vector2) -> Vector2:
	var gravity := float(ProjectSettings.get_setting("physics/2d/default_gravity"))
	var dx := to.x - from.x
	var dy := to.y - from.y
	# Lofted flight time so height bonuses can clear short walls.
	var time := clampf(absf(dx) / 110.0, 0.55, 1.4)
	var vx := dx / time
	var vy := (dy - 0.5 * gravity * time * time) / time
	return Vector2(vx, vy)


func _effective_throw_range(target: Node2D) -> float:
	## High ground: +24px per 16px the thrower is above the target, capped at +80.
	var height_above := target.global_position.y - global_position.y
	var bonus := 0.0
	if height_above > 0.0:
		bonus = minf(floorf(height_above / HEIGHT_TILE_PX) * HEIGHT_BONUS_PER_TILE, HEIGHT_BONUS_CAP)
	return BASE_THROW_RANGE + bonus


func _update_anim(delta: float, dir: float) -> void:
	if _sprite == null:
		return
	if _winding_up:
		_sprite.frame = PlaceholderThrower.WINDUP_FRAME
		return
	if _release_flash > 0.0:
		_sprite.frame = PlaceholderThrower.RELEASE_FRAME
		return
	if dir != 0.0:
		_sprite.flip_h = dir < 0.0
	var moving := absf(get_real_velocity().x) > 2.0 or dir != 0.0
	var fps := PlaceholderThrower.WALK_FPS if moving else PlaceholderThrower.WALK_FPS * 0.4
	_walk_phase += delta * fps
	_sprite.frame = int(_walk_phase) % PlaceholderThrower.WALK_FRAMES


func take_damage(amount: int) -> void:
	if health <= 0:
		return
	health = maxi(health - amount, 0)
	# Damage during windup does NOT cancel — they still finish the throw.
	if health <= 0:
		queue_free()


func _hop_if_blocked(delta: float, dir: float) -> void:
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
			if absf(col.get_normal().x) > 0.3 and signf(dir) == -signf(col.get_normal().x):
				return true
			if other is Node2D and signf((other as Node2D).global_position.x - global_position.x) == signf(dir):
				return true
	var space := get_world_2d().direct_space_state
	var probe := RectangleShape2D.new()
	var body_h := PlaceholderThrower.COLLISION_SIZE.y
	var body_w := PlaceholderThrower.COLLISION_SIZE.x
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


func _reject_wall_ledges() -> void:
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var other := col.get_collider()
		if not (other is Node and (other as Node).is_in_group("wall")):
			continue
		if col.get_normal().y < -0.5:
			velocity.y = maxf(velocity.y, 120.0)
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
