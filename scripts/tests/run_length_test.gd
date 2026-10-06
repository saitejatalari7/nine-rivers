extends Node

## A Timed Mode game is three stages: clearing the third shows the win screen
## instead of dealing a fourth.

const RiverTile = preload("res://scripts/core/river_tile.gd")
var _fails: int = 0

func _ready() -> void:
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = true
	SaveManager.prog["rapids_runs_today"] = 0
	await get_tree().create_timer(1.0).timeout
	main.get_node("Modal").hide_modal()
	var board = main.get_node("Board")
	var modal = main.get_node("Modal")
	main._start_run_mode()
	await get_tree().create_timer(0.6).timeout
	for stage in 3:
		var guard := 0
		while board.get_active_tiles().size() > 0 and guard < 200:
			var sets: Array = board.get_legal_sets()
			if sets.is_empty():
				board.shuffle_remaining_tiles()
				guard += 1
				continue
			var typed: Array[RiverTile] = []
			for t in sets[0]:
				typed.append(t)
			GameManager.time_left = GameManager.max_time
			board._resolve_matched_set(typed)
			guard += 1
		await get_tree().create_timer(1.6).timeout
		print("  after stage %d: stage_no=%d screen=%s" % [stage + 1, GameManager.current_stage_no, modal._current_screen])
	_check("the third clear wins the game", modal.visible and modal._current_screen == "run_won", modal._current_screen)
	_check("and no fourth stage is dealt", GameManager.current_stage_no == 3, str(GameManager.current_stage_no))
	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

func _check(what: String, ok: bool, detail: String) -> void:
	if not ok:
		_fails += 1
	print("  %s  %-40s %s" % ["PASS" if ok else "FAIL", what, detail])
