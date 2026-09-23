extends Node

## Shuffle must leave a board the player can finish, or refuse and say so.
##
## The old version permuted slot positions at random and returned true whatever
## came out. It could leave no legal move at all, and on a board down to two
## tiles in one column every permutation is still one tile above another - the
## geometry is unsolvable, not the arrangement. A player hit that at stage 2,
## pressed Shuffle, and lost a charge for nothing.

const BoardGenerator = preload("res://scripts/core/board_generator.gd")
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
	board.load_stage("turtle")
	await get_tree().process_frame

	# Shuffling a full board must always leave a move available.
	var worst_moves: int = 1 << 30
	for i in 25:
		var ok: bool = board.shuffle_remaining_tiles()
		await get_tree().process_frame
		if not ok:
			_check(false, "shuffling a full board succeeds", "refused on pass %d" % i)
			break
		worst_moves = mini(worst_moves, board.get_legal_sets().size())
	_check(worst_moves > 0, "every shuffle leaves at least one legal move",
		"fewest legal sets seen across 25 shuffles: %d" % worst_moves)

	# Strip the board down to one set and shuffle again: the small cases are
	# where the old version quietly did nothing.
	_keep_only_sets(board, 2)
	await get_tree().process_frame
	var small_ok: bool = board.shuffle_remaining_tiles()
	await get_tree().process_frame
	_check(not small_ok or board.get_legal_sets().size() > 0,
		"a near-empty board is either solvable or refused",
		"returned %s, %d legal sets" % [str(small_ok), board.get_legal_sets().size()])

	# The reported case: two identical tiles stacked in one column. No
	# arrangement of two stacked slots is playable, so shuffle must refuse
	# rather than consume a charge and change nothing.
	_force_stacked_pair(board)
	await get_tree().process_frame
	var before_x: int = board.get_active_tiles()[0].x
	var stacked_ok: bool = board.shuffle_remaining_tiles()
	await get_tree().process_frame
	_check(not stacked_ok, "two stacked tiles are refused, not silently shuffled",
		"returned %s" % str(stacked_ok))
	_check(board.get_active_tiles()[0].x == before_x,
		"and nothing moved", "x %d -> %d" % [before_x, board.get_active_tiles()[0].x])

	print("")
	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _keep_only_sets(board, set_count: int) -> void:
	var seen: Dictionary = {}
	for t in board.live_tiles:
		if t.is_removed:
			continue
		if not seen.has(t.set_id) and seen.size() >= set_count:
			t.is_removed = true
		else:
			seen[t.set_id] = true
	board.invalidate_legal_sets()
	board.update_all_tiles_status()


## Leaves exactly one set, seated in one column so the lower tile can never
## become free.
func _force_stacked_pair(board) -> void:
	_keep_only_sets(board, 1)
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
	print("  %s  %-50s %s" % ["PASS" if ok else "FAIL", what, detail])
