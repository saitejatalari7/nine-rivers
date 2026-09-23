extends Node

## When an interstitial is allowed to appear.
##
## The rule the owner asked for: nothing until three levels have been played,
## then sensible spacing. The spacing already existed but lived entirely in
## memory and timed from Time.get_ticks_msec(), so closing and reopening the app
## cleared it - a player who restarted between levels saw an ad every time.
##
## Each case asserts the REASON, not just the verdict. "No ad appeared" is true
## for six different reasons and they are not interchangeable; a test that only
## checks the boolean passes just as happily when the wrong rule fired.

var _fails: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_reset()

	SaveManager.economy["stages_since_ad"] = 99
	_expect(1, "too_early", "level 1 is left alone")
	_expect(2, "too_early", "level 2 is left alone")
	_expect(3, "too_early", "level 3 is left alone")
	_expect(MonetizationManager.INTERSTITIAL_START_LEVEL, "",
		"level %d is allowed" % MonetizationManager.INTERSTITIAL_START_LEVEL)

	# Spacing by stages.
	_reset()
	SaveManager.economy["stages_since_ad"] = 0
	_expect(10, "too_few_stages", "a stage after an ad is too soon")
	SaveManager.economy["stages_since_ad"] = MonetizationManager.INTERSTITIAL_MIN_LEVELS
	_expect(10, "", "%d stages later is allowed" % MonetizationManager.INTERSTITIAL_MIN_LEVELS)

	# Spacing by time, and the part that used to reset on relaunch.
	var now: float = float(Time.get_unix_time_from_system())
	SaveManager.economy["last_interstitial_unix"] = now - 10.0
	_expect(10, "too_soon", "ten seconds after an ad is too soon")
	SaveManager.economy["last_interstitial_unix"] = now - MonetizationManager.INTERSTITIAL_MIN_INTERVAL - 1.0
	_expect(10, "", "past the interval is allowed")

	# A purchase buys quiet.
	SaveManager.economy["last_purchase_unix"] = now - 5.0
	_expect(10, "just_purchased", "no ad right after a purchase")
	SaveManager.economy["last_purchase_unix"] = now - MonetizationManager.POST_PURCHASE_QUIET - 1.0
	_expect(10, "", "past the quiet window is allowed")

	# no_ads outranks everything.
	SaveManager.economy["no_ads_purchased"] = true
	_expect(99, "no_ads_purchased", "a paying player never sees one")
	SaveManager.economy["no_ads_purchased"] = false

	# A clock wound backwards leaves a future timestamp, which must read as
	# quiet rather than as licence.
	SaveManager.economy["last_interstitial_unix"] = now + 86400.0
	_expect(10, "clock_moved", "a future timestamp does not unlock ads")

	# The counters survive a restart, which is the whole point.
	_reset()
	SaveManager.economy["stages_since_ad"] = 2
	SaveManager.economy["last_interstitial_unix"] = now - 5.0
	SaveManager.save_game()
	SaveManager.economy["stages_since_ad"] = 0
	SaveManager.economy["last_interstitial_unix"] = 0.0
	SaveManager.load_game()
	_check(int(SaveManager.economy.get("stages_since_ad", -1)) == 2,
		"stages since the last ad survive a reload",
		"got %s" % str(SaveManager.economy.get("stages_since_ad")))
	_check(float(SaveManager.economy.get("last_interstitial_unix", 0.0)) > 0.0,
		"the last ad time survives a reload",
		"got %s" % str(SaveManager.economy.get("last_interstitial_unix")))

	print("")
	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _reset() -> void:
	SaveManager.economy["no_ads_purchased"] = false
	SaveManager.economy["last_interstitial_unix"] = 0.0
	SaveManager.economy["last_purchase_unix"] = 0.0
	SaveManager.economy["stages_since_ad"] = 0


func _expect(level: int, reason: String, what: String) -> void:
	var got: String = MonetizationManager.interstitial_block_reason(level)
	_check(got == reason, what, "reason=\"%s\" expected \"%s\"" % [got, reason])


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		_fails += 1
	print("  %s  %-46s %s" % ["PASS" if ok else "FAIL", what, detail])
