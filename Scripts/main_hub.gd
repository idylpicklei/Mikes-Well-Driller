extends StaticBody2D

signal health_changed(current: int, maximum: int)
signal destroyed

const MAX_HEALTH := 100

var health := MAX_HEALTH


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
	health_changed.emit(health, MAX_HEALTH)


func take_damage(amount: int) -> void:
	if health <= 0:
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health, MAX_HEALTH)
	_flash_damage()
	if health <= 0:
		destroyed.emit()
		queue_free()


func _flash_damage() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(1.4, 0.55, 0.55), 0.06)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.12)
