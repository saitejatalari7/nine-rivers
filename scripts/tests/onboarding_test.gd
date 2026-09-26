extends Node

## Onboarding must be completable by playing, must never trap a first-time
## player, and must leave their progress alone.
##
## It used to run on stage 1 itself, so the test had to reason about whatever
## the dealer happened to produce. It now runs on three boards of its own, and
## what matters is the seam: that a new player gets the lesson and not a level,
## that clearing each board advances it, and that stage 1 is waiting afterwards
## exactly as if it had never been touched.

const RiverTile = preload("res://scripts/core/river_tile.gd")

var _fails: int = 0
var main: Node2D
var board
var tut


func _ready() -> void:
	await get_tree().process_frame
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false

	# A profile that has never played.
	SaveManager.prog["tutorial_completed"] = false
	SaveManager.prog["level"] = 1
	SaveManager.prog["stars"] = {}
	SaveManager.clear_session()
	await get_tree().create_timer(1.2).timeout

	board = main.get_node("Board")
	tut = main.get_node("TutorialController")
	main.get_node("Modal").hide_modal()
	main._start_calm_mode(1)
	await get_tree().create_timer(0.9).timeout

	_check(tut.visible, "a new player is shown onboarding", "visible=%s" % tut.visible)
	_check(tut._beat == 0, "it opens on the first beat", "beat=%d" % tut._beat)
	_check(not main.get_node("HUD").visible,
		"the HUD is out of the way", "hud visible=%s" % main.get_node("HUD").visible)
	_check(board.get_active_tiles().size() == 4,
		"on a board of its own, not stage 1", "%d tiles" % board.get_active_tiles().size())

	# Each board is finished by clearing it. Nothing advances on a button.
	for expected in [1, 2, 3, 4]:
		await _clear_one_board(expected)
		_check(tut._beat == expected, "clearing board %d moves on" % expected,
			"beat=%d" % tut._beat)

	# The last beat is a card, not a board.
	_check(board.get_active_tiles().is_empty(),
		"the closing card has no board behind it",
		"%d tiles" % board.get_active_tiles().size())
	_check(SaveManager.prog.get("level", 1) == 1,
		"and the lesson never advanced the player", "level=%s" % SaveManager.prog.get("level"))
	_check(SaveManager.prog.get("stars", {}).is_empty(),
		"nor gave them stars for it", "stars=%s" % str(SaveManager.prog.get("stars")))

	tut._finish()
	await get_tree().create_timer(0.9).timeout
	_check(not tut.visible, "it can be finished", "visible=%s" % tut.visible)
	_check(bool(SaveManager.prog.get("tutorial_completed", false)),
		"and is not shown again", "flag=%s" % str(SaveManager.prog.get("tutorial_completed")))
	_check(main.get_node("HUD").visible, "the HUD comes back", "")
	_check(board.get_active_tiles().size() > 10,
		"and stage 1 is dealt for real", "%d tiles" % board.get_active_tiles().size())

	await _test_replay_keeps_progress(main)

	print("")
	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


## Plays the CURRENT lesson board out and stops the moment the beat changes.
## Looping on "are there tiles left" cleared the whole tutorial in one call:
## the next board is dealt the instant the previous one empties.
func _clear_one_board(target_beat: int) -> void:
	var guard: int = 0
	while tut._beat < target_beat and guard < 20:
		var sets: Array = board.get_legal_sets()
		if sets.is_empty():
			break
		var typed: Array[RiverTile] = []
		for t in sets[0]:
			typed.append(t)
		board._resolve_matched_set(typed)
		await get_tree().create_timer(0.35).timeout
		guard += 1
	await get_tree().create_timer(0.4).timeout


## Replaying the tutorial from Settings must not cost the player their place.
## It used to deal stage 1; then, once the lesson got boards of its own, the
## finish handler would have dropped a stage-10 player back to stage 1 as well.
func _test_replay_keeps_progress(m) -> void:
	SaveManager.prog["level"] = 10
	SaveManager.prog["tutorial_completed"] = true
	m._start_calm_mode(10)
	await get_tree().create_timer(0.7).timeout

	m._on_replay_tutorial()
	await get_tree().create_timer(0.7).timeout
	_check(m.get_node("TutorialController").visible,
		"replaying starts the lesson again", "")
	_check(board.get_active_tiles().size() == 4,
		"on the lesson's own first board", "%d tiles" % board.get_active_tiles().size())

	m.get_node("TutorialController")._finish()
	await get_tree().create_timer(0.9).timeout
	_check(GameManager.current_level == 10,
		"and leaves the player on their own stage, not stage 1",
		"stage %d" % GameManager.current_level)
	_check(board.get_active_tiles().size() > 10,
		"with a real board dealt", "%d tiles" % board.get_active_tiles().size())


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		_fails += 1
	print("  %s  %-50s %s" % ["PASS" if ok else "FAIL", what, detail])
