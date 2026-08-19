extends Node

signal water_changed(current: int, maximum: int)
signal arsenal_changed

const STARTING_WATER := 100
const GUN_GLOCK := &"glock"
const GUN_SAWN := &"sawn_off"
const GUN_COIL := &"coil_gun"
const GRENADE_MAX := 5

var water: int = STARTING_WATER
var water_max: int = 1000
var owned_guns: Array[StringName] = [GUN_GLOCK]
var equipped_gun: StringName = GUN_GLOCK
var grenades: int = 0


func _ready() -> void:
	water_changed.emit(water, water_max)
	arsenal_changed.emit()


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


func owns_gun(gun_id: StringName) -> bool:
	return gun_id in owned_guns


func own_gun(gun_id: StringName) -> void:
	if gun_id == &"" or owns_gun(gun_id):
		return
	owned_guns.append(gun_id)
	equipped_gun = gun_id
	arsenal_changed.emit()


func add_grenade(count: int = 1) -> int:
	var before := grenades
	grenades = clampi(grenades + count, 0, GRENADE_MAX)
	if grenades != before:
		arsenal_changed.emit()
	return grenades - before


func spend_grenade() -> bool:
	if grenades <= 0:
		return false
	grenades -= 1
	arsenal_changed.emit()
	return true


func cycle_gun() -> StringName:
	if owned_guns.is_empty():
		owned_guns = [GUN_GLOCK]
		equipped_gun = GUN_GLOCK
		arsenal_changed.emit()
		return equipped_gun
	var idx := owned_guns.find(equipped_gun)
	if idx < 0:
		idx = 0
	else:
		idx = (idx + 1) % owned_guns.size()
	equipped_gun = owned_guns[idx]
	arsenal_changed.emit()
	return equipped_gun


func reset_run() -> void:
	set_water(STARTING_WATER)
	owned_guns = [GUN_GLOCK]
	equipped_gun = GUN_GLOCK
	grenades = 0
	arsenal_changed.emit()
