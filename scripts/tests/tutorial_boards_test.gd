extends Node

## Every onboarding board must be clearable, and must teach what its caption
## claims. A tutorial that dead-ends is worse than no tutorial: the player
## cannot fail their way out of it and has no idea what they did wrong.

const TutorialBoards = preload("res://scripts/ui/tutorial_boards.gd")
const RiverTile = preload("res://scripts/core/river_tile.gd")

var _fails: int = 0
var main: Node2D
var board


func _ready() -> void:
	await get_tree().process_frame
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = true
	await get_tree().create_timer(1.2).timeout
	main.get_node("Modal").hide_modal()
	board = main.get_node("Board")

	await _clears("A - match", TutorialBoards.A_MATCH)
	await _clears("B - blocked", TutorialBoards.B_BLOCKED)
	await _clears("W - wild", TutorialBoards.W_WILD)
	await _clears("C - layers", TutorialBoards.C_LAYERS)

	await _b_really_blocks()
	await _w_needs_the_wild()
	await _c_teaches_the_wild()

	print("")
	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


## Plays the board to the end, always taking the first legal set. If a board
## can only be cleared by playing well, a first-timer will strand it.
func _clears(name: String, layout: Array) -> void:
	board.restore_stage(layout.duplicate(true))
	await get_tree().process_frame
	var moves: int = 0
	while board.get_active_tiles().size() > 0 and moves < 40:
		var sets: Array = board.get_legal_sets()
		if sets.is_empty():
			break
		var typed: Array[RiverTile] = []
		for t in sets[0]:
			typed.append(t)
		board._resolve_matched_set(typed)
		await get_tree().create_timer(0.35).timeout
		moves += 1
	_check(board.get_active_tiles().size() == 0,
		"%s clears by always taking the first move" % name,
		"%d tiles left after %d moves" % [board.get_active_tiles().size(), moves])


## The middle of each row must refuse to lift, or board B teaches nothing.
func _b_really_blocks() -> void:
	board.restore_stage(TutorialBoards.B_BLOCKED.duplicate(true))
	await get_tree().process_frame
	var grid: Dictionary = board.get_spatial_grid(board.get_active_tiles())
	var blocked: int = 0
	for t in board.get_active_tiles():
		if t.x == 2 and not board.is_tile_free_grid(t, grid):
			blocked += 1
	_check(blocked == 2, "B has exactly two blocked tiles to learn on",
		"%d blocked" % blocked)


## Board W is only clearable by spending wilds on unlike tiles: no pair may
## exist without one, and the two wilds must never be free together.
func _w_needs_the_wild() -> void:
	board.restore_stage(TutorialBoards.W_WILD.duplicate(true))
	await get_tree().process_frame
	var plain: int = 0
	var both_wild: int = 0
	for s in board.get_legal_sets():
		var wilds: int = 0
		for t in s:
			if t.is_wild():
				wilds += 1
		if wilds == 0:
			plain += 1
		elif wilds == s.size():
			both_wild += 1
	_check(plain == 0, "W has no pair without a wild", "%d plain" % plain)
	_check(both_wild == 0, "and the wilds cannot pair with each other", "%d" % both_wild)


## The flower on top must be matchable with the character beside it, or the
## caption about wild tiles is a lie.
func _c_teaches_the_wild() -> void:
	board.restore_stage(TutorialBoards.C_LAYERS.duplicate(true))
	await get_tree().process_frame
	var found := false
	for s in board.get_legal_sets():
		if s.size() != 2:
			continue
		var a: RiverTile = s[0]
		var b: RiverTile = s[1]
		if (a.is_wild() and not b.is_wild()) or (b.is_wild() and not a.is_wild()):
			found = true
	_check(found, "C offers a wild paired with something unlike it", "")

	var grid: Dictionary = board.get_spatial_grid(board.get_active_tiles())
	var covered: int = 0
	for t in board.get_active_tiles():
		if t.z == 0 and not board.is_tile_free_grid(t, grid):
			covered += 1
	_check(covered >= 2, "and tiles underneath that have to be uncovered",
		"%d not free" % covered)


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		_fails += 1
	print("  %s  %-52s %s" % ["PASS" if ok else "FAIL", what, detail])
