extends Control

const FONT_PATH := "res://Assets/fonts/PixelOperator8-Bold.ttf"
const GAME_SCENE := "res://Scenes/game.tscn"
const VERSION_PATH := "res://version.txt"
## Artist drop-in: pixelated dusk ref for the start menu (not the playfield).
## Binary-replace Assets/sprites/start_bg.png — no code change needed.
const START_BG_PATH := "res://Assets/sprites/start_bg.png"

## Chrome on the dusk still: near-white type over solid dark plates (not pale gray on pink).
const COL_TITLE := Color(0.96, 0.94, 0.88, 1.0)
const COL_TEXT := Color(0.92, 0.90, 0.86, 1.0)
const COL_MUTED := Color(0.72, 0.70, 0.66, 1.0)
const COL_OUTLINE := Color(0.04, 0.03, 0.05, 1.0)
const COL_SCRIM := Color(0.05, 0.04, 0.07, 0.90)
const COL_SCRIM_EDGE := Color(0.22, 0.18, 0.20, 0.95)
const COL_BTN := Color(0.09, 0.08, 0.10, 1.0)
const COL_BTN_HOVER := Color(0.16, 0.14, 0.17, 1.0)
const COL_BTN_PRESSED := Color(0.05, 0.04, 0.06, 1.0)
const COL_BTN_DISABLED := Color(0.12, 0.11, 0.13, 1.0)
const COL_BTN_BORDER := Color(0.40, 0.36, 0.38, 1.0)
const FONT_TITLE := 16
const FONT_BUTTON := 16
const FONT_STAMP := 8
const FONT_ROW := 16

enum View { MAIN, SETTINGS }

@onready var _main_chrome: PanelContainer = %MainChrome
@onready var _settings_chrome: PanelContainer = %SettingsChrome
@onready var _main_panel: VBoxContainer = %MainPanel
@onready var _settings_panel: VBoxContainer = %SettingsPanel
@onready var _bind_rows: VBoxContainer = %BindRows
@onready var _remap_hint: Label = %RemapHint
@onready var _build_stamp: Label = %BuildStamp
@onready var _background: ColorRect = $Background

var _view := View.MAIN
var _remapping_action: StringName = &""
var _bind_buttons: Dictionary = {}
var _font: Font
var _bg_art: TextureRect
var _button_style_normal: StyleBoxFlat
var _button_style_hover: StyleBoxFlat
var _button_style_pressed: StyleBoxFlat
var _button_style_disabled: StyleBoxFlat


func _ready() -> void:
	_font = load(FONT_PATH)
	_build_button_styles()
	_apply_scrim_styles()
	_apply_fonts()
	_apply_button_chrome()
	_apply_start_background()
	_build_stamp.text = _read_build_stamp()
	_build_bind_rows()
	_show_view(View.MAIN)


## Still art only: one TextureRect from start_bg.png. No playfield camera, no parallax.
## Keep the flat navy ColorRect until start_bg.png lands; then full-bleed nearest art.
func _apply_start_background() -> void:
	if not ResourceLoader.exists(START_BG_PATH):
		return
	var tex := load(START_BG_PATH) as Texture2D
	if tex == null:
		return
	if _background:
		_background.visible = false
	_bg_art = TextureRect.new()
	_bg_art.name = "StartBgArt"
	_bg_art.texture = tex
	_bg_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bg_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_art)
	move_child(_bg_art, 0)


func _read_build_stamp() -> String:
	if not FileAccess.file_exists(VERSION_PATH):
		return "dev"
	var file := FileAccess.open(VERSION_PATH, FileAccess.READ)
	if file == null:
		return "dev"
	var text := file.get_as_text().strip_edges()
	if text.is_empty():
		return "dev"
	return text


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


func _build_button_styles() -> void:
	_button_style_normal = _make_button_style(COL_BTN)
	_button_style_hover = _make_button_style(COL_BTN_HOVER)
	_button_style_pressed = _make_button_style(COL_BTN_PRESSED)
	_button_style_disabled = _make_button_style(COL_BTN_DISABLED)


func _make_button_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = COL_BTN_BORDER
	style.set_border_width_all(1)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.set_corner_radius_all(0)
	return style


func _apply_scrim_styles() -> void:
	var scrim := StyleBoxFlat.new()
	scrim.bg_color = COL_SCRIM
	scrim.border_color = COL_SCRIM_EDGE
	scrim.set_border_width_all(1)
	scrim.content_margin_left = 28
	scrim.content_margin_right = 28
	scrim.content_margin_top = 22
	scrim.content_margin_bottom = 22
	scrim.set_corner_radius_all(0)
	_main_chrome.add_theme_stylebox_override("panel", scrim)
	_settings_chrome.add_theme_stylebox_override("panel", scrim.duplicate())


func _apply_title_label(label: Label, size: int, color: Color) -> void:
	if _font:
		label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 1)
	label.add_theme_color_override("font_outline_color", COL_OUTLINE)


func _apply_fonts() -> void:
	_apply_title_label($Center/MainChrome/MainPanel/Title as Label, FONT_TITLE, COL_TITLE)
	_apply_title_label($Center/SettingsChrome/SettingsPanel/SettingsTitle as Label, FONT_TITLE, COL_TITLE)
	_apply_title_label(_build_stamp, FONT_STAMP, COL_MUTED)
	_apply_title_label(_remap_hint, FONT_STAMP, COL_MUTED)


func _style_button(button: Button) -> void:
	if _font:
		button.add_theme_font_override("font", _font)
	button.add_theme_font_size_override("font_size", FONT_BUTTON)
	button.add_theme_color_override("font_color", COL_TEXT)
	button.add_theme_color_override("font_hover_color", COL_TITLE)
	button.add_theme_color_override("font_pressed_color", COL_TITLE)
	button.add_theme_color_override("font_disabled_color", COL_MUTED)
	button.add_theme_color_override("font_outline_color", COL_OUTLINE)
	button.add_theme_constant_override("outline_size", 1)
	button.add_theme_stylebox_override("normal", _button_style_normal)
	button.add_theme_stylebox_override("hover", _button_style_hover)
	button.add_theme_stylebox_override("pressed", _button_style_pressed)
	button.add_theme_stylebox_override("disabled", _button_style_disabled)
	button.add_theme_stylebox_override("focus", _button_style_hover)


func _apply_button_chrome() -> void:
	for node in find_children("*", "Button", true, false):
		_style_button(node as Button)


func _show_view(view: View) -> void:
	_view = view
	_main_chrome.visible = view == View.MAIN
	_settings_chrome.visible = view == View.SETTINGS
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
		name_label.custom_minimum_size = Vector2(150, 0)
		_apply_title_label(name_label, FONT_ROW, COL_TEXT)
		row.add_child(name_label)

		var bind_button := Button.new()
		bind_button.custom_minimum_size = Vector2(200, 36)
		_style_button(bind_button)
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
