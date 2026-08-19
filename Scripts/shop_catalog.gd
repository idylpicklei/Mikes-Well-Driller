class_name ShopCatalog
extends RefCounted

## Water-only stock for the found store. Costs go through GameResources.spend_water.

const ITEM_SAWN := &"sawn_off"
const ITEM_COIL := &"coil_gun"
const ITEM_GRENADE := &"energy_grenade"

const COST_SAWN := 40
const COST_COIL := 65
const COST_GRENADE := 10
const GRENADE_MAX := 5


static func stock() -> Array[Dictionary]:
	return [
		{
			"id": ITEM_SAWN,
			"label": "Sawn-off",
			"cost": COST_SAWN,
			"kind": &"gun",
			"blurb": "3 pellets, short range, slower than the Glock.",
		},
		{
			"id": ITEM_COIL,
			"label": "Coil gun",
			"cost": COST_COIL,
			"kind": &"gun",
			"blurb": "Fat energy bolt. Slower fire, longer range, harder hit.",
		},
		{
			"id": ITEM_GRENADE,
			"label": "Energy grenade",
			"cost": COST_GRENADE,
			"kind": &"grenade",
			"blurb": "Arc lob with splash. Hurts enemies, ships — and Mike.",
		},
	]


static func item(item_id: StringName) -> Dictionary:
	for entry in stock():
		if entry.get("id", &"") == item_id:
			return entry
	return {}
