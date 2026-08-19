extends StaticBody2D

## Alien ship: spawns blobs at a steady sandbox rate until destroyed.

const ENEMY_SCENE := preload("res://Scenes/enemy.tscn")
const THROWER_SCENE := preload("res://Scenes/enemy_thrower.tscn")
## After the first crab pack, about one in three spawns is a ranged thrower.
const THROWER_MIX_CHANCE := 1.0 / 3.0
## Steady sandbox cadence after the opening grace window.
const SPAWN_INTERVAL := 8.0
## One minute to explore / place a hub before ships appear and dump the first pack.
const FIRST_SPAWN_DELAY := 60.0
const MAX_ALIVE := 4
const MAX_HEALTH := 12

var health := MAX_HEALTH
var _timer := 0.0
var _alive: Array[Node] = []
var _dead := false
var _spawned_once := false
var _ship_landed := false


func _ready() -> void:
	add_to_group("enemy_spawner")
	add_to_group("alien_ship")
	z_index = 1
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.texture = PlaceholderSpawner.create_texture()
		sprite.position = PlaceholderSpawner.SPRITE_OFFSET
	_apply_footprint_collision()
	# Sit dormant until the opening delay — no visible ships / aliens at t=0.
	_set_ship_active(false)


func _apply_footprint_collision() -> void:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return
	var rect := RectangleShape2D.new()
	rect.size = Vector2(PlaceholderSpawner.SIZE)
	shape_node.shape = rect
	shape_node.position = PlaceholderSpawner.SPRITE_OFFSET


func _set_ship_active(active: bool) -> void:
	_ship_landed = active
	visible = active
	collision_layer = 1 if active else 0
	collision_mask = 1 if active else 0
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node:
		shape_node.disabled = not active


func take_damage(amount: int) -> void:
	if _dead or not _ship_landed or amount <= 0:
		return
	health = maxi(health - amount, 0)
	_flash_damage()
	if health <= 0:
		_die()


func _die() -> void:
	_dead = true
	set_process(false)
	queue_free()


func _process(delta: float) -> void:
	if _dead:
		return
	_prune_dead()
	_timer += delta
	if not _ship_landed:
		if _timer >= FIRST_SPAWN_DELAY:
			_timer = 0.0
			_set_ship_active(true)
			# First pack stays crabs so 1:00 is still a rush.
			_spawn()
			_spawned_once = true
		return
	if _timer >= SPAWN_INTERVAL and _alive.size() < MAX_ALIVE:
		_timer = 0.0
		_spawn()
		_spawned_once = true


func _spawn() -> void:
	var host := get_parent()
	if host == null:
		return
	var use_thrower := _spawned_once and randf() < THROWER_MIX_CHANCE
	var enemy: Node = (THROWER_SCENE if use_thrower else ENEMY_SCENE).instantiate()
	if enemy.has_method("configure"):
		enemy.configure(2 if use_thrower else 1)
	host.add_child(enemy)
	var side := -1.0 if randf() < 0.5 else 1.0
	var offset_x := (PlaceholderSpawner.SIZE.x * 0.5) + (PlaceholderTileset.TILE_SIZE * 1.5)
	enemy.global_position = global_position + Vector2(side * offset_x, 0)
	_alive.append(enemy)


func _prune_dead() -> void:
	var living: Array[Node] = []
	for node in _alive:
		if is_instance_valid(node):
			living.append(node)
	_alive = living


func _flash_damage() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1.4, 0.55, 0.55), 0.06)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.12)
