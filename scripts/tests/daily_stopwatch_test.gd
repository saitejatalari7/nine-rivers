extends Node

## The Daily Puzzle is timed with a stopwatch, and leaving the app pauses it.

var main: Node
var _fails: int = 0


func _ready() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = true
	SaveManager.prog["daily_attempts_today"] = 0
	SaveManager.prog["last_daily_date"] = ""
	await get_tree().create_timer(0.5).timeout
	main.get_node("Modal").hide_modal()

	main._start_daily_mode()
	await get_tree().create_timer(0.4).timeout
	var hud = main.get_node("HUD")
	_check("the clock shows elapsed time", hud.lbl_clock.text == "0:00", hud.lbl_clock.text)
	_check("no countdown bar in the daily", not hud.time_bar.visible, str(hud.time_bar.visible))

	main._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	var e: float = GameManager.elapsed
	await get_tree().create_timer(0.4).timeout
	_check("leaving the app stops the stopwatch", is_equal_approx(e, GameManager.elapsed),
		"%.2f -> %.2f" % [e, GameManager.elapsed])
	_check("and opens the pause menu", main.get_node("Modal").visible, "")

	main._resume_game()
	await get_tree().create_timer(0.3).timeout
	_check("resume starts it again", GameManager.elapsed > e, "%.2f -> %.2f" % [e, GameManager.elapsed])

	main._start_run_mode()
	await get_tree().process_frame
	_check("Timed Mode keeps its bar", hud.time_bar.visible, "")

	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _check(name: String, ok: bool, detail: String) -> void:
	print("  %s  %-40s %s" % ["PASS" if ok else "FAIL", name, detail])
	if not ok:
		_fails += 1
