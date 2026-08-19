extends CharacterBody2D

## Stranded recruit: idles until Mike hires them, then auto-assigns turret → well.

enum State { STRANDED, HIRED_WALK, HIRED_STAFF, HIRED_WELL }

const SPEED := 70.0
const INTERACT_RANGE := 36.0
const ARRIVE_DIST := 10.0
const WATER_INTERVALS := [12.0, 8.0, 5.0]
const HP_PER_STRENGTH := 10
const LABEL_OFFSET := Vector2(0, -40)

signal hire_state_changed

var strength := 0
var water_interval := 8.0
var health := 10
var max_health := 10

var _state: State = State.STRANDED
var _water_timer := 0.0
var _assignment: Node2D = null
var _sprite: Sprite2D
var _prompt: Label


func _ready() -> void:
	add_to_group("hiree")
	z_index = 3
	collision_layer = 1
	collision_mask = 1
	_sprite = get_node_or_null("Sprite2D") as Sprite2D
	if _sprite:
		_sprite.texture = PlaceholderHiree.create_texture()
		_sprite.position = PlaceholderHiree.SPRITE_OFFSET
	_ensure_prompt()
	if strength < 1:
		roll_stats()
	_apply_visuals()
	_refresh_prompt()
	hire_state_changed.emit()


func roll_stats() -> void:
	strength = randi_range(1, 3)
	water_interval = float(WATER_INTERVALS[randi() % WATER_INTERVALS.size()])
	max_health = HP_PER_STRENGTH * strength
	health = max_health
	_apply_visuals()
	_refresh_prompt()


func is_hired() -> bool:
	return _state != State.STRANDED


func upkeep_interval() -> float:
	return water_interval if is_hired() else 0.0


func take_damage(amount: int) -> void:
	if amount <= 0 or health <= 0:
		return
	health = maxi(health - amount, 0)
	_flash_damage()
	if health <= 0:
		_die()


func _die() -> void:
	_release_assignment()
	_state = State.STRANDED
	hire_state_changed.emit()
	queue_free()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	match _state:
		State.STRANDED:
			velocity.x = 0.0
			_try_hire_interact()
		State.HIRED_WALK:
			_tick_upkeep(delta)
			_walk_toward_assignment(delta)
		State.HIRED_STAFF, State.HIRED_WELL:
			velocity.x = 0.0
			_tick_upkeep(delta)

	move_and_slide()
	_refresh_prompt()


func _try_hire_interact() -> void:
	if PauseMenu.is_open or BuildMenu.is_open or ShopMenu.is_open or BuildPlacer.is_placing:
		return
	var player := _nearby_player()
	if player == null:
		return
	if Input.is_action_just_pressed("interact"):
		_hire()


func _hire() -> void:
	if is_hired():
		return
	_state = State.HIRED_WALK
	_water_timer = 0.0
	_pick_assignment()
	hire_state_changed.emit()


func _quit_to_stranded() -> void:
	_release_assignment()
	_state = State.STRANDED
	_water_timer = 0.0
	velocity.x = 0.0
	hire_state_changed.emit()


func _tick_upkeep(delta: float) -> void:
	if water_interval <= 0.0:
		return
	_water_timer += delta
	while _water_timer >= water_interval:
		_water_timer -= water_interval
		if not GameResources.spend_water(1):
			_quit_to_stranded()
			return


func _pick_assignment() -> void:
	_release_assignment()
	var turret := _nearest_unstaffed_turret()
	if turret:
		_assignment = turret
		_state = State.HIRED_WALK
		return
	var well := _nearest_well()
	if well:
		_assignment = well
		_state = State.HIRED_WALK
		return
	_assignment = null
	_state = State.HIRED_WELL


func _walk_toward_assignment(_delta: float) -> void:
	if _assignment == null or not is_instance_valid(_assignment):
		_pick_assignment()
		return
	# Turret taken while walking — reassign.
	if _assignment.is_in_group("turret") and _assignment.has_method("is_staffed") and _assignment.is_staffed():
		if not (_assignment.has_method("is_staffed_by") and _assignment.is_staffed_by(self)):
			_pick_assignment()
			return

	var target_x := _assignment.global_position.x
	var dx := target_x - global_position.x
	if absf(dx) <= ARRIVE_DIST:
		velocity.x = 0.0
		_arrive()
		return
	velocity.x = signf(dx) * SPEED
	if _sprite:
		_sprite.flip_h = dx < 0.0


func _arrive() -> void:
	if _assignment == null or not is_instance_valid(_assignment):
		_pick_assignment()
		return
	if _assignment.is_in_group("turret"):
		if _assignment.has_method("staff") and _assignment.staff(self, strength):
			_state = State.HIRED_STAFF
			hire_state_changed.emit()
			return
		_pick_assignment()
		return
	# Well (or nowhere): idle nearby; wells still produce unmanned.
	_state = State.HIRED_WELL
	hire_state_changed.emit()


func _release_assignment() -> void:
	if _assignment != null and is_instance_valid(_assignment) and _assignment.has_method("unstaff"):
		_assignment.unstaff(self)
	_assignment = null


func _nearest_unstaffed_turret() -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("turret"):
		if not node is Node2D or not is_instance_valid(node):
			continue
		if node.has_method("is_staffed") and node.is_staffed():
			continue
		var dist := global_position.distance_squared_to((node as Node2D).global_position)
		if dist < best_dist:
			best_dist = dist
			best = node as Node2D
	return best


func _nearest_well() -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("well"):
		if not node is Node2D or not is_instance_valid(node):
			continue
		var dist := global_position.distance_squared_to((node as Node2D).global_position)
		if dist < best_dist:
			best_dist = dist
			best = node as Node2D
	return best


func _nearby_player() -> Node2D:
	var player := get_tree().get_first_node_in_group("player")
	if player is Node2D and global_position.distance_to((player as Node2D).global_position) <= INTERACT_RANGE:
		return player as Node2D
	return null


func _apply_visuals() -> void:
	if _sprite == null:
		return
	# Strength tint so two recruits at one ship don't read as clones.
	match strength:
		1:
			_sprite.modulate = Color(0.85, 0.9, 1.0)
		2:
			_sprite.modulate = Color(1.0, 0.95, 0.75)
		_:
			_sprite.modulate = Color(1.05, 0.78, 0.7)


func _ensure_prompt() -> void:
	_prompt = get_node_or_null("Prompt") as Label
	if _prompt:
		return
	_prompt = Label.new()
	_prompt.name = "Prompt"
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 8)
	_prompt.position = LABEL_OFFSET + Vector2(-48, -10)
	_prompt.size = Vector2(96, 20)
	_prompt.z_index = 10
	add_child(_prompt)


func _refresh_prompt() -> void:
	if _prompt == null:
		return
	if _state == State.STRANDED:
		var near := _nearby_player() != null
		_prompt.visible = near
		if near:
			_prompt.text = "E: Hire  Str %d · 1/%ds" % [strength, int(water_interval)]
		return
	_prompt.visible = false


func _flash_damage() -> void:
	if _sprite == null:
		return
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color(1.4, 0.55, 0.55), 0.06)
	tween.tween_callback(_apply_visuals)


func _exit_tree() -> void:
	_release_assignment()
