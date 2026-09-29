extends Node

## Timed mode must give every stage a fair clock for its size, compensate
## Fog and Rush, and carry leftover time forward only as a capped bonus.

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

	var BG = load("res://scripts/core/board_generator.gd")
	var prev: float = 0.0
	print("stage  board        tiles  modifier  seconds  s/pair")
	for i in 5:
		var name: String = BG.LADDER[i]
		var tiles: int = BG.get_layout_positions(name).size()
		StageModifiers.set_modifier_for_stage(1, i + 1)
		var t: float = GameManager.stage_time_for(tiles, StageModifiers.is_fog_active(), StageModifiers.is_rush_active())
		var eff: float = t / (1.5 if StageModifiers.is_rush_active() else 1.0)
		print("  %d    %-12s %3d    %-8s  %4.0f    %.1f" % [i + 1, name, tiles, StageModifiers.get_modifier_name(), t, eff / (tiles * 0.5)])
		_check("stage %d allows at least 3.5 s per pair of real time" % (i + 1), eff / (tiles * 0.5) >= 3.5, "")
		prev = t

	main._start_run_mode()
	await get_tree().create_timer(0.6).timeout
	var s1: float = GameManager.max_time
	_check("stage 1 opens with its own allotment", absf(s1 - GameManager.stage_time_for(36, false, false)) < 1.0, "%.0f" % s1)

	GameManager.time_left = 500.0
	main._next_stage()
	await get_tree().create_timer(0.6).timeout
	var allot2: float = GameManager.stage_time_for(40, StageModifiers.is_fog_active(), StageModifiers.is_rush_active())
	_check("carry-over is capped at half the new allotment", absf(GameManager.time_left - allot2 * 1.5) < 1.0,
		"%.0f vs %.0f" % [GameManager.time_left, allot2 * 1.5])
	_check("and the bar opens full", GameManager.max_time - GameManager.time_left < 1.5, "%.1f short" % (GameManager.max_time - GameManager.time_left))

	GameManager.time_left = 3.0
	main._next_stage()
	await get_tree().create_timer(0.6).timeout
	var allot3: float = GameManager.stage_time_for(60, StageModifiers.is_fog_active(), StageModifiers.is_rush_active())
	_check("a nearly spent clock still gets the full new stage", GameManager.time_left >= allot3, "%.0f" % GameManager.time_left)

	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

func _check(what: String, ok: bool, detail: String) -> void:
	if not ok:
		_fails += 1
	print("  %s  %-52s %s" % ["PASS" if ok else "FAIL", what, detail])
