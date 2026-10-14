extends Node

## The next level is dealt on a worker thread while the current one is played.
## That deal must be the very board a fresh deal of the level gives.

const StagePlan = preload("res://scripts/core/stage_plan.gd")
const BoardGenerator = preload("res://scripts/core/board_generator.gd")
var _fails: int = 0

func _sig(tiles: Array) -> String:
	var parts: Array = []
	for t in tiles:
		parts.append("%d,%d,%d,%s%d,%d,%s" % [t.x, t.y, t.z, t.suit, t.rank, t.set_id, t.is_glass])
	parts.sort()
	return ";".join(parts)

func _ready() -> void:
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = true
	await get_tree().create_timer(1.0).timeout
	main.get_node("Modal").hide_modal()
	for lv in [77, 300, 455]:
		main._prefetch_level(lv)
		var waited: int = 0
		while not main._prefetched.has(lv) and waited < 300:
			await get_tree().process_frame
			waited += 1
		_check("level %d is dealt in the background" % lv, main._prefetched.has(lv), "")
		var plan: Dictionary = StagePlan.describe(lv)
		var rng := RandomNumberGenerator.new()
		rng.seed = plan["seed"]
		var fresh: String = _sig(BoardGenerator.deal_board(plan["layout"], rng))
		var early: String = _sig(main._prefetched[lv]["tiles"]) if main._prefetched.has(lv) else ""
		_check("and it is the same board a fresh deal gives", early == fresh, plan["layout"])
		main._start_calm_mode(lv)
		await get_tree().create_timer(0.5).timeout
		_check("starting the level uses it", not main._prefetched.has(lv) and _sig(main.get_node("Board").live_tiles) == fresh, "")
		_check("and the level after is dealt next", main._prefetching.has(lv + 1) or main._prefetched.has(lv + 1), "")
	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

func _check(what: String, ok: bool, detail: String) -> void:
	if not ok:
		_fails += 1
	print("  %s  %-48s %s" % ["PASS" if ok else "FAIL", what, detail])
