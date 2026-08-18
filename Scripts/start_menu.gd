extends Control

const FONT_PATH := "res://Assets/fonts/PixelOperator8-Bold.ttf"
const GAME_SCENE := "res://Scenes/game.tscn"

enum View { MAIN, SETTINGS }

@onready var _main_panel: VBoxContainer = %MainPanel
@onready var _settings_panel: VBoxContainer = %SettingsPanel
@onready var _bind_rows: VBoxContainer = %BindRows
@onready var _remap_hint: Label = %RemapHint

var _view := View.MAIN
var _remapping_action: StringName = &""
var _bind_buttons: Dictionary = {}
var _font: Font


func _ready() -> void:
	_font = load(FONT_PATH)
	_apply_fonts()
	_build_bind_rows()
	_show_view(View.MAIN)


func _input(event: InputEvent) -> void:
	if _view != View.SETTINGS or _remapping_action == &"":
		return
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("pause"):
		_cancel_remap()
		get_viewport().set_input_as_handled()
		return
	if not InputBindings.can_bind(event):
		return
	InputBindings.bind_action(_remapping_action, event)
	_cancel_remap()
	_refresh_bind_rows()
	get_viewport().set_input_as_handled()


func _apply_fonts() -> void:
	if _font == null:
		return
	for node in find_children("*", "Label", true, false):
		(node as Label).add_theme_font_override("font", _font)
	for node in find_children("*", "Button", true, false):
		(node as Button).add_theme_font_override("font", _font)


func _show_view(view: View) -> void:
	_view = view
	_main_panel.visible = view == View.MAIN
	_settings_panel.visible = view == View.SETTINGS
	_remap_hint.visible = false
	if view == View.SETTINGS:
		_refresh_bind_rows()


func _build_bind_rows() -> void:
	for child in _bind_rows.get_children():
		child.queue_free()
	_bind_buttons.clear()

	for definition in InputBindings.get_action_defs():
		var action: StringName = definition["action"]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var name_label := Label.new()
		name_label.text = str(definition["label"])
		name_label.custom_minimum_size = Vector2(140, 0)
		if _font:
			name_label.add_theme_font_override("font", _font)
			name_label.add_theme_font_size_override("font_size", 8)
		row.add_child(name_label)

		var bind_button := Button.new()
		bind_button.custom_minimum_size = Vector2(180, 28)
		if _font:
			bind_button.add_theme_font_override("font", _font)
			bind_button.add_theme_font_size_override("font_size", 8)
		bind_button.pressed.connect(_on_bind_pressed.bind(action))
		row.add_child(bind_button)

		if not bool(definition.get("remappable", true)):
			bind_button.disabled = true

		_bind_rows.add_child(row)
		_bind_buttons[action] = bind_button

	_refresh_bind_rows()


func _refresh_bind_rows() -> void:
	for action in _bind_buttons:
		var button: Button = _bind_buttons[action]
		if action == _remapping_action:
			button.text = "Press a key..."
		else:
			button.text = InputBindings.get_binding_label(action)


func _on_bind_pressed(action: StringName) -> void:
	if not InputBindings.is_rebindable(action):
		return
	_remapping_action = action
	_remap_hint.visible = true
	_refresh_bind_rows()


func _cancel_remap() -> void:
	_remapping_action = &""
	_remap_hint.visible = false
	_refresh_bind_rows()


func _on_start_pressed() -> void:
	GameResources.reset_run()
	BuildMenu.is_open = false
	BuildMenu.block_shoot = false
	BuildPlacer.is_placing = false
	PauseMenu.is_open = false
	get_tree().paused = false
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_settings_pressed() -> void:
	_show_view(View.SETTINGS)


func _on_reset_pressed() -> void:
	InputBindings.reset_defaults()
	_refresh_bind_rows()


func _on_back_pressed() -> void:
	InputBindings.save_bindings()
	_cancel_remap()
	_show_view(View.MAIN)
