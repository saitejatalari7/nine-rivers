extends Node

## Time Rapids is three runs a day, the Daily Tide is one board a day, and Calm
## is uncapped so there is always somewhere to go when the other two are spent.
## Without that last part a cap is just a locked door.

const RiverTile = preload("res://scripts/core/river_tile.gd")
const RAPIDS_RUNS_PER_DAY: int = 3

var _fails: int = 0


func _ready() -> void:
	await get_tree().process_frame

	var today: String = SaveManager._today_utc()
	SaveManager.prog["last_rapids_date"] = today
	SaveManager.prog["rapids_runs_today"] = 0

	_check(SaveManager.rapids_runs_left() == SaveManager.RAPIDS_RUNS_PER_DAY,
		"a fresh day has all runs", "%d left" % SaveManager.rapids_runs_left())

	var taken: int = 0
	while SaveManager.record_rapids_start():
		taken += 1
		if taken > 10:
			break
	_check(taken == SaveManager.RAPIDS_RUNS_PER_DAY,
		"exactly %d runs are allowed" % SaveManager.RAPIDS_RUNS_PER_DAY, "took %d" % taken)
	_check(SaveManager.rapids_runs_left() == 0, "then none are left",
		"%d left" % SaveManager.rapids_runs_left())

	# Winding the clock backwards must not refill them.
	SaveManager.prog["last_rapids_date"] = "2099-01-01"
	_check(SaveManager.rapids_runs_left() == 0,
		"a backwards clock does not refill runs",
		"%d left" % SaveManager.rapids_runs_left())

	# A genuinely later date does.
	SaveManager.prog["last_rapids_date"] = "2000-01-01"
	_check(SaveManager.rapids_runs_left() == SaveManager.RAPIDS_RUNS_PER_DAY,
		"a new day refills them", "%d left" % SaveManager.rapids_runs_left())

	# The daily is one board a day.
	SaveManager.prog["last_daily_date"] = ""
	_check(not SaveManager.daily_done_today(), "the daily starts available", "")
	SaveManager.record_daily_play()
	_check(SaveManager.daily_done_today(), "and is spent once cleared", "")

	# Calm must never be gated by either.
	_check(SaveManager.prog.has("level"), "Calm has no daily counter of its own",
		"level=%s" % str(SaveManager.prog.get("level")))

	# "Back tomorrow" told the player nothing they could act on: both caps roll
	# at UTC midnight, which in India is half past five in the morning, so
	# "tomorrow" could mean twenty minutes or a whole day.
	var msg: String = SaveManager.time_until_reset()
	_check(msg.begins_with("back in "), "the wait is quoted, not called tomorrow", msg)
	var mins: int = _minutes_in(msg)
	_check(mins > 0 and mins <= 1440, "and it is inside one day", "%d minutes" % mins)

	await _looking_is_free()

	print("")
	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


## Opening the timed mode and backing out without playing used to spend a run.
## Three looks cost a whole day of them, which is what a tester hit.
func _looking_is_free() -> void:
	print("--- opening the mode is not playing it ---")
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = true
	await get_tree().create_timer(1.2).timeout
	SaveManager.prog["rapids_runs_today"] = 0
	SaveManager.prog["last_rapids_date"] = ""
	SaveManager.clear_session()

	for i in range(3):
		main._start_run_mode()
		await get_tree().create_timer(0.7).timeout
		main._return_home()
		await get_tree().create_timer(0.3).timeout
	_check(SaveManager.rapids_runs_left() == RAPIDS_RUNS_PER_DAY,
		"three looks cost nothing", "%d left" % SaveManager.rapids_runs_left())

	main._start_run_mode()
	await get_tree().create_timer(0.8).timeout
	var board = main.get_node("Board")
	var sets: Array = board.get_legal_sets()
	if not sets.is_empty():
		var typed: Array[RiverTile] = []
		for t in sets[0]:
			typed.append(t)
		board._resolve_matched_set(typed)
	await get_tree().create_timer(0.6).timeout
	_check(SaveManager.rapids_runs_left() == RAPIDS_RUNS_PER_DAY - 1,
		"the first match spends one", "%d left" % SaveManager.rapids_runs_left())

	sets = board.get_legal_sets()
	if not sets.is_empty():
		var typed2: Array[RiverTile] = []
		for t in sets[0]:
			typed2.append(t)
		board._resolve_matched_set(typed2)
	await get_tree().create_timer(0.6).timeout
	_check(SaveManager.rapids_runs_left() == RAPIDS_RUNS_PER_DAY - 1,
		"and the second does not spend another", "%d left" % SaveManager.rapids_runs_left())


## Parses "back in 7h 20m" or "back in 20m" back into minutes, so the string the
## player reads is the thing being checked rather than the maths behind it.
func _minutes_in(msg: String) -> int:
	var total: int = 0
	for part in msg.replace("back in ", "").split(" ", false):
		if part.ends_with("h"):
			total += int(part.trim_suffix("h")) * 60
		elif part.ends_with("m"):
			total += int(part.trim_suffix("m"))
	return total


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		_fails += 1
	print("  %s  %-44s %s" % ["PASS" if ok else "FAIL", what, detail])
