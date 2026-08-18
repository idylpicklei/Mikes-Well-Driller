extends Node

## Global wave clock for a run. Spawners and HUD read current wave params from here.

signal wave_changed(wave: int)

const WAVE_DURATION := 50.0
const BASE_SPAWN_INTERVAL := 5.0
const MIN_SPAWN_INTERVAL := 1.8
const INTERVAL_STEP := 0.7
const BASE_MAX_ALIVE := 6
const MAX_ALIVE_STEP := 1
const TOUGH_ENEMY_WAVE := 3
const TOUGH_ENEMY_HEALTH := 2

var wave := 1
var _elapsed := 0.0
var _active := false


func _ready() -> void:
	set_process(false)


func start_run() -> void:
	wave = 1
	_elapsed = 0.0
	_active = true
	set_process(true)
	wave_changed.emit(wave)


func reset() -> void:
	_active = false
	set_process(false)
	wave = 1
	_elapsed = 0.0
	wave_changed.emit(wave)


func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	while _elapsed >= WAVE_DURATION:
		_elapsed -= WAVE_DURATION
		wave += 1
		wave_changed.emit(wave)


func spawn_interval() -> float:
	return maxf(MIN_SPAWN_INTERVAL, BASE_SPAWN_INTERVAL - float(wave - 1) * INTERVAL_STEP)


func max_alive() -> int:
	return BASE_MAX_ALIVE + (wave - 1) * MAX_ALIVE_STEP


func enemy_health() -> int:
	if wave >= TOUGH_ENEMY_WAVE:
		return TOUGH_ENEMY_HEALTH
	return 1
