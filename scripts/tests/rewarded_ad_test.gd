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
	_run_offer_gate()
	await _run_adjacent_holes()

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


## The offers must appear exactly when taking one would do something, or the
## screen either lies or hides a working reward. Gating the UI on
## is_rewarded_ad_available() alone hid them in debug builds too.
func _run_offer_gate() -> void:
	SaveManager.economy["rewarded_ads_today"] = 0
	MonetizationManager.debug_force_release_mobile = false
	_check(MonetizationManager.can_offer_rewarded_ad(),
		"debug build offers the reward it would actually grant",
		"can_offer=%s" % MonetizationManager.can_offer_rewarded_ad())

	MonetizationManager.debug_force_release_mobile = true
	_check(not MonetizationManager.can_offer_rewarded_ad(),
		"release mobile with no ad network offers nothing",
		"can_offer=%s" % MonetizationManager.can_offer_rewarded_ad())
	MonetizationManager.debug_force_release_mobile = false

	SaveManager.economy["rewarded_ads_today"] = MonetizationManager.MAX_DAILY_REWARDED_ADS
	_check(not MonetizationManager.can_offer_rewarded_ad(),
		"a spent daily cap offers nothing",
		"can_offer=%s" % MonetizationManager.can_offer_rewarded_ad())
	SaveManager.economy["rewarded_ads_today"] = 0


## A stray reward callback with nothing pending used to fall to the catch-all
## arm and pay 50 pearls. The clock reset used to fire on ANY date mismatch, so
## winding the device clock back and forward refilled the charges.
func _run_adjacent_holes() -> void:
	var before: int = MonetizationManager.get_pearls()
	MonetizationManager._on_admob_reward_granted("", 0)
	MonetizationManager._on_admob_reward_granted("", 0)
	await get_tree().process_frame
	_check(MonetizationManager.get_pearls() == before,
		"a reward callback with nothing pending grants nothing",
		"%d -> %d over 2 stray calls" % [before, MonetizationManager.get_pearls()])

	var dt := Time.get_date_dict_from_system(true)
	var today := "%04d-%02d-%02d" % [dt["year"], dt["month"], dt["day"]]
	SaveManager.economy["last_rewarded_date"] = today
	SaveManager.economy["rewarded_ads_today"] = MonetizationManager.MAX_DAILY_REWARDED_ADS
	# A clock wound BACKWARDS must not look like a new day.
	SaveManager.economy["last_rewarded_date"] = "2099-01-01"
	_check(MonetizationManager.get_remaining_rewarded_ads() == 0,
		"a backwards clock does not refill the charges",
		"remaining=%d" % MonetizationManager.get_remaining_rewarded_ads())
	SaveManager.economy["last_rewarded_date"] = today
	SaveManager.economy["rewarded_ads_today"] = 0
