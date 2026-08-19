extends Area2D

## World-placed abandoned car. Walk-through Area2D — stand in/near, press E to search.
## Loot table is empty for now (PropLoot stub). Two art variants via set_variant().

const PROMPT_OFFSET := Vector2(0, -36)
const INTERACT_PAD := Vector2(12, 8)
const EMPTY_FLASH_SEC := 1.15
const PROP_ID := &"abandoned_car"

var variant: PlaceholderCar.Variant = PlaceholderCar.Variant.A
var _sprite: Sprite2D
var _prompt: Label
var _player_inside: bool = false
var _empty_until: float = 0.0
var _ready_done: bool = false


func _ready() -> void:
	add_to_group("abandoned_car")
	z_index = 2
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false
	_sprite = get_node_or_null("Sprite2D") as Sprite2D
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite2D"
		add_child(_sprite)
	_ensure_prompt()
	_apply_visual()
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	_ready_done = true
	set_process(true)


func set_variant(v: PlaceholderCar.Variant) -> void:
	variant = v
	if _ready_done:
		_apply_visual()


func _apply_visual() -> void:
	if _sprite == null:
		return
	_sprite.texture = PlaceholderCar.create_texture(variant)
	_sprite.centered = true
	_sprite.position = PlaceholderCar.sprite_offset_for(variant)
	_sprite.visible = true
	_apply_interact_shape()


func _apply_interact_shape() -> void:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return
	var rect := RectangleShape2D.new()
	rect.size = Vector2(PlaceholderCar.size_for(variant)) + INTERACT_PAD
	shape_node.shape = rect
	shape_node.position = PlaceholderCar.sprite_offset_for(variant)


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


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		_empty_until = 0.0


func _process(_delta: float) -> void:
	if PauseMenu.is_open or BuildMenu.is_open or BuildPlacer.is_placing or ShopMenu.is_open:
		_prompt.visible = false
		return
	_prompt.visible = _player_inside
	if not _player_inside:
		return
	var now := Time.get_ticks_msec() * 0.001
	if now < _empty_until:
		_prompt.text = PropLoot.empty_message(PROP_ID)
		return
	_prompt.text = "E — Search"
	if Input.is_action_just_pressed("interact"):
		var drops := PropLoot.roll(PROP_ID)
		if drops.is_empty():
			_empty_until = now + EMPTY_FLASH_SEC
			_prompt.text = PropLoot.empty_message(PROP_ID)
