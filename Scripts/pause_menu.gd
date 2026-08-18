class_name PauseMenu
extends Control

enum View { MAIN, KEYBINDS }

static var is_open := false

@onready var _main_panel: VBoxContainer = %MainPanel
@onready var _keybinds_panel: VBoxContainer = %KeybindsPanel
@onready var _bind_rows: VBoxContainer = %BindRows
@onready var _remap_hint: Label = %RemapHint

var _view := View.MAIN
var _remapping_action: StringName = &""
var _bind_buttons: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	hide()
	_apply_night_colors()
	_build_bind_rows()
	_show_view(View.MAIN)


func _apply_night_colors() -> void:
	var text := Color(0.78, 0.8, 0.84)
	var muted := Color(0.58, 0.62, 0.68)
	for node in find_children("*", "Label", true, false):
		(node as Label).add_theme_color_override("font_color", text)
	_remap_hint.add_theme_color_override("font_color", muted)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		if _remapping_action != &"":
			_cancel_remap()
		elif is_open:
			_resume()
		else:
			_open_pause()
		get_viewport().set_input_as_handled()
		return

	if not is_open or _view != View.KEYBINDS or _remapping_action == &"":
		return
	if not event.is_pressed() or event.is_echo():
		return
	if not InputBindings.can_bind(event):
		return
	InputBindings.bind_action(_remapping_action, event)
	_cancel_remap()
	_refresh_bind_rows()
	get_viewport().set_input_as_handled()


func _open_pause() -> void:
	if _game_over_visible():
		return
	if BuildMenu.is_open:
		BuildMenu.close_menu()
	is_open = true
	_view = View.MAIN
	_cancel_remap()
	_show_view(View.MAIN)
	show()
	get_tree().paused = true


func _game_over_visible() -> bool:
	for node in get_tree().get_nodes_in_group("game_over"):
		if node is CanvasItem and (node as CanvasItem).visible:
			return true
	return false


func _resume() -> void:
	if _view == View.KEYBINDS:
		InputBindings.save_bindings()
	is_open = false
	_cancel_remap()
	hide()
	get_tree().paused = false


func _show_view(view: View) -> void:
	_view = view
	_main_panel.visible = view == View.MAIN
	_keybinds_panel.visible = view == View.KEYBINDS
	_remap_hint.visible = false
	if view == View.KEYBINDS:
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
		row.add_child(name_label)

		var bind_button := Button.new()
		bind_button.custom_minimum_size = Vector2(180, 28)
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


func _on_resume_pressed() -> void:
	_resume()


func _on_keybinds_pressed() -> void:
	_show_view(View.KEYBINDS)


func _on_reset_pressed() -> void:
	InputBindings.reset_defaults()
	_refresh_bind_rows()


func _on_back_pressed() -> void:
	InputBindings.save_bindings()
	_show_view(View.MAIN)


func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()
