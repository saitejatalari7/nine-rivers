extends Node

## Time Rapids is three runs a day, the Daily Tide is one board a day, and Calm
## is uncapped so there is always somewhere to go when the other two are spent.
## Without that last part a cap is just a locked door.

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

	print("")
	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		_fails += 1
	print("  %s  %-44s %s" % ["PASS" if ok else "FAIL", what, detail])
