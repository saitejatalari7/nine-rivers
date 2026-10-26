extends Node

## The in-app update flow with Play faked out: when Play's sheet is asked for,
## that a "No thanks" holds for a day, and that a finished download is offered
## on the main menu once - never over a board.

class FakePlay extends RefCounted:
	var checks: int = 0
	var starts: int = 0
	var completes: int = 0
	func checkForUpdate() -> void: checks += 1
	func startUpdate() -> void: starts += 1
	func completeUpdate() -> void: completes += 1

var _fails: int = 0


func _ready() -> void:
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = true
	await get_tree().create_timer(1.0).timeout
	var modal = main.get_node("Modal")
	var um = UpdateManager

	_check("off Android there is no plugin", um._plugin == null, "")
	um.check()
	_check("and checking is harmless", true, "")

	var play := FakePlay.new()
	um._plugin = play
	SaveManager.prog.erase("update_asked_code")
	SaveManager.prog.erase("update_asked_at")
	var now: int = int(Time.get_unix_time_from_system())
	_check("a new version is asked about", um.should_ask(16, now), "")
	um._on_update_available(16)
	_check("which opens Play's sheet", play.starts == 1, str(play.starts))
	um._on_update_available(16)
	_check("not twice in a day for the same version", play.starts == 1, str(play.starts))
	_check("but again the next day", um.should_ask(16, now + 86400), "")
	_check("and at once for a newer version", um.should_ask(17, now), "")
	var kept: Dictionary = SaveManager._sanitize_prog(SaveManager.prog)
	_check("the asked version survives a save", int(kept.get("update_asked_code", 0)) == 16,
		str(kept.get("update_asked_code", 0)))

	main._start_calm_mode(12)
	await get_tree().create_timer(0.5).timeout
	um._on_update_downloaded()
	await get_tree().process_frame
	_check("a download mid-stage does not cover the board", modal._current_screen != "update_ready",
		modal._current_screen)
	um.check()
	_check("no more checks once it is downloaded", play.checks == 0, str(play.checks))

	modal.show_main_menu()
	_check("the menu offers the restart", modal._current_screen == "update_ready", modal._current_screen)
	modal.handle_back_pressed()
	_check("back means later", modal._current_screen == "main", modal._current_screen)
	modal.show_main_menu()
	_check("and it is not offered again this session", modal._current_screen == "main", modal._current_screen)

	um.restart_offered = false
	modal.show_main_menu()
	um.restart_into_update()
	_check("Restart Now installs it", play.completes == 1, str(play.completes))

	um._plugin = null
	um.ready_to_install = false
	um.restart_offered = false
	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _check(what: String, ok: bool, detail: String) -> void:
	if not ok:
		_fails += 1
	print("  %s  %-48s %s" % ["PASS" if ok else "FAIL", what, detail])
