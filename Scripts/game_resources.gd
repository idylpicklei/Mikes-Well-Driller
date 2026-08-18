extends Node

signal water_changed(current: int, maximum: int)
signal gold_changed(current: int)

const STARTING_WATER := 100

var water: int = STARTING_WATER
var water_max: int = 1000
var gold: int = 0


func _ready() -> void:
	water_changed.emit(water, water_max)
	gold_changed.emit(gold)


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


func add_gold(amount: int) -> int:
	var before := gold
	gold = maxi(gold + amount, 0)
	if gold != before:
		gold_changed.emit(gold)
	return gold - before


func spend_gold(amount: int) -> bool:
	if amount < 0 or gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


func set_gold(amount: int) -> void:
	var next := maxi(amount, 0)
	if next == gold:
		return
	gold = next
	gold_changed.emit(gold)


func reset_run() -> void:
	set_water(STARTING_WATER)
	set_gold(0)
