class_name BuildCatalog
extends RefCounted

## Categories and items for the build wheel. Append here to add more later.
## Only list items that BuildCatalog.placeable() can actually spawn.
const _MainHub := preload("res://Scripts/main_hub.gd")
const _Well := preload("res://Scripts/well.gd")
const _Turret := preload("res://Scripts/turret.gd")


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


## Fat Mike one-liners. Stats come from item_stats() so costs/HP stay single-source.
static func item_blurb(item_id: StringName) -> String:
	match item_id:
		&"main_hub":
			return "Water tank the crabs chew on. One only — lose the tank and I start dying of thirst."
		&"well":
			return "Sinks a pump, fills the hub tank. Park a hire on it if you want it working harder."
		&"basic_drill":
			return "Bolt it next to a free well. Doubles that well's flow. One drill per well."
		&"wall":
			return "Hard block. Crabs don't hop these — they walk around or eat dirt."
		&"turret":
			return "Silent until a hire staffs it. Strength makes it spit faster and meaner."
		_:
			return ""


## Live numbers from placeable() + scene script constants. No second cost table.
static func item_stats(item_id: StringName) -> PackedStringArray:
	var def := placeable(item_id)
	if def.is_empty():
		return PackedStringArray()

	var lines: PackedStringArray = []
	var cost := int(def.get("cost_water", 0))
	if cost > 0:
		lines.append("%d gal" % cost)

	match item_id:
		&"main_hub":
			lines.append("one only")
			lines.append("%d tank HP" % int(_MainHub.MAX_HEALTH))
			lines.append(
				"poison: -%d HP / %.2fs"
				% [int(_MainHub.THIRST_DAMAGE), float(_MainHub.THIRST_INTERVAL)]
			)
		&"well":
			var max_count := int(def.get("max_count", 5))
			lines.append("max %d" % max_count)
			var base_gpm := _well_base_gpm()
			lines.append("%.1f gpm base" % base_gpm)
			lines.append("staffable")
		&"basic_drill":
			lines.append("×%.0f well GPM" % float(_Well.DRILL_MULTIPLIER))
			lines.append("1 per well")
		&"wall":
			lines.append("hard block")
		&"turret":
			lines.append("%.0fpx range" % float(_Turret.RANGE_PX))
			lines.append("%.2fs cooldown" % float(_Turret.FIRE_COOLDOWN))
			lines.append("staffed only")
	return lines


static func is_available(item_id: StringName, tree: SceneTree) -> bool:
	var def := placeable(item_id)
	if def.is_empty():
		return false
	if tree == null:
		return true
	var group := str(def.get("unique_group", ""))
	if group.is_empty():
		return true
	var max_count := int(def.get("max_count", 1))
	return tree.get_nodes_in_group(group).size() < max_count


static func _well_base_gpm() -> float:
	var produce_time := float(_Well.PRODUCE_TIME)
	if produce_time <= 0.0:
		return 0.0
	return 60.0 * float(_Well.PRODUCE_AMOUNT) / produce_time
