class_name BuildCatalog
extends RefCounted

## Categories and items for the build wheel. Append here to add more later.
## Only list items that BuildCatalog.placeable() can actually spawn.
static func default_categories() -> Array[Dictionary]:
	return [
		{
			"id": &"well",
			"label": "Well",
			"color": Color("4a6570"),
			"items": [
				{"id": &"well", "label": "Well"},
			],
		},
		{
			"id": &"drill",
			"label": "Drill",
			"color": Color("a06a28"),
			"items": [
				{"id": &"basic_drill", "label": "Basic Drill"},
			],
		},
		{
			"id": &"defence",
			"label": "Defence",
			"color": Color("2e5478"),
			"items": [
				{"id": &"wall", "label": "Wall"},
				{"id": &"turret", "label": "Turret"},
			],
		},
		{
			"id": &"utility",
			"label": "Utility",
			"color": Color("247068"),
			"items": [
				{"id": &"main_hub", "label": "Main Hub"},
			],
		},
	]


static func placeable(item_id: StringName) -> Dictionary:
	match item_id:
		&"main_hub":
			return {
				"scene": preload("res://Scenes/main_hub.tscn"),
				"unique_group": "main_hub",
				"cost_water": 25,
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
				"cost_water": 15,
				"width": PlaceholderWell.WIDTH_TILES,
				"height": PlaceholderWell.HEIGHT_TILES,
				"sprite_offset": PlaceholderWell.SPRITE_OFFSET,
				"texture": PlaceholderWell.create_texture(),
			}
		&"basic_drill":
			return {
				"scene": preload("res://Scenes/drill.tscn"),
				"cost_water": 20,
				"width": PlaceholderDrill.WIDTH_TILES,
				"height": PlaceholderDrill.HEIGHT_TILES,
				"sprite_offset": PlaceholderDrill.SPRITE_OFFSET,
				"texture": PlaceholderDrill.create_texture(),
			}
		&"wall":
			return {
				"scene": preload("res://Scenes/wall.tscn"),
				"cost_water": 10,
				"width": PlaceholderWall.WIDTH_TILES,
				"height": PlaceholderWall.HEIGHT_TILES,
				"sprite_offset": PlaceholderWall.SPRITE_OFFSET,
				"texture": PlaceholderWall.create_texture(),
			}
		&"turret":
			return {
				"scene": preload("res://Scenes/turret.tscn"),
				"cost_water": 15,
				"width": PlaceholderTurret.WIDTH_TILES,
				"height": PlaceholderTurret.HEIGHT_TILES,
				"sprite_offset": PlaceholderTurret.SPRITE_OFFSET,
				"texture": PlaceholderTurret.create_texture(),
			}
		_:
			return {}
