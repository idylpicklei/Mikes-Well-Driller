extends Node

const SAVE_PATH := "user://input.cfg"
## Bump when default binds change so stale user:// configs cannot keep D/Right on Build.
const BINDINGS_VERSION := 3

const ACTION_DEFS: Array[Dictionary] = [
	{"action": &"move_left", "label": "Move Left", "remappable": true},
	{"action": &"move_right", "label": "Move Right", "remappable": true},
	{"action": &"jump", "label": "Jump", "remappable": true},
	{"action": &"shoot", "label": "Shoot", "remappable": true},
	{"action": &"interact", "label": "Interact", "remappable": true},
	{"action": &"build_menu", "label": "Build", "remappable": true},
	{"action": &"cycle_weapon", "label": "Cycle Gun", "remappable": true},
	{"action": &"throw_grenade", "label": "Throw Grenade", "remappable": true},
	{"action": &"pause", "label": "Pause", "remappable": false},
]

## Keys that must never open the build catalog (movement / jump).
const _MOVE_KEYS: Array[Key] = [KEY_A, KEY_D, KEY_W, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_SPACE]


func _ready() -> void:
	_ensure_actions_exist()
	load_bindings()
	_sanitize_build_menu_binding()


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
			return [_key(KEY_A), _key(KEY_LEFT)]
		&"move_right":
			return [_key(KEY_D), _key(KEY_RIGHT)]
		&"jump":
			return [_key(KEY_W), _key(KEY_SPACE), _key(KEY_UP)]
		&"shoot":
			return [_mouse(MOUSE_BUTTON_LEFT)]
		&"interact":
			return [_key(KEY_E)]
		&"build_menu":
			return [_key(KEY_B)]
		&"cycle_weapon":
			return [_key(KEY_Q)]
		&"throw_grenade":
			return [_key(KEY_G)]
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
	# Never let movement keys own Build — that was the D/Right → catalog bug.
	if action == &"build_menu" and _event_is_move_key(event):
		return
	apply_events(action, [event.duplicate()])
	# Drop the same key from the opposite side so Build and Move stay exclusive.
	if action == &"build_menu":
		_erase_event_from_actions(
			event,
			[&"move_left", &"move_right", &"jump", &"interact", &"cycle_weapon", &"throw_grenade"]
		)
	elif action in [&"move_left", &"move_right", &"jump", &"interact", &"cycle_weapon", &"throw_grenade"]:
		_erase_event_from_actions(event, [&"build_menu"])
	save_bindings()


func reset_defaults() -> void:
	for definition in ACTION_DEFS:
		var action: StringName = definition["action"]
		apply_events(action, get_default_events(action))
	save_bindings()


func save_bindings() -> void:
	var config := ConfigFile.new()
	config.set_value("meta", "version", BINDINGS_VERSION)
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

	var stored_version := int(config.get_value("meta", "version", 0))
	if stored_version < BINDINGS_VERSION:
		# Stale configs may have had D/Right on build_menu or missing arrows.
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


## True when this event should toggle the B-catalog (never movement keys).
func is_build_toggle_event(event: InputEvent) -> bool:
	if not event.is_pressed() or event.is_echo():
		return false
	if _event_is_move_key(event):
		return false
	if event.is_action("move_left") or event.is_action("move_right") or event.is_action("jump"):
		return false
	return event.is_action("build_menu")


func _sanitize_build_menu_binding() -> void:
	if not InputMap.has_action(&"build_menu"):
		apply_events(&"build_menu", get_default_events(&"build_menu"))
		return
	var cleaned: Array[InputEvent] = []
	for event in InputMap.action_get_events(&"build_menu"):
		if _event_is_move_key(event):
			continue
		if event is InputEventKey:
			cleaned.append(event)
		elif event is InputEventMouseButton:
			cleaned.append(event)
	if cleaned.is_empty():
		cleaned.assign(get_default_events(&"build_menu"))
	apply_events(&"build_menu", cleaned)
	# Ensure movement still has WASD + arrows even if an old save wiped them.
	if InputMap.action_get_events(&"move_right").is_empty():
		apply_events(&"move_right", get_default_events(&"move_right"))
	if InputMap.action_get_events(&"move_left").is_empty():
		apply_events(&"move_left", get_default_events(&"move_left"))
	save_bindings()


func _erase_event_from_actions(event: InputEvent, actions: Array[StringName]) -> void:
	for action in actions:
		if not InputMap.has_action(action):
			continue
		for existing in InputMap.action_get_events(action):
			if _events_same_bind(existing, event):
				InputMap.action_erase_event(action, existing)


func _events_same_bind(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		var ka := a as InputEventKey
		var kb := b as InputEventKey
		var ca := ka.physical_keycode if ka.physical_keycode != KEY_NONE else ka.keycode
		var cb := kb.physical_keycode if kb.physical_keycode != KEY_NONE else kb.keycode
		return ca != KEY_NONE and ca == cb
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return (a as InputEventMouseButton).button_index == (b as InputEventMouseButton).button_index
	return false


func _event_is_move_key(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key_event := event as InputEventKey
	var code := key_event.physical_keycode if key_event.physical_keycode != KEY_NONE else key_event.keycode
	return code in _MOVE_KEYS


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
