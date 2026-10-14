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
	var SP = load("res://scripts/core/stage_plan.gd")
	var LD = load("res://scripts/core/layout_data.gd")
	# Every shape Timed Mode can deal, in each stage's size band, must leave a
	# fair clock - the worst modifier that stage can roll included.
	for stage in 3:
		var band: Vector2i = SP.TIMED_BANDS[stage]
		var worst: float = 99.0
		var worst_name: String = ""
		var count: int = 0
		for name in LD.LAYOUTS.keys():
			var tiles: int = SP.layout_size(name)
			if tiles < band.x or tiles > band.y:
				continue
			count += 1
			for fog_rush in [[false, false], [true, false], [false, true]]:
				var t: float = GameManager.stage_time_for(tiles, fog_rush[0], fog_rush[1])
				var eff: float = t / (1.5 if fog_rush[1] else 1.0)
				var per_pair: float = eff / (tiles * 0.5)
				if per_pair < worst:
					worst = per_pair
					worst_name = name
		_check("stage %d: all %d shapes allow 3.5 s per pair" % [stage + 1, count], worst >= 3.5 and count >= 5,
			"worst %.1f s (%s)" % [worst, worst_name])

	var seen: Dictionary = {}
	for game in 6:
		SaveManager.prog["rapids_runs_today"] = 0
		main._start_run_mode()
		await get_tree().create_timer(0.3).timeout
		seen[GameManager.current_layout_name] = true
	_check("Timed Mode games start on different shapes", seen.size() >= 3, "%d shapes in 6 games" % seen.size())

	SaveManager.prog["rapids_runs_today"] = 0
	main._start_run_mode()
	await get_tree().create_timer(0.6).timeout
	var names: Array = [GameManager.current_layout_name]
	var s1: float = GameManager.max_time
	_check("stage 1 opens with its own allotment", absf(s1 - GameManager.stage_time_for(SP.layout_size(names[0]), false, false)) < 1.0, "%.0f" % s1)

	GameManager.time_left = 500.0
	main._next_stage()
	await get_tree().create_timer(0.6).timeout
	names.append(GameManager.current_layout_name)
	var allot2: float = GameManager.stage_time_for(SP.layout_size(names[1]), StageModifiers.is_fog_active(), StageModifiers.is_rush_active())
	_check("carry-over is capped at half the new allotment", absf(GameManager.time_left - allot2 * 1.5) < 1.0,
		"%.0f vs %.0f" % [GameManager.time_left, allot2 * 1.5])
	_check("and the bar opens full", GameManager.max_time - GameManager.time_left < 1.5, "%.1f short" % (GameManager.max_time - GameManager.time_left))

	GameManager.time_left = 3.0
	main._next_stage()
	await get_tree().create_timer(0.6).timeout
	names.append(GameManager.current_layout_name)
	var allot3: float = GameManager.stage_time_for(SP.layout_size(names[2]), StageModifiers.is_fog_active(), StageModifiers.is_rush_active())
	_check("a nearly spent clock still gets the full new stage", GameManager.time_left >= allot3, "%.0f" % GameManager.time_left)
	_check("the three stages are three different shapes", names[0] != names[1] and names[1] != names[2] and names[0] != names[2], "%s" % [names])
	_check("and they grow stage by stage", SP.layout_size(names[0]) <= SP.layout_size(names[2]), "%d, %d, %d tiles" % [SP.layout_size(names[0]), SP.layout_size(names[1]), SP.layout_size(names[2])])

	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

func _check(what: String, ok: bool, detail: String) -> void:
	if not ok:
		_fails += 1
	print("  %s  %-52s %s" % ["PASS" if ok else "FAIL", what, detail])
