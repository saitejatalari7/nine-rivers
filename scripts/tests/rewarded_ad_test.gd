extends Node

## show_rewarded_ad() used to fall through to _grant_reward() when no ad plugin
## was present, which is the shipping state. Four offers a day at 60 pearls each
## paid out with nothing watched, for a currency otherwise sold for money.
## buy_product() has always refused to fulfil in the same situation.
##
## No ad plugin exists on desktop either, so these runs exercise the real path.

var _fails: int = 0
## GDScript lambdas capture locals by value, so a flag set inside one has to
## live on the node or the test silently reads a copy that never changed.
var _unavailable_fired: bool = false


func _ready() -> void:
	await get_tree().process_frame

	_check(not MonetizationManager.is_rewarded_ad_available(),
		"no ad network is present in this build",
		"available=%s" % MonetizationManager.is_rewarded_ad_available())

	# Desktop is a debug build, where the simulated grant is deliberately kept.
	# The branch that matters is mobile release, which is unreachable here unless
	# it is forced - so it is forced, rather than left untested.
	SaveManager.economy["rewarded_ads_today"] = 0
	var pearls_before: int = MonetizationManager.get_pearls()
	var charges_before: int = MonetizationManager.get_remaining_rewarded_ads()

	MonetizationManager.show_rewarded_ad("daily_pearls")
	await get_tree().process_frame

	if not MonetizationManager.debug_force_release_mobile:
		_check(MonetizationManager.get_pearls() == pearls_before + 60,
			"debug build keeps the simulated grant",
			"%d -> %d" % [pearls_before, MonetizationManager.get_pearls()])
		_check(MonetizationManager.get_remaining_rewarded_ads() == charges_before - 1,
			"a granted offer consumes one charge",
			"%d -> %d" % [charges_before, MonetizationManager.get_remaining_rewarded_ads()])
	else:
		_check(MonetizationManager.get_pearls() == pearls_before,
			"release build grants nothing without an ad",
			"%d -> %d" % [pearls_before, MonetizationManager.get_pearls()])
		_check(MonetizationManager.get_remaining_rewarded_ads() == charges_before,
			"a refused offer must not burn a charge",
			"%d -> %d" % [charges_before, MonetizationManager.get_remaining_rewarded_ads()])

	# The cap still holds whatever path is taken.
	SaveManager.economy["rewarded_ads_today"] = MonetizationManager.MAX_DAILY_REWARDED_ADS
	var capped_before: int = MonetizationManager.get_pearls()
	MonetizationManager.show_rewarded_ad("daily_pearls")
	await get_tree().process_frame
	_check(MonetizationManager.get_pearls() == capped_before,
		"the daily cap still refuses a grant",
		"%d -> %d" % [capped_before, MonetizationManager.get_pearls()])

	await _run_release_mobile()

	print("")
	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		_fails += 1
	print("  %s  %-48s %s" % ["PASS" if ok else "FAIL", what, detail])


func _run_release_mobile() -> void:
	MonetizationManager.debug_force_release_mobile = true
	SaveManager.economy["rewarded_ads_today"] = 0
	var pearls_before: int = MonetizationManager.get_pearls()
	var charges_before: int = MonetizationManager.get_remaining_rewarded_ads()
	_unavailable_fired = false
	var conn := func(_p): _unavailable_fired = true
	MonetizationManager.rewarded_ad_unavailable.connect(conn)

	MonetizationManager.show_rewarded_ad("daily_pearls")
	await get_tree().process_frame

	_check(MonetizationManager.get_pearls() == pearls_before,
		"RELEASE MOBILE: grants nothing without an ad",
		"%d -> %d" % [pearls_before, MonetizationManager.get_pearls()])
	_check(_unavailable_fired, "RELEASE MOBILE: reports the offer unavailable",
		"signal fired=%s" % _unavailable_fired)
	_check(MonetizationManager.get_remaining_rewarded_ads() == charges_before,
		"RELEASE MOBILE: a refused offer does not burn a charge",
		"%d -> %d" % [charges_before, MonetizationManager.get_remaining_rewarded_ads()])

	MonetizationManager.rewarded_ad_unavailable.disconnect(conn)
	MonetizationManager.debug_force_release_mobile = false
