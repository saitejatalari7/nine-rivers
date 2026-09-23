extends Node

## Nine Rivers — Verification for save durability (#1) and Play-authoritative
## entitlements (#2). Re-runs the attacks that previously succeeded and checks
## that each one now fails.
##
## Run: godot --headless --audio-driver Dummy --path . scenes/hardening_test.tscn

const SAVE_PATH := "user://nine_rivers_save.json"
const BACKUP_PATH := "user://nine_rivers_save.bak"
const TEMP_PATH := "user://nine_rivers_save.tmp"

var _pass: int = 0
var _fail: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("")
	print("========= DURABILITY + ENTITLEMENT VERIFICATION =========")

	print("")
	print("--- #1  Save durability ---")
	_d1_backup_is_created()
	_d2_truncated_primary_recovers()
	_d3_crash_mid_rotation_recovers()
	_d4_all_copies_destroyed_is_survivable()

	print("")
	print("--- #2  Google Play as the purchase authority ---")
	_p1_new_phone_restores_purchases()
	_p2_forged_no_ads_is_revoked()
	_p3_pearl_bought_theme_survives()
	_p4_offline_query_never_revokes()
	_p5_background_purchase_now_grants()

	print("")
	print("--- #3  Load validation and clamping ---")
	_v1_wrong_types_fall_back_to_defaults()
	_v2_level_clear_survives_hostile_save()
	_v3_out_of_range_numbers_clamped()
	_v4_unknown_ids_rejected()
	_v5_int_types_stable_across_reload()
	_v6_version_2_profile_still_loads()

	print("")
	print("Passed: %d    Failed: %d" % [_pass, _fail])
	print("========================================================")
	get_tree().quit(1 if _fail > 0 else 0)

# ---------------------------------------------------------------- helpers

func _check(name: String, condition: bool, detail: String) -> void:
	if condition:
		_pass += 1
		print("  PASS  %-46s %s" % [name, detail])
	else:
		_fail += 1
		printerr("  FAIL  %-46s %s" % [name, detail])

func _wipe_all() -> void:
	for p in [SAVE_PATH, BACKUP_PATH, TEMP_PATH]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func _fresh_profile(level: int, pearls_seed: int) -> void:
	SaveManager.prog = {
		"level": level, "best_score": 1000, "best_stage": 0, "stars": {"1": 3},
		"river_jade": 0, "daily_streak": 0, "last_daily_date": "",
		"streak_shields": 1, "tutorial_completed": true
	}
	SaveManager.economy = {
		"pearls": pearls_seed, "no_ads_purchased": false,
		"unlocked_themes": ["classic_jade"], "active_tile_theme": "classic_jade",
		"unlocked_background_themes": ["emerald_pond", "moonlit_river", "autumn_stream"],
		"active_background_theme": "auto", "active_mat_theme": "river_felt",
		"rewarded_ads_today": 0, "last_rewarded_date": "", "entitlement_source": {}
	}
	SaveManager.tile_mastery = {}

func _truncate(path: String, fraction: float) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	var full: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(full.slice(0, int(full.size() * fraction)))
	f.close()

func _play_response(product_ids: Array, code: int = 0) -> Dictionary:
	var purchases: Array = []
	for pid in product_ids:
		purchases.append({
			"sku": pid, "product_id": pid,
			"purchase_state": 1, "is_acknowledged": true,
			"purchase_token": "tok_" + str(pid)
		})
	return {"response_code": code, "purchases": purchases}

# ---------------------------------------------------------------- #1 durability

func _d1_backup_is_created() -> void:
	_wipe_all()
	_fresh_profile(10, 1000)
	SaveManager.save_game()
	var first_only: bool = FileAccess.file_exists(SAVE_PATH) and not FileAccess.file_exists(BACKUP_PATH)

	SaveManager.prog["level"] = 11
	var ok: bool = SaveManager.save_game()
	_check("backup rotates on second save",
		ok and FileAccess.file_exists(SAVE_PATH) and FileAccess.file_exists(BACKUP_PATH) and not FileAccess.file_exists(TEMP_PATH) and first_only,
		"save + .bak present, scratch file cleaned up")

func _d2_truncated_primary_recovers() -> void:
	_wipe_all()
	_fresh_profile(25, 5000)
	SaveManager.save_game()
	SaveManager.prog["level"] = 26
	SaveManager.save_game() # level 26 live, level 25 in backup

	# The exact attack from audit T07.
	_truncate(SAVE_PATH, 0.6)
	SaveManager.prog = {}
	SaveManager.economy = {}
	SaveManager.load_game()

	var lvl: int = int(SaveManager.prog.get("level", 0))
	_check("truncated save recovers from backup", lvl == 25,
		"level reloaded as %d (was 1 before the fix)" % lvl)

func _d3_crash_mid_rotation_recovers() -> void:
	_wipe_all()
	_fresh_profile(30, 7000)
	SaveManager.save_game()

	# Reproduce a kill between "rename save -> bak" and "rename tmp -> save":
	# the live file is gone, the verified scratch file holds the newest data.
	DirAccess.rename_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(BACKUP_PATH))
	SaveManager.prog["level"] = 31
	var data := {
		"prog": SaveManager.prog, "sanctuary": SaveManager.sanctuary,
		"tile_mastery": SaveManager.tile_mastery, "settings": SaveManager.settings,
		"economy": SaveManager.economy, "version": 2,
		"checksum": SaveManager._compute_checksum(SaveManager.prog, SaveManager.economy)
	}
	var f := FileAccess.open_encrypted_with_pass(TEMP_PATH, FileAccess.WRITE, SaveManager._ENC_KEY)
	f.store_string(JSON.stringify(data))
	f.close()

	SaveManager.prog = {}
	SaveManager.load_game()
	var lvl: int = int(SaveManager.prog.get("level", 0))
	_check("crash mid-rotation keeps newest data", lvl == 31,
		"recovered level %d from the verified scratch file" % lvl)

func _d4_all_copies_destroyed_is_survivable() -> void:
	_wipe_all()
	_fresh_profile(12, 900)
	SaveManager.save_game()
	SaveManager.prog["level"] = 13
	SaveManager.save_game()

	_truncate(SAVE_PATH, 0.4)
	_truncate(BACKUP_PATH, 0.4)
	SaveManager.prog = {"level": 1, "river_jade": 100, "stars": {}}
	SaveManager.load_game()

	_check("total loss degrades cleanly", int(SaveManager.prog.get("level", 0)) == 1,
		"no crash; falls back to a fresh profile")

# ---------------------------------------------------------------- #2 entitlements

## The question that matters: new phone, same Google account.
func _p1_new_phone_restores_purchases() -> void:
	_wipe_all()
	_fresh_profile(1, 100) # brand new device: owns nothing locally
	MonetizationManager._on_billing_query_purchases_response(
		_play_response(["no_ads", "theme_imperial_gold"]))

	var restored_ads: bool = MonetizationManager.is_no_ads()
	var restored_theme: bool = MonetizationManager.is_theme_unlocked("theme_imperial_gold")
	_check("new phone restores paid purchases", restored_ads and restored_theme,
		"no_ads=%s, Imperial Gold=%s, restored from Play with no login" % [str(restored_ads), str(restored_theme)])

func _p2_forged_no_ads_is_revoked() -> void:
	_wipe_all()
	# A tampered save claiming every paid product, exactly as audit T02/T03 produced.
	_fresh_profile(99, 9999999)
	SaveManager.economy["no_ads_purchased"] = true
	SaveManager.economy["unlocked_themes"] = ["classic_jade", "theme_imperial_gold", "theme_obsidian_ink"]
	SaveManager.economy["entitlement_source"] = {"theme_imperial_gold": "iap"}

	MonetizationManager._on_billing_query_purchases_response(_play_response([]))

	var ads_gone: bool = not MonetizationManager.is_no_ads()
	var iap_theme_gone: bool = not MonetizationManager.is_theme_unlocked("theme_imperial_gold")
	_check("forged entitlements are withdrawn", ads_gone and iap_theme_gone,
		"no_ads revoked=%s, forged IAP theme revoked=%s" % [str(ads_gone), str(iap_theme_gone)])

func _p3_pearl_bought_theme_survives() -> void:
	_wipe_all()
	_fresh_profile(5, 500)
	SaveManager.economy["pearls"] = 5000
	MonetizationManager.buy_with_pearls("theme_cherry_blossom")
	var bought: bool = MonetizationManager.is_theme_unlocked("theme_cherry_blossom")

	# Play has no record of an in-game purchase and must not take it away.
	MonetizationManager._on_billing_query_purchases_response(_play_response([]))

	_check("pearl-bought theme survives reconcile",
		bought and MonetizationManager.is_theme_unlocked("theme_cherry_blossom"),
		"bought with pearls, still owned after Play reported nothing")

func _p4_offline_query_never_revokes() -> void:
	_wipe_all()
	_fresh_profile(5, 500)
	SaveManager.economy["no_ads_purchased"] = true
	SaveManager.economy["entitlement_source"] = {"no_ads": "iap"}

	# Network error. Must be read as "unknown", never as "owns nothing".
	MonetizationManager._on_billing_query_purchases_response(_play_response([], 2))

	_check("failed query does not revoke", MonetizationManager.is_no_ads(),
		"no_ads retained through a billing error (response_code 2)")

func _p5_background_purchase_now_grants() -> void:
	_wipe_all()
	_fresh_profile(5, 500)
	MonetizationManager._on_billing_query_purchases_response(_play_response(["bg_misty_spring"]))

	var owned: bool = MonetizationManager.is_background_theme_unlocked("misty_spring")
	_check("paid background now actually unlocks", owned,
		"bg_misty_spring granted (previously paid money and got nothing)")

# ---------------------------------------------------------------- #3 validation

## These fixtures are signed, because the loader now refuses an unsigned or
## wrongly-signed file outright rather than sanitizing it. The attacker modelled
## here is the one from audit T02, who has the salt out of the APK and can sign
## whatever they like; what these checks measure is that even a correctly signed
## payload full of wrong types and impossible numbers cannot break the game.
func _write_hostile(data: Dictionary) -> void:
	_wipe_all()
	data["version"] = SaveManager.CURRENT_VERSION
	data["checksum"] = SaveManager.signature_for_payload(data)
	var f := FileAccess.open_encrypted_with_pass(SAVE_PATH, FileAccess.WRITE, SaveManager._ENC_KEY)
	f.store_string(JSON.stringify(data))
	f.close()

func _v1_wrong_types_fall_back_to_defaults() -> void:
	_write_hostile({
		"prog": {"level": "not_a_number", "stars": "I am a string", "river_jade": 100},
		"economy": {"pearls": 250, "unlocked_themes": 12345},
		"sanctuary": {"koi_unlocked": {"not": "an array"}},
		"tile_mastery": {"dot_1": "abc"},
		"version": 2
	})
	SaveManager.load_game()

	var ok: bool = (SaveManager.prog.get("stars") is Dictionary) \
		and (SaveManager.economy.get("unlocked_themes") is Array) \
		and (SaveManager.sanctuary.get("koi_unlocked") is Array) \
		and (SaveManager.prog.get("level") is int)
	_check("wrong types are replaced by defaults", ok,
		"stars=%s themes=%s koi=%s level=%s" % [
			type_string(typeof(SaveManager.prog.get("stars"))),
			type_string(typeof(SaveManager.economy.get("unlocked_themes"))),
			type_string(typeof(SaveManager.sanctuary.get("koi_unlocked"))),
			type_string(typeof(SaveManager.prog.get("level")))])

## The exact failure from audit T05: a hostile save used to break level completion
## permanently, because record_level_clear() threw before saving anything.
func _v2_level_clear_survives_hostile_save() -> void:
	_write_hostile({
		"prog": {"level": 1, "stars": "I am a string", "river_jade": 100},
		"economy": {"pearls": 250}, "version": 2
	})
	SaveManager.load_game()
	var jade_before: int = SaveManager.get_pearls()
	SaveManager.record_level_clear(1, 500, 3)

	var stars_written: int = int(SaveManager.prog.get("stars", {}).get("1", -1))
	var jade_paid: bool = SaveManager.get_pearls() > jade_before
	_check("level clear works after a hostile save", stars_written == 3 and jade_paid,
		"stars[1]=%d recorded, pearls %d -> %d" % [stars_written, jade_before, SaveManager.get_pearls()])

func _v3_out_of_range_numbers_clamped() -> void:
	_write_hostile({
		"prog": {"level": -5, "river_jade": -100000, "best_score": -1,
			"stars": {"1": 999, "9999": 3}, "streak_shields": 500},
		"economy": {"pearls": -50000}, "version": 2
	})
	SaveManager.load_game()

	var lvl: int = int(SaveManager.prog.get("level", 0))
	var stars: Dictionary = SaveManager.prog.get("stars", {})
	var ok: bool = SaveManager.get_pearls() >= 0 \
		and lvl >= 1 and int(stars.get("1", 0)) <= 3 and not stars.has("9999")
	_check("impossible numbers are clamped", ok,
		"level=%d pearls=%d stars[1]=%d out-of-range level key dropped=%s" % [
			lvl, SaveManager.get_pearls(),
			int(stars.get("1", 0)), str(not stars.has("9999"))])

func _v4_unknown_ids_rejected() -> void:
	_write_hostile({
		"prog": {"level": 1, "river_jade": 100},
		"economy": {
			"pearls": 250,
			"unlocked_themes": ["classic_jade", "theme_does_not_exist"],
			"active_tile_theme": "theme_never_sold",
			"unlocked_background_themes": ["made_up_pond"],
			"active_background_theme": "made_up_pond"
		},
		"sanctuary": {"koi_unlocked": ["kohaku", "invisible_koi"]},
		"version": 2
	})
	SaveManager.load_game()

	var themes: Array = SaveManager.economy.get("unlocked_themes", [])
	var koi: Array = SaveManager.sanctuary.get("koi_unlocked", [])
	var ok: bool = not ("theme_does_not_exist" in themes) \
		and SaveManager.economy.get("active_tile_theme") == "classic_jade" \
		and SaveManager.economy.get("active_background_theme") == "auto" \
		and not ("invisible_koi" in koi) and ("kohaku" in koi)
	_check("unknown ids cannot be injected", ok,
		"themes=%s active=%s bg=%s koi=%s" % [
			str(themes), str(SaveManager.economy.get("active_tile_theme")),
			str(SaveManager.economy.get("active_background_theme")), str(koi)])

## JSON has no integer type, so reloads used to turn 26 into 26.0 and the drift
## compounded with every save cycle.
func _v5_int_types_stable_across_reload() -> void:
	_wipe_all()
	_fresh_profile(26, 5655)
	for i in range(3):
		SaveManager.save_game()
		SaveManager.load_game()

	var lvl: Variant = SaveManager.prog.get("level")
	var purse: Variant = SaveManager.economy.get("pearls")
	var ok: bool = lvl is int and purse is int and int(lvl) == 26 and int(purse) == 5655
	_check("whole numbers stay whole across reloads", ok,
		"after 3 save/load cycles level=%s (%s) pearls=%s (%s)" % [
			str(lvl), type_string(typeof(lvl)), str(purse), type_string(typeof(purse))])

## Every profile on the owner's and the testers' devices was written by a build
## that stamped version 2 and signed only jade / pearls / no_ads. The loader now
## refuses a file it cannot verify, so if version 2 were not still accepted on
## its own terms, shipping this would wipe all of them.
func _v6_version_2_profile_still_loads() -> void:
	_wipe_all()
	_fresh_profile(33, 400)
	# A real v2 profile held River Jade. That currency no longer exists, so this
	# is the fixture that proves an existing player's balance arrives as pearls
	# instead of being dropped by the upgrade.
	SaveManager.prog["river_jade"] = 777
	SaveManager.economy["unlocked_themes"] = ["classic_jade", "theme_obsidian_ink"]
	SaveManager.economy["entitlement_source"] = {"theme_obsidian_ink": "pearls"}
	SaveManager.sanctuary = {"clarity_level": 4, "koi_unlocked": ["kohaku", "sanke"], "decorations": ["bamboo_fountain"]}
	SaveManager.tile_mastery = {"dot_1": 42}

	# Byte-for-byte the shape the previous build wrote.
	var legacy := {
		"prog": SaveManager.prog, "sanctuary": SaveManager.sanctuary,
		"tile_mastery": SaveManager.tile_mastery, "settings": SaveManager.settings,
		"economy": SaveManager.economy, "version": 2,
		"checksum": SaveManager._compute_checksum(SaveManager.prog, SaveManager.economy)
	}
	var f := FileAccess.open_encrypted_with_pass(SAVE_PATH, FileAccess.WRITE, SaveManager._ENC_KEY)
	f.store_string(JSON.stringify(legacy))
	f.close()

	_fresh_profile(1, 100)
	SaveManager.sanctuary = {"clarity_level": 1, "koi_unlocked": ["kohaku"], "decorations": ["bamboo_fountain"]}
	SaveManager.tile_mastery = {}
	SaveManager.load_game()

	var ok: bool = int(SaveManager.prog.get("level", 0)) == 33 \
		and int(SaveManager.prog.get("river_jade", -1)) == 0 \
		and SaveManager.get_pearls() == 400 + 777 / SaveManager.JADE_PER_PEARL \
		and SaveManager.economy.get("unlocked_themes", []).has("theme_obsidian_ink") \
		and SaveManager.sanctuary.get("koi_unlocked", []).has("sanke") \
		and int(SaveManager.tile_mastery.get("dot_1", 0)) == 42
	_check("a version 2 profile survives the upgrade", ok,
		"level=%s pearls=%d themes=%s koi=%s mastery=%s" % [
			str(SaveManager.prog.get("level")), SaveManager.get_pearls(),
			str(SaveManager.economy.get("unlocked_themes")), str(SaveManager.sanctuary.get("koi_unlocked")),
			str(SaveManager.tile_mastery.get("dot_1"))])

	# And it is re-signed on the way out, so the narrow scheme is used once.
	SaveManager.save_game()
	var g := FileAccess.open_encrypted_with_pass(SAVE_PATH, FileAccess.READ, SaveManager._ENC_KEY)
	var text: String = g.get_as_text()
	g.close()
	var json := JSON.new()
	var restamped: bool = json.parse(text) == OK and int(json.data.get("version", 0)) == SaveManager.CURRENT_VERSION
	_check("and is re-signed at the current version", restamped,
		"file version on disk after one save = %s" % str(json.data.get("version") if json.data is Dictionary else "?"))
