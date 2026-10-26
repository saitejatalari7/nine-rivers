extends Node

## Sits on a board for a minute and reports every frame over 50 ms, with the
## time since launch, so a one-off hitch can be matched to what caused it.

var _t0: int = 0
var _last: int = 0
var _spikes: Array[String] = []

func _process(_d: float) -> void:
	var now: int = Time.get_ticks_usec()
	if _last > 0 and now - _last > 50000:
		_spikes.append("  %6.2f s  frame %6.1f ms" % [(now - _t0) / 1e6, (now - _last) / 1000.0])
	_last = now

func _ready() -> void:
	_t0 = Time.get_ticks_usec()
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	SaveManager.prog["tutorial_completed"] = true
	SettingsManager.music_enabled = OS.get_environment("FREEZE_NO_MUSIC") == ""
	await get_tree().create_timer(float(OS.get_environment("FREEZE_MENU_S")) if OS.get_environment("FREEZE_MENU_S") != "" else 3.0).timeout
	print("  %6.2f s  start level" % ((Time.get_ticks_usec() - _t0) / 1e6))
	main.get_node("Modal").hide_modal()
	main._start_calm_mode(61)
	await get_tree().create_timer(float(OS.get_environment("FREEZE_SECONDS")) if OS.get_environment("FREEZE_SECONDS") != "" else 60.0).timeout
	print("drift sounds ready: %d kinds, %d sounds" % [AudioManager._drift_pool.size(), AudioManager._drift_pool.values().reduce(func(a, p): return a + p.size(), 0)])
	for s in _spikes:
		print(s)
	print("spikes: %d" % _spikes.size())
	get_tree().quit(0)
