extends Node

## Where a match spends its time, and how long the frames right after it take.

const RiverTile = preload("res://scripts/core/river_tile.gd")
var main: Node
var board
var _last_us: int = 0
var _frame_us: Array[int] = []
var _recording: bool = false

func _process(_d: float) -> void:
	var now: int = Time.get_ticks_usec()
	if _recording and _last_us > 0:
		_frame_us.append(now - _last_us)
	_last_us = now

func _ready() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = true
	await get_tree().create_timer(4.0).timeout
	main.get_node("Modal").hide_modal()
	board = main.get_node("Board")
	Engine.max_fps = 0
	var BC = load("res://scripts/core/board_controller.gd")
	var TV = load("res://scripts/ui/tile_view.gd")
	var mode: String = OS.get_environment("PERF_MODE")
	BC.debug_no_dust = mode.contains("nodust")
	TV.debug_no_dissolve = mode.contains("nodissolve")
	main._start_calm_mode(61)
	await get_tree().create_timer(2.0).timeout
	print("mode=", mode)
	var rows: Array = []
	for i in 10:
		var sets: Array = board.get_legal_sets()
		if sets.is_empty():
			break
		var typed: Array[RiverTile] = []
		for t in sets[0]:
			typed.append(t)
		var flow_before: int = GameManager.flow_level
		var cache_before: int = AudioManager._guzheng_cache.size()
		_frame_us.clear()
		_recording = true
		var t0: int = Time.get_ticks_usec()
		board._resolve_matched_set(typed)
		var t1: int = Time.get_ticks_usec()
		await get_tree().create_timer(0.9).timeout
		_recording = false
		var worst: int = 0
		for f in _frame_us:
			worst = maxi(worst, f)
		rows.append("match %2d  resolve %6.1f ms   worst frame after %6.1f ms   frames %3d   new notes synthesised %d" % [
			i + 1, (t1 - t0) / 1000.0, worst / 1000.0, _frame_us.size(), AudioManager._guzheng_cache.size() - cache_before])
		await get_tree().create_timer(0.3).timeout
	for r in rows:
		print(r)
	for i in 5:
		_frame_us.clear()
		_recording = true
		board.update_all_tiles_status()
		await get_tree().create_timer(0.9).timeout
		_recording = false
		var w2: int = 0
		for f in _frame_us:
			w2 = maxi(w2, f)
		print("redraw-all only %d  worst frame %6.1f ms" % [i + 1, w2 / 1000.0])
	for i in 10:
		_frame_us.clear()
		_recording = true
		await get_tree().create_timer(0.9).timeout
		_recording = false
		var worst: int = 0
		var total: int = 0
		for f in _frame_us:
			worst = maxi(worst, f)
			total += f
		print("idle %2d  worst frame %6.1f ms   avg %5.1f ms   frames %3d" % [i + 1, worst / 1000.0, total / 1000.0 / maxf(1.0, _frame_us.size()), _frame_us.size()])
	# The parts on their own.
	var t: int = Time.get_ticks_usec()
	AudioManager._synthesize_guzheng_wav(523.25, 0.42)
	print("one 0.42 s guzheng note synthesised: %.1f ms" % ((Time.get_ticks_usec() - t) / 1000.0))
	t = Time.get_ticks_usec()
	AudioManager._synthesize_guzheng_wav(261.6, 2.5)
	print("one 2.5 s ambient note synthesised: %.1f ms" % ((Time.get_ticks_usec() - t) / 1000.0))
	t = Time.get_ticks_usec()
	board.update_all_tiles_status()
	print("update_all_tiles_status: %.1f ms" % ((Time.get_ticks_usec() - t) / 1000.0))
	t = Time.get_ticks_usec()
	board.invalidate_legal_sets()
	board.get_legal_sets()
	print("get_legal_sets: %.1f ms" % ((Time.get_ticks_usec() - t) / 1000.0))
	get_tree().quit(0)
