class_name BuildCatalog
extends RefCounted

## Categories and items for the build wheel. Append here to add more later.
static func default_categories() -> Array[Dictionary]:
	return [
		{
			"id": &"drill",
			"label": "Drill",
			"color": Color("d98a2b"),
			"items": [
				{"id": &"basic_drill", "label": "Basic Drill"},
				{"id": &"heavy_drill", "label": "Heavy Drill"},
			],
		},
		{
			"id": &"defence",
			"label": "Defence",
			"color": Color("3d6ea8"),
			"items": [
				{"id": &"wall", "label": "Wall"},
				{"id": &"turret", "label": "Turret"},
			],
		},
		{
			"id": &"utility",
			"label": "Utility",
			"color": Color("2f9e8f"),
			"items": [
				{"id": &"platform", "label": "Platform"},
				{"id": &"light", "label": "Light"},
			],
		},
	]
