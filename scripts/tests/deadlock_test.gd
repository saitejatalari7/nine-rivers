extends Node

## A board that cannot be played and cannot be rearranged offers the player the
## stage rather than leaving them stuck. A board that merely has no legal move
## right now does not - a shuffle fixes that, and if this appeared there too a
## player could skip any hard stage by spending their shuffles first.

const RiverTile = preload("res://scripts/core/river_tile.gd")

var _fails: int = 0


func _ready() -> void:
	await get_tree().process_frame
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = true
	await get_tree().create_timer(1.2).timeout
	main.get_node("Modal").hide_modal()

	var board = main.get_node("Board")
	var modal = main.get_node("Modal")

	# A full board is always rearrangeable, so no offer is made.
	board.load_stage("turtle")
	await get_tree().process_frame
	_check(board.can_reshuffle(), "a full board can be reshuffled",
		"can_reshuffle=%s" % board.can_reshuffle())

	# Two tiles sharing one column: the lower can never be uncovered, and no
	# permutation of two stacked slots changes that.
	_force_stacked_pair(board)
	await get_tree().process_frame
	_check(not board.can_reshuffle(), "a stacked pair cannot be reshuffled",
		"can_reshuffle=%s" % board.can_reshuffle())

	# That is the case the offer exists for.
	main._on_no_moves_left()
	await get_tree().create_timer(0.4).timeout
	_check(modal.visible and modal._current_screen == "deadlock",
		"a true dead end offers the stage",
		"screen=%s visible=%s" % [modal._current_screen, modal.visible])

	# Taking it records a clear worth one star, not three.
	var lvl: int = GameManager.current_level
	SaveManager.prog["stars"] = {}
	main._on_deadlock_accepted()
	await get_tree().create_timer(0.4).timeout
	var stars: int = int(SaveManager.prog.get("stars", {}).get(str(lvl), -1))
	_check(stars == 1, "taking a knotted stage is worth one star",
		"stars[%d]=%d" % [lvl, stars])

	# And a board that is merely stuck says so instead, with no offer.
	board.load_stage("turtle")
	await get_tree().process_frame
	modal.hide_modal()
	await get_tree().create_timer(0.3).timeout
	main._on_no_moves_left()
	await get_tree().create_timer(0.4).timeout
	# Visibility, not _current_screen: hide_modal() leaves the old screen name
	# behind, so checking the name reads whatever was shown last rather than
	# whether anything is being shown now.
	_check(not modal.visible,
		"a recoverable board is not offered away",
		"modal visible=%s (last screen %s)" % [modal.visible, modal._current_screen])

	print("")
	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


## Leaves one set, seated in a single column.
func _force_stacked_pair(board) -> void:
	var seen: Dictionary = {}
	for t in board.live_tiles:
		if t.is_removed:
			continue
		if not seen.has(t.set_id) and seen.size() >= 1:
			t.is_removed = true
		else:
			seen[t.set_id] = true
	var live: Array = board.get_active_tiles()
	for i in range(live.size()):
		live[i].x = 4
		live[i].y = 4
		live[i].z = i
	board.invalidate_legal_sets()
	board.update_all_tiles_status()


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		_fails += 1
	print("  %s  %-46s %s" % ["PASS" if ok else "FAIL", what, detail])
