extends Node

const SAVE_PATH := "user://input.cfg"

const ACTION_DEFS: Array[Dictionary] = [
	{"action": &"move_left", "label": "Move Left", "remappable": true},
	{"action": &"move_right", "label": "Move Right", "remappable": true},
	{"action": &"jump", "label": "Jump", "remappable": true},
	{"action": &"shoot", "label": "Shoot", "remappable": true},
	{"action": &"build_menu", "label": "Build", "remappable": true},
	{"action": &"pause", "label": "Pause", "remappable": false},
]


func _ready() -> void:
	_ensure_actions_exist()
	load_bindings()


func get_action_defs() -> Array[Dictionary]:
	return ACTION_DEFS


func is_rebindable(action: StringName) -> bool:
	for definition in ACTION_DEFS:
		if definition["action"] == action:
			return bool(definition.get("remappable", true))
	return false


func get_default_events(action: StringName) -> Array[InputEvent]:
	match action:
		&"move_left":
			return [_key(KEY_A)]
		&"move_right":
			return [_key(KEY_D)]
		&"jump":
			return [_key(KEY_W), _key(KEY_SPACE)]
		&"shoot":
			return [_mouse(MOUSE_BUTTON_LEFT)]
		&"build_menu":
			return [_key(KEY_B)]
		&"pause":
			return [_key(KEY_ESCAPE)]
		_:
			return []


func apply_events(action: StringName, events: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for existing in InputMap.action_get_events(action):
		InputMap.action_erase_event(action, existing)
	for event in events:
		if event is InputEvent:
			InputMap.action_add_event(action, event)


func get_binding_label(action: StringName) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "Unbound"
	var labels: PackedStringArray = []
	for event in events:
		labels.append(event_label(event))
	return ", ".join(labels)


func event_label(event: InputEvent) -> String:
	return event.as_text()


func can_bind(event: InputEvent) -> bool:
	if event is InputEventKey:
		return (event as InputEventKey).physical_keycode != KEY_ESCAPE
	if event is InputEventMouseButton:
		var button_event := event as InputEventMouseButton
		return button_event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]
	return false


func bind_action(action: StringName, event: InputEvent) -> void:
	if not is_rebindable(action):
		return
	apply_events(action, [event.duplicate()])
	save_bindings()


func reset_defaults() -> void:
	for definition in ACTION_DEFS:
		var action: StringName = definition["action"]
		apply_events(action, get_default_events(action))
	save_bindings()


func save_bindings() -> void:
	var config := ConfigFile.new()
	for definition in ACTION_DEFS:
		var action: StringName = definition["action"]
		var events: Array = []
		for event in InputMap.action_get_events(action):
			var data := _event_to_dict(event)
			if not data.is_empty():
				events.append(data)
		config.set_value("bindings", str(action), events)
	config.save(SAVE_PATH)


func load_bindings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		reset_defaults()
		return

	for definition in ACTION_DEFS:
		var action: StringName = definition["action"]
		var key := str(action)
		if not config.has_section_key("bindings", key):
			apply_events(action, get_default_events(action))
			continue

		var stored: Variant = config.get_value("bindings", key, [])
		if stored is Array and not (stored as Array).is_empty():
			var events: Array[InputEvent] = []
			for entry in stored:
				var event := _dict_to_event(entry)
				if event:
					events.append(event)
			if events.is_empty():
				apply_events(action, get_default_events(action))
			else:
				apply_events(action, events)
		else:
			apply_events(action, get_default_events(action))


func _ensure_actions_exist() -> void:
	for definition in ACTION_DEFS:
		var action: StringName = definition["action"]
		if not InputMap.has_action(action):
			InputMap.add_action(action)


func _key(physical_keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = physical_keycode
	return event


func _mouse(button_index: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	return event


func _event_to_dict(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return {"type": "key", "physical_keycode": key_event.physical_keycode}
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		return {"type": "mouse", "button_index": mouse_event.button_index}
	return {}


func _dict_to_event(data: Variant) -> InputEvent:
	if not data is Dictionary:
		return null
	var entry := data as Dictionary
	match str(entry.get("type", "")):
		"key":
			return _key(int(entry.get("physical_keycode", KEY_NONE)) as Key)
		"mouse":
			return _mouse(int(entry.get("button_index", MOUSE_BUTTON_LEFT)) as MouseButton)
		_:
			return null
