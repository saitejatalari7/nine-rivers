extends Node

## Nine Rivers — Time Rapids clock harness
## Boots the real main.tscn and drives a Rapids run through a genuine board
## clear into the next stage, because the freeze this exists to catch lives in
## the handover between main.gd's clear handler and GameManager, not in either
## one alone.
##
## Run: godot --rendering-driver opengl3 --audio-driver Dummy --path . scenes/rapids_clock_test.tscn

## Not read from GameManager, so this harness still runs (and still fails)
## against a build that sets the ceiling some other way.
const RAPIDS_START: float = 100.0

var main: Node2D
var _failures: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	await _boot()
	await _t1_clock_runs_after_the_first_stage()
	await _t2_a_frozen_clock_is_not_topped_up()
	await _t3_the_bar_opens_full_in_every_mode()
	_report()
	get_tree().quit(1 if not _failures.is_empty() else 0)

func _boot() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	main = packed.instantiate()
	add_child(main)
	# The boot splash dissolves over ~0.55s and ends by calling _return_home(),
	# which stops the clock. Driving a mode before that lands has the splash
	# reset it out from under the test.
	await get_tree().create_timer(1.2).timeout

func _check(name: String, passed: bool, detail: String) -> void:
	print("  %s  %-52s %s" % [("PASS" if passed else "FAIL"), name, detail])
	if not passed:
		_failures.append(name)

# ---------------------------------------------------------------------------

## The bug: _on_board_cleared() stops the clock so it holds still under the
## reward screen, and nothing on the way into stage 2 started it again. From the
## second stage onward the countdown never moved for the rest of the run.
func _t1_clock_runs_after_the_first_stage() -> void:
	print("--- #1  The clock survives a stage boundary ---")
	main._start_run_mode()
	await get_tree().process_frame
	_check("stage 1 starts the clock", GameManager.is_timer_active,
		"is_timer_active=%s" % str(GameManager.is_timer_active))

	# The real clear path, which is what switches the clock off.
	main._on_board_cleared()
	await get_tree().process_frame
	_check("a cleared board stops the clock", not GameManager.is_timer_active,
		"is_timer_active=%s" % str(GameManager.is_timer_active))

	main._next_stage()
	await get_tree().process_frame
	_check("stage 2 starts the clock again", GameManager.is_timer_active,
		"stage=%d is_timer_active=%s" % [GameManager.current_stage_no, str(GameManager.is_timer_active)])

	# is_timer_active alone is only a flag. Prove the countdown actually moves,
	# so a future change that sets the flag without arming _process still fails.
	var before: float = GameManager.time_left
	await get_tree().create_timer(0.6).timeout
	var after: float = GameManager.time_left
	_check("the countdown really counts down in stage 2", after < before - 0.3,
		"time_left %.2f -> %.2f over ~0.6s" % [before, after])

## With the clock frozen, every match still called the time reward, so the bar
## only ever rose. The reward has to follow the clock, not the mode.
func _t2_a_frozen_clock_is_not_topped_up() -> void:
	print("--- #2  A stopped clock is not refilled by matches ---")
	GameManager.is_timer_active = false
	var before: float = GameManager.time_left
	GameManager.register_match("dot", false)
	GameManager.register_match("dot", true)
	var after: float = GameManager.time_left
	_check("matches add no time while the clock is stopped", is_equal_approx(before, after),
		"time_left %.2f -> %.2f across 2 matches" % [before, after])

	GameManager.is_timer_active = true
	var b2: float = GameManager.time_left
	GameManager.register_match("dot", false)
	_check("matches still add time while the clock runs", GameManager.time_left > b2,
		"time_left %.2f -> %.2f" % [b2, GameManager.time_left])

## max_time is the HUD bar's denominator. It is the time the mode starts with,
## so the bar opens full in every mode - it used to be a fixed ceiling the start
## time was measured against, which opened Rapids at 56%.
func _t3_the_bar_opens_full_in_every_mode() -> void:
	print("--- #3  the time bar opens full ---")
	GameManager.start_daily_tide()
	GameManager.apply_daily_time(144)
	await get_tree().process_frame
	var daily_fill: float = GameManager.time_left / GameManager.max_time
	# Not is_equal_approx: the clock is already running, so a frame of drain
	# lands a fraction under 1.0 and that is not what this is looking for.
	_check("a long Daily opens full", daily_fill > 0.99,
		"time_left=%.0f / max_time=%.0f" % [GameManager.time_left, GameManager.max_time])

	main._start_run_mode()
	await get_tree().process_frame
	var fill: float = GameManager.time_left / GameManager.max_time
	_check("Rapids after a Daily opens full", fill > 0.99,
		"time_left=%.0f / max_time=%.0f = %.0f%%" % [GameManager.time_left, GameManager.max_time, fill * 100.0])
	_check("and its ceiling is the Rapids start, not the Daily's",
		is_equal_approx(GameManager.max_time, RAPIDS_START),
		"max_time=%.0f (expected %.0f)" % [GameManager.max_time, RAPIDS_START])

func _report() -> void:
	print("")
	print("Failures: %d" % _failures.size())
	for f in _failures:
		print("  FAILED: %s" % f)
