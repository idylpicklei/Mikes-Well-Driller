extends Control

const START_MENU_SCENE := "res://Scenes/start_menu.tscn"
const FONT_PATH := "res://Assets/fonts/PixelOperator8-Bold.ttf"

@onready var _status: Label = %StatusLabel
@onready var _wave: Label = %WaveLabel
@onready var _health: Label = %HealthLabel
@onready var _water_bar: ProgressBar = %WaterBar
@onready var _water_label: Label = %WaterLabel
@onready var _gpm_label: Label = %GpmLabel
@onready var _gold_bar: ProgressBar = %GoldBar
@onready var _gold_label: Label = %GoldLabel
@onready var _game_over: ColorRect = %GameOver
@onready var _menu_button: Button = %MenuButton

var _hub: Node = null
var _font: Font


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = load(FONT_PATH)
	_game_over.add_to_group("game_over")
	_apply_game_over_fonts()
	_game_over.visible = false
	_set_idle_status()
	_on_wave_changed(WaveDirector.wave)
	_refresh_water(GameResources.water, GameResources.water_max)
	_refresh_gold(GameResources.gold)
	if not GameResources.water_changed.is_connected(_refresh_water):
		GameResources.water_changed.connect(_refresh_water)
	if not GameResources.gold_changed.is_connected(_refresh_gold):
		GameResources.gold_changed.connect(_refresh_gold)
	if not WaveDirector.wave_changed.is_connected(_on_wave_changed):
		WaveDirector.wave_changed.connect(_on_wave_changed)
	_refresh_gpm()
	set_process(true)
	call_deferred("_connect_signals")


func _apply_game_over_fonts() -> void:
	if _font == null:
		return
	for node in _game_over.find_children("*", "Label", true, false):
		(node as Label).add_theme_font_override("font", _font)
	_menu_button.add_theme_font_override("font", _font)


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


func _process(_delta: float) -> void:
	_refresh_gpm()


func _refresh_gpm() -> void:
	var total := 0.0
	for well in get_tree().get_nodes_in_group("well"):
		if well.has_method("gallons_per_minute"):
			total += float(well.gallons_per_minute())
	_gpm_label.text = "%.1f gpm" % total


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
		var cost := int(BuildCatalog.placeable(&"turret").get("cost_gold", 0))
		_status.text = "Place Turret (%d gold): click ground, right-click cancel" % cost


func _on_hub_placed(hub: Node2D) -> void:
	_bind_hub(hub)
	_status.text = "Defend the Main Hub!"


func _on_wave_changed(wave: int) -> void:
	_wave.text = "Wave %d" % wave


func _bind_hub(hub: Node) -> void:
	if _hub and _hub.has_signal("health_changed"):
		if _hub.health_changed.is_connected(_on_hub_health_changed):
			_hub.health_changed.disconnect(_on_hub_health_changed)
		if _hub.destroyed.is_connected(_on_hub_destroyed):
			_hub.destroyed.disconnect(_on_hub_destroyed)

	_hub = hub
	if "health" in _hub and "MAX_HEALTH" in _hub:
		_on_hub_health_changed(int(_hub.health), int(_hub.MAX_HEALTH))
	if _hub.has_signal("health_changed"):
		_hub.health_changed.connect(_on_hub_health_changed)
	if _hub.has_signal("destroyed"):
		_hub.destroyed.connect(_on_hub_destroyed)


func _on_hub_health_changed(current: int, maximum: int) -> void:
	_health.text = "Hub HP: %d / %d" % [current, maximum]


func _on_hub_destroyed() -> void:
	_hub = null
	_health.text = "Hub destroyed!"
	_status.text = "The Main Hub was lost."
	_show_game_over()


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
	WaveDirector.reset()
	get_tree().paused = false
	get_tree().change_scene_to_file(START_MENU_SCENE)


func _set_idle_status() -> void:
	if _hub:
		return
	_status.text = "Build a Main Hub from Utility (B)"


func _refresh_water(current: int, maximum: int) -> void:
	_water_bar.max_value = maximum
	_water_bar.value = current
	_water_label.text = "%d / %d gal" % [current, maximum]


func _refresh_gold(current: int) -> void:
	_gold_bar.max_value = 1.0
	_gold_bar.value = 1.0 if current > 0 else 0.0
	_gold_label.text = "%d gold" % current
