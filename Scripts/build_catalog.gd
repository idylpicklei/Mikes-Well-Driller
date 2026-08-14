class_name BuildCatalog
extends RefCounted

## Categories and items for the build wheel. Append here to add more later.
static func default_categories() -> Array[Dictionary]:
	return [
		{
			"id": &"well",
			"label": "Well",
			"color": Color("6b8e9f"),
			"items": [
				{"id": &"well", "label": "Well"},
			],
		},
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
				{"id": &"main_hub", "label": "Main Hub"},
				{"id": &"platform", "label": "Platform"},
				{"id": &"light", "label": "Light"},
			],
		},
	]


static func placeable(item_id: StringName) -> Dictionary:
	match item_id:
		&"main_hub":
			return {
				"scene": preload("res://Scenes/main_hub.tscn"),
				"unique_group": "main_hub",
				"width": PlaceholderHub.WIDTH_TILES,
				"height": PlaceholderHub.HEIGHT_TILES,
				"sprite_offset": PlaceholderHub.SPRITE_OFFSET,
				"texture": PlaceholderHub.create_texture(),
			}
		&"well":
			return {
				"scene": preload("res://Scenes/well.tscn"),
				"unique_group": "well",
				"max_count": 5,
				"width": PlaceholderWell.WIDTH_TILES,
				"height": PlaceholderWell.HEIGHT_TILES,
				"sprite_offset": PlaceholderWell.SPRITE_OFFSET,
				"texture": PlaceholderWell.create_texture(),
			}
		_:
			return {}
