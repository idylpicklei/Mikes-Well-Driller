extends StaticBody2D

## Alien ship: spawns blobs at a steady sandbox rate until destroyed.

const ENEMY_SCENE := preload("res://Scenes/enemy.tscn")
const SPAWN_INTERVAL := 5.0
const MAX_ALIVE := 6
const MAX_HEALTH := 12

var health := MAX_HEALTH
var _timer := SPAWN_INTERVAL
var _alive: Array[Node] = []
var _dead := false


func _ready() -> void:
	add_to_group("enemy_spawner")
	add_to_group("alien_ship")
	z_index = 1
	collision_layer = 1
	collision_mask = 1
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.texture = PlaceholderSpawner.create_texture()
		sprite.position = PlaceholderSpawner.SPRITE_OFFSET
	_apply_footprint_collision()


func _apply_footprint_collision() -> void:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return
	var rect := RectangleShape2D.new()
	rect.size = Vector2(PlaceholderSpawner.SIZE)
	shape_node.shape = rect
	shape_node.position = PlaceholderSpawner.SPRITE_OFFSET


func take_damage(amount: int) -> void:
	if _dead or amount <= 0:
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
	if _timer >= SPAWN_INTERVAL and _alive.size() < MAX_ALIVE:
		_timer = 0.0
		_spawn()


func _spawn() -> void:
	var host := get_parent()
	if host == null:
		return
	var enemy := ENEMY_SCENE.instantiate()
	if enemy.has_method("configure"):
		enemy.configure(1)
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
