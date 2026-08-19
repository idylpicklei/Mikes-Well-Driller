extends Node2D

## World-placed found store. Not in the B catalog. E opens the shop panel.

const INTERACT_RANGE := 40.0
const PROMPT_OFFSET := Vector2(0, -56)

var _sprite: Sprite2D
var _prompt: Label


func _ready() -> void:
	add_to_group("found_store")
	z_index = 2
	_sprite = get_node_or_null("Sprite2D") as Sprite2D
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite2D"
		add_child(_sprite)
	_sprite.texture = PlaceholderStore.create_texture()
	_sprite.centered = true
	_sprite.position = PlaceholderStore.SPRITE_OFFSET
	_sprite.visible = true
	_ensure_prompt()
	_apply_footprint_collision()
	set_process(true)


func _apply_footprint_collision() -> void:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return
	var rect := RectangleShape2D.new()
	rect.size = Vector2(PlaceholderStore.SIZE)
	shape_node.shape = rect
	shape_node.position = PlaceholderStore.SPRITE_OFFSET


func _ensure_prompt() -> void:
	_prompt = get_node_or_null("Prompt") as Label
	if _prompt:
		return
	_prompt = Label.new()
	_prompt.name = "Prompt"
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position = PROMPT_OFFSET + Vector2(-48, 0)
	_prompt.size = Vector2(96, 14)
	_prompt.add_theme_font_size_override("font_size", 8)
	_prompt.add_theme_color_override("font_color", Color(0.86, 0.78, 0.68, 1.0))
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt)


func _process(_delta: float) -> void:
	if PauseMenu.is_open or BuildMenu.is_open or BuildPlacer.is_placing:
		_prompt.visible = false
		return
	if ShopMenu.is_open:
		_prompt.visible = false
		return
	var player := _nearby_player()
	_prompt.visible = player != null
	if player == null:
		return
	_prompt.text = "E — Shop"
	if Input.is_action_just_pressed("interact"):
		ShopMenu.open_shop()


func _nearby_player() -> Node2D:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return null
	if global_position.distance_to(player.global_position) > INTERACT_RANGE:
		return null
	return player
