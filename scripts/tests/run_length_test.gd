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
		# The deal's own clearing order (set ids follow peel_dynamic), which
		# always finishes - greedy first-set play can corner itself on the
		# harder shapes Timed Mode now deals.
		var by_set: Dictionary = {}
		for t in board.live_tiles:
			if not by_set.has(t.set_id):
				by_set[t.set_id] = []
			by_set[t.set_id].append(t)
		var ids: Array = by_set.keys()
		ids.sort()
		for sid in ids:
			var typed: Array[RiverTile] = []
			for t in by_set[sid]:
				if not t.is_removed:
					typed.append(t)
			if typed.is_empty():
				continue
			GameManager.time_left = GameManager.max_time
			board._resolve_matched_set(typed)
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
