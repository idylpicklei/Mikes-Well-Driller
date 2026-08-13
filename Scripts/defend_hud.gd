extends Control

@onready var _status: Label = %StatusLabel
@onready var _health: Label = %HealthLabel
@onready var _water_bar: ProgressBar = %WaterBar
@onready var _water_label: Label = %WaterLabel
@onready var _gold_bar: ProgressBar = %GoldBar
@onready var _gold_label: Label = %GoldLabel

var _hub: Node = null


func _ready() -> void:
	_set_idle_status()
	_refresh_water(GameResources.water, GameResources.water_max)
	_refresh_gold(GameResources.gold)
	if not GameResources.water_changed.is_connected(_refresh_water):
		GameResources.water_changed.connect(_refresh_water)
	if not GameResources.gold_changed.is_connected(_refresh_gold):
		GameResources.gold_changed.connect(_refresh_gold)
	call_deferred("_connect_signals")


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


func _on_item_chosen(_category_id: StringName, item_id: StringName) -> void:
	if item_id == &"main_hub":
		_status.text = "Place Main Hub: click ground, right-click cancel"
	elif item_id == &"well":
		_status.text = "Place Well: click ground, right-click cancel"


func _on_hub_placed(hub: Node2D) -> void:
	_bind_hub(hub)
	_status.text = "Defend the Main Hub!"


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
