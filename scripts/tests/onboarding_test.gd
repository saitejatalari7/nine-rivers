extends Node

## Onboarding must be completable by playing, and must never trap a first-time
## player. The previous version was three paragraphs behind a Next button, so
## there was nothing to test; this one advances on real moves.

var _fails: int = 0


func _ready() -> void:
	await get_tree().process_frame
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false

	# A profile that has never played.
	SaveManager.prog["tutorial_completed"] = false
	await get_tree().create_timer(1.2).timeout

	var board = main.get_node("Board")
	var tut = main.get_node("TutorialController")
	main.get_node("Modal").hide_modal()
	main._start_calm_mode(1)
	await get_tree().create_timer(0.8).timeout

	_check(tut.visible, "a new player is shown onboarding", "visible=%s" % tut.visible)
	_check(tut._beat == 0, "it opens on the first beat", "beat=%d" % tut._beat)

	# Beat 1: only the two pointed-at tiles answer a tap.
	var focus: Array = board.tutorial_focus
	_check(focus.size() >= 2, "it points at a real matching pair", "focus=%d tiles" % focus.size())

	var outsider = _tile_outside(board, focus)
	if outsider != null:
		var before: int = board.selected_tiles.size()
		board._on_tile_clicked(board.tile_views[outsider])
		await get_tree().process_frame
		_check(board.selected_tiles.size() == before,
			"a tile outside the lesson does not respond", "selection unchanged")

	# Matching the pair advances it, with no button pressed anywhere.
	for t in focus.duplicate():
		board._on_tile_clicked(board.tile_views[t])
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	_check(tut._beat >= 1, "matching the pair advances the lesson", "beat=%d" % tut._beat)

	# Whatever beat we are on, the lesson must be finishable and must not leave
	# the board locked behind it.
	tut._finish()
	# _finish fades the card out before hiding, so one frame is not enough.
	await get_tree().create_timer(0.4).timeout
	_check(not tut.visible, "it can be finished", "visible=%s" % tut.visible)
	_check(board.tutorial_focus.is_empty(),
		"finishing releases the board", "focus=%d" % board.tutorial_focus.size())
	_check(bool(SaveManager.prog.get("tutorial_completed", false)),
		"and it is not shown again", "flag=%s" % str(SaveManager.prog.get("tutorial_completed")))

	print("")
	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _tile_outside(board, focus: Array):
	for t in board.get_active_tiles():
		if not focus.has(t) and board.tile_views.has(t):
			return t
	return null


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		_fails += 1
	print("  %s  %-46s %s" % ["PASS" if ok else "FAIL", what, detail])
