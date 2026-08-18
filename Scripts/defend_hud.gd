extends Control

const START_MENU_SCENE := "res://Scenes/start_menu.tscn"
const FONT_PATH := "res://Assets/fonts/PixelOperator8-Bold.ttf"

@onready var _status: Label = %StatusLabel
@onready var _mike_health: Label = %MikeHealthLabel
@onready var _health: Label = %HealthLabel
@onready var _crew: Label = %CrewLabel
@onready var _water_bar: ProgressBar = %WaterBar
@onready var _water_label: Label = %WaterLabel
@onready var _gpm_label: Label = %GpmLabel
@onready var _game_over: ColorRect = %GameOver
@onready var _menu_button: Button = %MenuButton

var _hub: Node = null
var _font: Font


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = load(FONT_PATH)
	_game_over.add_to_group("game_over")
	_apply_hud_colors()
	_apply_game_over_fonts()
	_game_over.visible = false
	_set_idle_status()
	_refresh_water(GameResources.water, GameResources.water_max)
	if not GameResources.water_changed.is_connected(_refresh_water):
		GameResources.water_changed.connect(_refresh_water)
	_refresh_gpm()
	set_process(true)
	call_deferred("_connect_signals")


func _apply_hud_colors() -> void:
	var text := Color(0.72, 0.76, 0.8)
	var soft := Color(0.58, 0.62, 0.68)
	for node in find_children("*", "Label", true, false):
		var label := node as Label
		if _game_over.is_ancestor_of(label):
			continue
		label.add_theme_color_override("font_color", text)
	_status.add_theme_color_override("font_color", soft)


func _apply_game_over_fonts() -> void:
	if _font == null:
		return
	var text := Color(0.78, 0.8, 0.84)
	for node in _game_over.find_children("*", "Label", true, false):
		var label := node as Label
		label.add_theme_font_override("font", _font)
		label.add_theme_color_override("font_color", text)
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


func _process(_delta: float) -> void:
	_refresh_gpm()
	_refresh_crew()


func _refresh_gpm() -> void:
	var total := 0.0
	for well in get_tree().get_nodes_in_group("well"):
		if well.has_method("gallons_per_minute"):
			total += float(well.gallons_per_minute())
	_gpm_label.text = "%.1f gpm" % total


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
		_crew.text = "Hired: %d · upkeep %s" % [hired, ", ".join(parts)]


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


func _bind_hub(hub: Node) -> void:
	if _hub and _hub.has_signal("health_changed"):
		if _hub.health_changed.is_connected(_on_hub_health_changed):
			_hub.health_changed.disconnect(_on_hub_health_changed)
		if _hub.has_signal("tank_poisoned") and _hub.tank_poisoned.is_connected(_on_tank_poisoned):
			_hub.tank_poisoned.disconnect(_on_tank_poisoned)

	_hub = hub
	if "health" in _hub and "MAX_HEALTH" in _hub:
		_on_hub_health_changed(int(_hub.health), int(_hub.MAX_HEALTH))
	if _hub.has_signal("health_changed"):
		_hub.health_changed.connect(_on_hub_health_changed)
	if _hub.has_signal("tank_poisoned"):
		_hub.tank_poisoned.connect(_on_tank_poisoned)
	if "is_tank_poisoned" in _hub and bool(_hub.is_tank_poisoned):
		_on_tank_poisoned()


func _on_mike_health_changed(current: int, maximum: int) -> void:
	_mike_health.text = "Mike HP: %d / %d" % [current, maximum]


func _on_mike_died() -> void:
	_mike_health.text = "Mike down!"
	_status.text = "Fat Mike was killed."
	_set_game_over_subtitle("Fat Mike was killed.")
	_show_game_over()


func _on_hub_health_changed(current: int, maximum: int) -> void:
	var poisoned := _hub != null and "is_tank_poisoned" in _hub and bool(_hub.is_tank_poisoned)
	if poisoned or current <= 0:
		_health.text = "Tank: Poisoned · HP %d / %d" % [current, maximum]
	else:
		_health.text = "Tank: Clean · HP %d / %d" % [current, maximum]


func _on_tank_poisoned() -> void:
	# Hub stays standing — no instant Game Over. Mike thirst-ticks down to Fat Mike GO.
	if _hub and "health" in _hub and "MAX_HEALTH" in _hub:
		_on_hub_health_changed(int(_hub.health), int(_hub.MAX_HEALTH))
	else:
		_health.text = "Tank: Poisoned"
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
	_water_label.text = "%d / %d gal" % [current, maximum]
