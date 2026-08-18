extends Node2D

## Child drawer so procedural hills_mid sits at MID_Z (in front of clouds).
var hills: Node2D


func _draw() -> void:
	if hills and hills.has_method("draw_mid_procedural_into"):
		hills.draw_mid_procedural_into(self)
