extends Node

signal water_changed(current: int, maximum: int)

const STARTING_WATER := 100

var water: int = STARTING_WATER
var water_max: int = 1000


func _ready() -> void:
	water_changed.emit(water, water_max)


func add_water(gallons: int) -> int:
	var before := water
	water = clampi(water + gallons, 0, water_max)
	if water != before:
		water_changed.emit(water, water_max)
	return water - before


func spend_water(gallons: int) -> bool:
	if gallons < 0 or water < gallons:
		return false
	water -= gallons
	water_changed.emit(water, water_max)
	return true


func set_water(gallons: int) -> void:
	var next := clampi(gallons, 0, water_max)
	if next == water:
		return
	water = next
	water_changed.emit(water, water_max)


func reset_run() -> void:
	set_water(STARTING_WATER)
