extends Node

## Checks the two halves of the Frost rule against a real board.
##
## 1. A tile frozen where it lay, already free at the deal, stays frozen. If
##    auto-thaw fired on the first status pass the whole modifier would be over
##    before the player touched anything.
## 2. Clearing what blocked a frozen tile thaws it without a tap.

const StageModifiers = preload("res://scripts/core/stage_modifiers.gd")

var _fails: int = 0


func _ready() -> void:
	await get_tree().process_frame
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = true
	await get_tree().create_timer(1.2).timeout

	var board = main.get_node("Board")
	main.get_node("Modal").hide_modal()
	StageModifiers.active_modifier = StageModifiers.Modifier.FROST
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260921
	board.load_stage("turtle", rng)
	board.visible = true
	await get_tree().process_frame

	var frozen_at_deal: int = 0
	var frozen_and_free: int = 0
	for t in board.get_active_tiles():
		if t.is_frozen:
			frozen_at_deal += 1
			if board.is_tile_free(t, board.get_active_tiles()):
				frozen_and_free += 1
	_check(frozen_at_deal > 0, "board deals frozen tiles", "%d frozen" % frozen_at_deal)
	_check(frozen_and_free > 0, "some frozen tiles start free and must be tapped",
		"%d frozen-and-free" % frozen_and_free)

	# Find a frozen tile that is currently blocked, then clear whatever blocks
	# it by fiat and run the same refresh a match would.
	var target = null
	for t in board.get_active_tiles():
		if t.is_frozen and not board.is_tile_free(t, board.get_active_tiles()):
			target = t
			break
	if target == null:
		_check(false, "found a blocked frozen tile to unblock", "none on this board")
	else:
		var freed: int = 0
		for other in board.get_active_tiles():
			if other == target:
				continue
			if other.z > target.z and absi(other.x - target.x) <= 1 and absi(other.y - target.y) <= 1:
				other.is_removed = true
				freed += 1
			elif other.z == target.z and absi(other.x - target.x) == 2 and absi(other.y - target.y) <= 1:
				other.is_removed = true
				freed += 1
		board.invalidate_legal_sets()
		board.update_all_tiles_status()
		await get_tree().process_frame
		_check(board.is_tile_free(target, board.get_active_tiles()),
			"target became free after removing its blockers", "removed %d" % freed)
		_check(not target.is_frozen, "clearing the blockers auto-thawed the ice",
			"is_frozen=%s" % target.is_frozen)

	print("")
	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		_fails += 1
	print("  %s  %-52s %s" % ["PASS" if ok else "FAIL", what, detail])
