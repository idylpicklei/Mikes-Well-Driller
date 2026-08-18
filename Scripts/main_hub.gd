extends StaticBody2D

signal health_changed(current: int, maximum: int)
signal tank_poisoned

const MAX_HEALTH := 100
## Poisoned tank: Mike loses this much HP each thirst tick (hires are unaffected).
const THIRST_DAMAGE := 2
## Interval between thirst ticks while the tank is poisoned (1.5–2s band).
const THIRST_INTERVAL := 1.75

var health := MAX_HEALTH
var is_tank_poisoned := false

var _thirst_cd := 0.0
var _tank_sprite: Sprite2D


func _ready() -> void:
	add_to_group("defend_target")
	add_to_group("main_hub")
	z_index = 1
	collision_layer = 1
	collision_mask = 1
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.texture = PlaceholderHub.create_texture()
		sprite.position = PlaceholderHub.SPRITE_OFFSET
		sprite.modulate = Color.WHITE
	_ensure_tank_overlay()
	_refresh_tank_overlay()
	health_changed.emit(health, MAX_HEALTH)


func _ensure_tank_overlay() -> void:
	_tank_sprite = get_node_or_null("TankSprite") as Sprite2D
	if _tank_sprite == null:
		_tank_sprite = Sprite2D.new()
		_tank_sprite.name = "TankSprite"
		add_child(_tank_sprite)
	_tank_sprite.centered = true
	_tank_sprite.position = PlaceholderTank.SPRITE_OFFSET
	_tank_sprite.z_index = 1


func _refresh_tank_overlay() -> void:
	if _tank_sprite == null:
		return
	if is_tank_poisoned:
		_tank_sprite.texture = PlaceholderTank.create_poisoned_texture()
	else:
		_tank_sprite.texture = PlaceholderTank.create_texture()


func take_damage(amount: int) -> void:
	if amount <= 0:
		return
	if is_tank_poisoned:
		# Hub stays up; further hits don't matter once the tank is already poisoned.
		_flash_damage()
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health, MAX_HEALTH)
	_flash_damage()
	if health <= 0:
		_poison_tank()


func _poison_tank() -> void:
	if is_tank_poisoned:
		return
	is_tank_poisoned = true
	_thirst_cd = THIRST_INTERVAL
	_apply_poisoned_look()
	tank_poisoned.emit()


func _physics_process(delta: float) -> void:
	if not is_tank_poisoned:
		return
	_thirst_cd -= delta
	if _thirst_cd > 0.0:
		return
	_thirst_cd = THIRST_INTERVAL
	_tick_thirst()


func _tick_thirst() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player):
		return
	if player.has_method("take_damage"):
		player.take_damage(THIRST_DAMAGE)


func _apply_poisoned_look() -> void:
	# Overlay swap only — hub body stays un-tinted and standing.
	_refresh_tank_overlay()


func _flash_damage() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1.4, 0.55, 0.55), 0.06)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.12)
