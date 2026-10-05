extends Node

## Both three-a-day modes must hold at three, including through the pause
## menu's Restart Board, and a try only counts once a match is made.

const RiverTile = preload("res://scripts/core/river_tile.gd")
var _fails: int = 0
var main
var board

func _ready() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = true
	SaveManager.prog["rapids_runs_today"] = 0
	SaveManager.prog["daily_attempts_today"] = 0
	SaveManager.prog["last_daily_date"] = ""
	await get_tree().create_timer(1.0).timeout
	main.get_node("Modal").hide_modal()
	board = main.get_node("Board")

	print("--- Daily Puzzle ---")
	main._start_daily_mode()
	await get_tree().create_timer(0.6).timeout
	_check("opening without matching costs nothing", SaveManager.daily_attempts_left() == 3, str(SaveManager.daily_attempts_left()))
	for i in 3:
		await _match_one()
		main._restart_current_stage()
		await get_tree().create_timer(0.6).timeout
	_check("three tries via Restart Board use all three", SaveManager.daily_attempts_left() == 0, str(SaveManager.daily_attempts_left()))
	_check("and the daily is then closed", SaveManager.daily_closed_today(), "")

	print("--- Timed Mode ---")
	main._start_run_mode()
	await get_tree().create_timer(0.6).timeout
	for i in 3:
		await _match_one()
		main._restart_current_stage()
		await get_tree().create_timer(0.6).timeout
	_check("Restart Board counts each run", SaveManager.rapids_runs_left() == 0, str(SaveManager.rapids_runs_left()))
	main._start_run_mode()
	await get_tree().create_timer(0.4).timeout
	_check("a fourth run is refused", main.get_node("Modal").visible, "")

	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _match_one() -> void:
	var sets: Array = board.get_legal_sets()
	if sets.is_empty():
		return
	var typed: Array[RiverTile] = []
	for t in sets[0]:
		typed.append(t)
	board._resolve_matched_set(typed)
	await get_tree().create_timer(0.3).timeout


func _check(what: String, ok: bool, detail: String) -> void:
	if not ok:
		_fails += 1
	print("  %s  %-48s %s" % ["PASS" if ok else "FAIL", what, detail])
