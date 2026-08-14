class_name WellEfficiency
extends RefCounted

const HEIGHT_BONUS := 0.05
const MIN_EFFICIENCY := 0.25


static func at_world(world_pos: Vector2) -> float:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return 1.0
	var terrain := tree.get_first_node_in_group("terrain")
	if terrain == null or not terrain.has_method("surface_cell_at"):
		return 1.0
	var grass: Vector2i = terrain.surface_cell_at(world_pos + Vector2(0, 4))
	if grass == Vector2i(-999999, -999999):
		return 1.0
	var baseline: int = int(terrain.get("base_surface_y"))
	var tiles_lower: int = grass.y - baseline
	return maxf(MIN_EFFICIENCY, 1.0 + HEIGHT_BONUS * float(tiles_lower))


static func boost_percent(efficiency: float) -> int:
	return roundi((efficiency - 1.0) * 100.0)
