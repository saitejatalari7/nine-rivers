extends Node

## No board may deal two tiles of the same type directly on top of one another.
##
## Two slots in one column are never free at the same time, so a same-type pair
## seated that way cannot be matched once the other copies are gone. A player
## reported exactly that at stage 2: two tiles left, one above the other,
## Shuffle did nothing. Tiles never move during play, so the only way a board
## ends that way is if it was dealt that way.

const BoardGenerator = preload("res://scripts/core/board_generator.gd")
const StagePlan = preload("res://scripts/core/stage_plan.gd")
const RiverTile = preload("res://scripts/core/river_tile.gd")

var _fails: int = 0


func _ready() -> void:
	var traps: int = 0
	var checked: int = 0
	var worst: String = ""
	for level in range(1, StagePlan.TOTAL_LEVELS + 1):
		var rng := RandomNumberGenerator.new()
		rng.seed = StagePlan.seed_for_level(level)
		var tiles: Array[RiverTile] = BoardGenerator.deal_board(StagePlan.layout_for_level(level), rng)
		var n: int = _count(tiles)
		checked += 1
		if n > 0:
			traps += n
			if worst.is_empty():
				worst = "stage %d (%s)" % [level, StagePlan.layout_for_level(level)]
	_check(traps == 0, "no stage deals a same-type pair in one column",
		"%d stages checked, %d traps%s" % [checked, traps, "" if worst.is_empty() else ", first at " + worst])

	# And the same for the daily pool, which is dealt from its own seeds.
	var daily_traps: int = 0
	for day in range(0, 60):
		var seed_val: int = 20260101 + day
		var rng2 := RandomNumberGenerator.new()
		rng2.seed = seed_val
		var layout: String = StagePlan.layout_for_level((day % StagePlan.TOTAL_LEVELS) + 1)
		daily_traps += _count(BoardGenerator.deal_board(layout, rng2))
	_check(daily_traps == 0, "nor does any of 60 daily seeds", "%d traps" % daily_traps)

	print("")
	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _count(tiles: Array[RiverTile]) -> int:
	var at: Dictionary = {}
	for t in tiles:
		at[Vector3i(t.x, t.y, t.z)] = t
	var n: int = 0
	for t in tiles:
		var above = at.get(Vector3i(t.x, t.y, t.z + 1))
		if above != null and above.get_match_key() == t.get_match_key():
			n += 1
	return n


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		_fails += 1
	print("  %s  %-48s %s" % ["PASS" if ok else "FAIL", what, detail])
