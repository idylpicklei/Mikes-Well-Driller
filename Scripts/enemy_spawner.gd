extends Node2D

const ENEMY_SCENE := preload("res://Scenes/enemy.tscn")
const SPAWN_INTERVAL := 5.0
const MAX_ALIVE := 6

var _timer := SPAWN_INTERVAL
var _alive: Array[Node] = []


func _ready() -> void:
	add_to_group("enemy_spawner")
	z_index = 1
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.texture = PlaceholderSpawner.create_texture()
		sprite.position = PlaceholderSpawner.SPRITE_OFFSET


func _process(delta: float) -> void:
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
