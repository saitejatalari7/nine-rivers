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

	# "Back tomorrow" told the player nothing they could act on: both caps roll
	# at UTC midnight, which in India is half past five in the morning, so
	# "tomorrow" could mean twenty minutes or a whole day.
	var msg: String = SaveManager.time_until_reset()
	_check(msg.begins_with("back in "), "the wait is quoted, not called tomorrow", msg)
	var mins: int = _minutes_in(msg)
	_check(mins > 0 and mins <= 1440, "and it is inside one day", "%d minutes" % mins)

	print("")
	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


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
