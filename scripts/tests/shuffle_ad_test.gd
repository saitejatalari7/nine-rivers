extends Node

## Out of shuffles: the offer pauses the clock, a watched video shuffles the
## board at once, and the Daily Puzzle never offers one.

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
	SaveManager.prog["rapids_runs_today"] = 0
	SaveManager.economy["rewarded_ads_today"] = 0
	await get_tree().create_timer(0.5).timeout
	var modal = main.get_node("Modal")
	modal.hide_modal()

	main._start_run_mode()
	await get_tree().create_timer(0.5).timeout
	GameManager.shuffles = 0
	main._on_shuffle_clicked()
	await get_tree().create_timer(0.4).timeout
	_check("tapping Shuffle with none left offers a video", modal._current_screen == "shuffle_offer" and modal.visible, modal._current_screen)
	_check("and the clock stops while it is offered", not GameManager.is_timer_active, "")

	var used: int = SaveManager.economy.get("rewarded_ads_today", 0)
	modal.shuffle_ad_requested.emit()
	await get_tree().create_timer(0.4).timeout
	_check("a watched video is spent on the shuffle", GameManager.shuffles == 0, "shuffles=%d" % GameManager.shuffles)
	_check("it counts against the daily video limit", int(SaveManager.economy.get("rewarded_ads_today", 0)) == used + 1, "")
	_check("and the clock runs again", GameManager.is_timer_active, "")

	GameManager.shuffles = 0
	main._on_shuffle_clicked()
	await get_tree().create_timer(0.3).timeout
	modal.handle_back_pressed()
	await get_tree().create_timer(0.3).timeout
	_check("Back on the offer resumes play", GameManager.is_timer_active and GameManager.shuffles == 0, "")

	main._start_daily_mode()
	await get_tree().create_timer(0.4).timeout
	GameManager.shuffles = 0
	_check("(the Daily really started)", GameManager.current_mode == GameManager.GameMode.DAILY, "")
	main._on_shuffle_clicked()
	await get_tree().create_timer(0.3).timeout
	_check("the Daily Puzzle never offers a video", not modal.visible and GameManager.is_timer_active, "modal=%s" % modal.visible)

	SaveManager.economy["rewarded_ads_today"] = MonetizationManager.MAX_DAILY_REWARDED_ADS
	main._start_run_mode()
	await get_tree().create_timer(0.4).timeout
	GameManager.shuffles = 0
	main._on_shuffle_clicked()
	await get_tree().create_timer(0.3).timeout
	_check("nor once the day's videos are used", not modal.visible and GameManager.is_timer_active, "modal=%s" % modal.visible)

	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _check(name: String, ok: bool, detail: String) -> void:
	print("  %s  %-48s %s" % ["PASS" if ok else "FAIL", name, detail])
	if not ok:
		_fails += 1
