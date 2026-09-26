extends Node

## A finger drag that starts on a Settings row must scroll the list, must not
## fire the row, and must not crash. Three device crashes followed a drag.

var _fails: int = 0


func _ready() -> void:
	await get_tree().process_frame
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = true
	await get_tree().create_timer(1.0).timeout
	var m = main.get_node("Modal")
	m.show_settings_menu()
	await get_tree().create_timer(0.8).timeout
	var screen_before: String = m._current_screen
	var start := Vector2(540, 900)
	for round in 3:
		_touch(start, true)
		await get_tree().process_frame
		for i in 12:
			_drag(start + Vector2(0, -20 * (i + 1)), Vector2(0, -20))
			await get_tree().process_frame
		_touch(start + Vector2(0, -240), false)
		await get_tree().create_timer(0.3).timeout
		print("  round %d  scroll=%d screen=%s" % [round, m.scroll_view.scroll_vertical, m._current_screen])
	_check("the drag scrolled the list", m.scroll_view.scroll_vertical > 0, str(m.scroll_view.scroll_vertical))
	_check("and did not open a row", m._current_screen == screen_before, m._current_screen)
	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _touch(at: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.position = at
	e.pressed = down
	e.index = 0
	Input.parse_input_event(e)


func _drag(at: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.position = at
	e.relative = rel
	e.index = 0
	Input.parse_input_event(e)


func _check(what: String, ok: bool, detail: String) -> void:
	if not ok:
		_fails += 1
	print("  %s  %-36s %s" % ["PASS" if ok else "FAIL", what, detail])
