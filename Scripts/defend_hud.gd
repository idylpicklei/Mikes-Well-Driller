extends Control

const START_MENU_SCENE := "res://Scenes/start_menu.tscn"
const FONT_BODY_PATH := "res://Assets/fonts/kenpixel_mini.ttf"
const FONT_TITLE_PATH := "res://Assets/fonts/kenpixel_mini_square.ttf"
## Kenney FontFile integer size class (nearest, no MSDF): body + titles at 16.
const FONT_SIZE_BODY := 16
const FONT_SIZE_TITLE := 16
## Roomier than the ultra-thin strip, still far below the old half-screen panel.
const HUD_STRIP_MAX_H := 72

const COL_TEXT := Color(0.86, 0.78, 0.68, 1.0)
const COL_MUTED := Color(0.62, 0.55, 0.48, 1.0)
const COL_TEAL := Color(0.55, 0.78, 0.76, 1.0)
const COL_RUST := Color(0.86, 0.55, 0.38, 1.0)
const COL_POISON := Color(0.55, 0.78, 0.42, 1.0)
const COL_BAR := Color(0.12, 0.09, 0.08, 0.94)
const COL_BAR_EDGE := Color(0.55, 0.32, 0.22, 0.95)

@onready var _status: Label = %StatusLabel
@onready var _mike_health: Label = %MikeHealthLabel
@onready var _mike_bar: ProgressBar = %MikeHealthBar
@onready var _health: Label = %HealthLabel
@onready var _tank_row: Control = %TankRow
@onready var _tank_bar: ProgressBar = %TankHealthBar
@onready var _crew: Label = %CrewLabel
@onready var _water_bar: TextureProgressBar = %WaterBar
@onready var _water_label: Label = %WaterLabel
@onready var _gpm_label: Label = %GpmLabel
@onready var _game_over: ColorRect = %GameOver
@onready var _menu_button: Button = %MenuButton
@onready var _hud_bar: Control = $HudBar

var _hub: Node = null
var _font_body: Font
var _font_title: Font
var _tank_fill_clean: StyleBoxFlat
var _tank_fill_poison: StyleBoxFlat


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font_body = load(FONT_BODY_PATH)
	_font_title = load(FONT_TITLE_PATH)
	_game_over.add_to_group("game_over")
	_cache_tank_styles()
	_passthrough_hud_clicks()
	_apply_hud_look()
	_apply_game_over_fonts()
	_game_over.visible = false
	_tank_row.visible = false
	_set_idle_status()
	_refresh_water(GameResources.water, GameResources.water_max)
	if not GameResources.water_changed.is_connected(_refresh_water):
		GameResources.water_changed.connect(_refresh_water)
	_refresh_gpm()
	set_process(true)
	call_deferred("_connect_signals")
	call_deferred("_fit_hud_bar")


func _cache_tank_styles() -> void:
	var existing := _tank_bar.get_theme_stylebox("fill")
	if existing is StyleBoxFlat:
		_tank_fill_clean = (existing as StyleBoxFlat).duplicate() as StyleBoxFlat
	else:
		_tank_fill_clean = StyleBoxFlat.new()
		_tank_fill_clean.bg_color = Color(0.32, 0.55, 0.5, 1)
	_tank_fill_poison = _tank_fill_clean.duplicate() as StyleBoxFlat
	_tank_fill_poison.bg_color = Color(0.42, 0.62, 0.28, 1)


## Full-rect HUD must not steal world clicks (ghost + place). Strip chrome is display-only.
func _passthrough_hud_clicks() -> void:
	if _hud_bar:
		_hud_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for node in find_children("*", "Control", true, false):
		var control := node as Control
		if control == null or control == _game_over or _game_over.is_ancestor_of(control):
			continue
		if control == _menu_button:
			continue
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _apply_hud_look() -> void:
	for node in find_children("*", "Label", true, false):
		var label := node as Label
		if _game_over.is_ancestor_of(label):
			continue
		var is_title := label.name.ends_with("Title")
		var font := _font_title if is_title else _font_body
		var size := FONT_SIZE_TITLE if is_title else FONT_SIZE_BODY
		if font:
			label.add_theme_font_override("font", font)
			label.add_theme_font_size_override("font_size", size)
		label.add_theme_color_override("font_color", COL_TEXT)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.add_theme_color_override("font_color", COL_MUTED)
	_gpm_label.add_theme_color_override("font_color", COL_TEAL)
	_water_label.add_theme_color_override("font_color", COL_TEAL)
	_mike_health.add_theme_color_override("font_color", COL_RUST)


func _apply_game_over_fonts() -> void:
	if _font_title:
		var title := _game_over.find_child("Title", true, false) as Label
		if title:
			title.add_theme_font_override("font", _font_title)
			title.add_theme_font_size_override("font_size", FONT_SIZE_TITLE)
			title.add_theme_color_override("font_color", COL_TEXT)
	if _font_body:
		var subtitle := _game_over.find_child("Subtitle", true, false) as Label
		if subtitle:
			subtitle.add_theme_font_override("font", _font_body)
			subtitle.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
			subtitle.add_theme_color_override("font_color", COL_TEXT)
	if _font_title:
		_menu_button.add_theme_font_override("font", _font_title)
		_menu_button.add_theme_font_size_override("font_size", FONT_SIZE_TITLE)


func _process(_delta: float) -> void:
	_refresh_gpm()
	_refresh_crew()
	# Keep B-catalog wheel clear while open.
	if _hud_bar:
		var show_bar := not BuildMenu.is_open and not _game_over.visible
		if _hud_bar.visible != show_bar:
			_hud_bar.visible = show_bar
			if show_bar:
				call_deferred("_fit_hud_bar")


## Full-width strip: size to content, hard-capped, no empty brown padding.
func _fit_hud_bar() -> void:
	if _hud_bar == null:
		return
	_hud_bar.reset_size()
	var h := ceili(_hud_bar.get_combined_minimum_size().y)
	h = clampi(h, 1, HUD_STRIP_MAX_H)
	_hud_bar.offset_top = -float(h)
	_hud_bar.offset_bottom = 0.0


func _connect_signals() -> void:
	var placer := get_tree().get_first_node_in_group("build_placer")
	if placer:
		if not placer.hub_placed.is_connected(_on_hub_placed):
			placer.hub_placed.connect(_on_hub_placed)
		if not placer.placement_cancelled.is_connected(_set_idle_status):
			placer.placement_cancelled.connect(_set_idle_status)

	var menu := get_tree().get_first_node_in_group("build_menu") as BuildMenu
	if menu and not menu.item_chosen.is_connected(_on_item_chosen):
		menu.item_chosen.connect(_on_item_chosen)

	_bind_player(get_tree().get_first_node_in_group("player"))
	_set_idle_status()


func _bind_player(player: Node) -> void:
	if player == null:
		return
	if "health" in player and "MAX_HEALTH" in player:
		_on_mike_health_changed(int(player.health), int(player.MAX_HEALTH))
	if player.has_signal("health_changed") and not player.health_changed.is_connected(_on_mike_health_changed):
		player.health_changed.connect(_on_mike_health_changed)
	if player.has_signal("died") and not player.died.is_connected(_on_mike_died):
		player.died.connect(_on_mike_died)


func _refresh_gpm() -> void:
	var total := 0.0
	for well in get_tree().get_nodes_in_group("well"):
		if well.has_method("gallons_per_minute"):
			total += float(well.gallons_per_minute())
	_gpm_label.text = "%.1fgpm" % total


func _refresh_crew() -> void:
	if _crew == null:
		return
	var hired := 0
	var parts: PackedStringArray = []
	for node in get_tree().get_nodes_in_group("hiree"):
		if not is_instance_valid(node):
			continue
		if node.has_method("is_hired") and node.is_hired():
			hired += 1
			var interval := 8
			if node.has_method("upkeep_interval"):
				interval = int(node.upkeep_interval())
			parts.append("1/%ds" % interval)
	if hired <= 0:
		_crew.text = "Hired: 0"
	else:
		_crew.text = "Hired: %d · %s" % [hired, ", ".join(parts)]


func _on_item_chosen(_category_id: StringName, item_id: StringName) -> void:
	if item_id == &"main_hub":
		var cost := int(BuildCatalog.placeable(&"main_hub").get("cost_water", 0))
		_status.text = "Place Main Hub (%d gal): click ground, right-click cancel" % cost
	elif item_id == &"well":
		var def := BuildCatalog.placeable(&"well")
		var max_count := int(def.get("max_count", 5))
		var cost := int(def.get("cost_water", 0))
		var count := get_tree().get_nodes_in_group("well").size()
		if count >= max_count:
			_status.text = "Well limit reached (%d)" % max_count
		else:
			_status.text = "Place Well (%d/%d, %d gal): click ground, right-click cancel" % [count, max_count, cost]
	elif item_id == &"basic_drill":
		var cost := int(BuildCatalog.placeable(&"basic_drill").get("cost_water", 0))
		_status.text = "Place Basic Drill (%d gal): next to a free well, right-click cancel" % cost
	elif item_id == &"wall":
		var cost := int(BuildCatalog.placeable(&"wall").get("cost_water", 0))
		_status.text = "Place Wall (%d gal): click ground, right-click cancel" % cost
	elif item_id == &"turret":
		var cost := int(BuildCatalog.placeable(&"turret").get("cost_water", 0))
		_status.text = "Place Turret (%d gal): click ground, right-click cancel" % cost


func _on_hub_placed(hub: Node2D) -> void:
	_bind_hub(hub)
	_status.text = "Defend the Main Hub!"
	_orient_turrets_away_from_hub(hub)


func _orient_turrets_away_from_hub(hub: Node2D) -> void:
	for node in get_tree().get_nodes_in_group("turret"):
		if node.has_method("set_idle_facing_from_hub"):
			node.set_idle_facing_from_hub(hub)


func _bind_hub(hub: Node) -> void:
	if _hub and _hub.has_signal("health_changed"):
		if _hub.health_changed.is_connected(_on_hub_health_changed):
			_hub.health_changed.disconnect(_on_hub_health_changed)
		if _hub.has_signal("tank_poisoned") and _hub.tank_poisoned.is_connected(_on_tank_poisoned):
			_hub.tank_poisoned.disconnect(_on_tank_poisoned)

	_hub = hub
	_tank_row.visible = true
	call_deferred("_fit_hud_bar")
	if "health" in _hub and "MAX_HEALTH" in _hub:
		_on_hub_health_changed(int(_hub.health), int(_hub.MAX_HEALTH))
	if _hub.has_signal("health_changed"):
		_hub.health_changed.connect(_on_hub_health_changed)
	if _hub.has_signal("tank_poisoned"):
		_hub.tank_poisoned.connect(_on_tank_poisoned)
	if "is_tank_poisoned" in _hub and bool(_hub.is_tank_poisoned):
		_on_tank_poisoned()


func _on_mike_health_changed(current: int, maximum: int) -> void:
	_mike_bar.max_value = maximum
	_mike_bar.value = current
	_mike_health.text = "%d/%d" % [current, maximum]


func _on_mike_died() -> void:
	_mike_health.text = "DOWN"
	_mike_bar.value = 0
	_status.text = "Fat Mike was killed."
	_set_game_over_subtitle("Fat Mike was killed.")
	_show_game_over()


func _on_hub_health_changed(current: int, maximum: int) -> void:
	var was_visible := _tank_row.visible
	_tank_row.visible = true
	if not was_visible:
		call_deferred("_fit_hud_bar")
	_tank_bar.max_value = maximum
	_tank_bar.value = current
	var poisoned := _hub != null and "is_tank_poisoned" in _hub and bool(_hub.is_tank_poisoned)
	if poisoned or current <= 0:
		_health.text = "Psn %d/%d" % [current, maximum]
		_health.add_theme_color_override("font_color", COL_POISON)
		if _tank_fill_poison:
			_tank_bar.add_theme_stylebox_override("fill", _tank_fill_poison)
	else:
		_health.text = "Ok %d/%d" % [current, maximum]
		_health.add_theme_color_override("font_color", COL_TEAL)
		if _tank_fill_clean:
			_tank_bar.add_theme_stylebox_override("fill", _tank_fill_clean)


func _on_tank_poisoned() -> void:
	if _hub and "health" in _hub and "MAX_HEALTH" in _hub:
		_on_hub_health_changed(int(_hub.health), int(_hub.MAX_HEALTH))
	else:
		_health.text = "Poisoned"
		_health.add_theme_color_override("font_color", COL_POISON)
	_status.text = "Tank poisoned — Mike is dying of thirst! (stored water is undrinkable)"


func _set_game_over_subtitle(text: String) -> void:
	var subtitle := _game_over.find_child("Subtitle", true, false) as Label
	if subtitle:
		subtitle.text = text


func _show_game_over() -> void:
	if BuildMenu.is_open:
		BuildMenu.close_menu()
	BuildMenu.is_open = false
	BuildPlacer.is_placing = false
	PauseMenu.is_open = false
	_game_over.visible = true
	get_tree().paused = true


func _on_game_over_menu_pressed() -> void:
	_game_over.visible = false
	BuildMenu.is_open = false
	BuildMenu.block_shoot = false
	BuildPlacer.is_placing = false
	PauseMenu.is_open = false
	get_tree().paused = false
	get_tree().change_scene_to_file(START_MENU_SCENE)


func _set_idle_status() -> void:
	if _hub:
		return
	_status.text = "Build a Main Hub from Utility (B)"


func _refresh_water(current: int, maximum: int) -> void:
	_water_bar.max_value = maximum
	_water_bar.value = current
	_water_label.text = "%d/%d" % [current, maximum]
