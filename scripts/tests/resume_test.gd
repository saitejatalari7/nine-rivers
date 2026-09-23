extends Node

## A board interrupted by the app closing comes back as it was. The board state
## is the part nothing else can re-derive: the layout name replays the geometry,
## but which tiles were dealt where, and which are already gone, cannot be
## worked out from the stage number.
##
## Run: godot --path . --rendering-driver opengl3 res://scenes/resume_test.tscn

const RiverTile = preload("res://scripts/core/river_tile.gd")

var _fails: int = 0
var main: Node2D
var board
var modal


func _ready() -> void:
	await get_tree().process_frame
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = true
	await get_tree().create_timer(1.2).timeout
	board = main.get_node("Board")
	modal = main.get_node("Modal")

	await _t1_a_played_board_survives_a_close()
	await _t2_a_finished_board_is_not_offered()
	await _t3_resuming_rapids_does_not_buy_a_run()

	print("")
	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _t1_a_played_board_survives_a_close() -> void:
	print("--- #1  a board in progress is restored ---")
	SaveManager.clear_session()
	main._start_calm_mode(7)
	await get_tree().create_timer(0.8).timeout

	# Play two sets, so the restored board has to be mid-game rather than fresh.
	for i in range(2):
		var sets: Array = board.get_legal_sets()
		if sets.is_empty():
			break
		var grp: Array = sets[0]
		var typed: Array[RiverTile] = []
		for t in grp:
			typed.append(t)
		board._resolve_matched_set(typed)
		await get_tree().create_timer(0.45).timeout

	var before_tiles: int = board.get_active_tiles().size()
	var before_score: int = GameManager.score
	var before_layout: String = GameManager.current_layout_name
	var fingerprint: String = _fingerprint()

	main._capture_session()
	_check("closing the app writes the board", SaveManager.has_session(),
		"%d tiles stored" % SaveManager.session.get("tiles", []).size())

	await _cold_restart()
	_check("and the session is still on disk after a relaunch",
		SaveManager.has_session(), "has_session=%s" % SaveManager.has_session())

	var ok: bool = main._resume_session()
	await get_tree().create_timer(0.5).timeout
	_check("the session restores", ok, "restore_stage returned %s" % ok)
	_check("with the same tiles still standing",
		board.get_active_tiles().size() == before_tiles,
		"%d -> %d" % [before_tiles, board.get_active_tiles().size()])
	_check("in the same places",
		_fingerprint() == fingerprint, "board fingerprint")
	_check("with the score intact", GameManager.score == before_score,
		"%d -> %d" % [before_score, GameManager.score])
	_check("and the same stage", GameManager.current_layout_name == before_layout,
		"%s -> %s" % [before_layout, GameManager.current_layout_name])
	_check("and it is still playable",
		not board.get_legal_sets().is_empty(),
		"%d legal sets" % board.get_legal_sets().size())


func _t2_a_finished_board_is_not_offered() -> void:
	print("--- #2  a board that ended is not offered back ---")
	main._capture_session()
	_check("a live board is stored", SaveManager.has_session(), "")
	main._on_game_over("test")
	await get_tree().create_timer(0.3).timeout
	_check("losing drops the session", not SaveManager.has_session(),
		"has_session=%s" % SaveManager.has_session())
	modal.hide_modal()


## Rapids runs are capped at three a day. The cap is charged when a run starts;
## a resumed run is the same run, so it must not be charged again - otherwise
## closing the app is a free fourth run.
func _t3_resuming_rapids_does_not_buy_a_run() -> void:
	print("--- #3  a resumed Rapids run is the same run ---")
	SaveManager.prog["rapids_runs_today"] = 0
	SaveManager.prog["last_rapids_date"] = ""
	main._start_run_mode()
	await get_tree().create_timer(0.9).timeout
	var spent_after_start: int = SaveManager.RAPIDS_RUNS_PER_DAY - SaveManager.rapids_runs_left()
	_check("starting a run spends one", spent_after_start == 1,
		"%d of %d spent" % [spent_after_start, SaveManager.RAPIDS_RUNS_PER_DAY])

	main._capture_session()
	await _cold_restart()
	main._resume_session()
	await get_tree().create_timer(0.5).timeout

	var spent_after_resume: int = SaveManager.RAPIDS_RUNS_PER_DAY - SaveManager.rapids_runs_left()
	_check("resuming it spends nothing more", spent_after_resume == 1,
		"%d of %d spent" % [spent_after_resume, SaveManager.RAPIDS_RUNS_PER_DAY])
	_check("and the clock is running again", GameManager.is_timer_active,
		"is_timer_active=%s" % GameManager.is_timer_active)


## What being killed in the background looks like from inside one process: the
## board is torn down without going through the menu, which is the route that
## ends a session on purpose.
func _cold_restart() -> void:
	# Through the file, not just through memory: the session has to survive being
	# written, signed alongside the profile, read back and sanitized.
	SaveManager.save_game()
	SaveManager.session = {}
	SaveManager.load_game()
	board.clear_board()
	board.visible = false
	main.get_node("HUD").visible = false
	GameManager.is_timer_active = false
	await get_tree().create_timer(0.3).timeout

func _fingerprint() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for t in board.get_active_tiles():
		parts.append("%d,%d,%d,%s%d,%s" % [t.x, t.y, t.z, t.suit, t.rank, str(t.is_frozen)])
	parts.sort()
	return "|".join(parts)


func _check(what: String, ok: bool, detail: String) -> void:
	if not ok:
		_fails += 1
	print("  %s  %-48s %s" % ["PASS" if ok else "FAIL", what, detail])
