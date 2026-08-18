extends Node2D

## Basic Drill: sits next to a well and doubles that well's GPM.

var _well: Node2D = null


func _ready() -> void:
	add_to_group("drill")
	z_index = 1
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.texture = PlaceholderDrill.create_texture()
		sprite.position = PlaceholderDrill.SPRITE_OFFSET


func attach_to_well(well: Node2D) -> bool:
	if well == null or not is_instance_valid(well):
		return false
	if not well.has_method("attach_drill"):
		return false
	if not well.attach_drill(self):
		return false
	_well = well
	return true


func attached_well() -> Node2D:
	return _well if is_instance_valid(_well) else null


func _exit_tree() -> void:
	if is_instance_valid(_well) and _well.has_method("detach_drill"):
		_well.detach_drill(self)
	_well = null
