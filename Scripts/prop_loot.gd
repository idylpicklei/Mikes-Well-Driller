class_name PropLoot
extends RefCounted

## Stub loot table for world props (gas station, abandoned cars).
## Empty for now — hook so drops can land later. No currency invented.


static func roll(_prop_id: StringName) -> Array:
	return []


static func empty_message(_prop_id: StringName) -> String:
	return "Nothing here."
