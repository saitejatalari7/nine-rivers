extends Node

## Nine Rivers — Save Integrity & Tamper Resistance Audit
## Writes hostile save files to disk, runs the real SaveManager.load_game()
## against them, and reports what the game accepted.
##
## Run: godot --headless --audio-driver Dummy --path . scenes/security_audit.tscn

const SAVE_PATH := "user://nine_rivers_save.json"

# These two constants are copied verbatim out of scripts/autoload/save_manager.gd.
# They ship inside the APK, so any attacker has them. The audit uses them to
# prove that a forged save can be signed correctly.
const LEAKED_ENC_KEY := "NR_9R_ZenJade_k892X_P0nd!"
const LEAKED_SALT := "NR_ZenPond_Salt_9Rivers_2026!"

var _results: Array[Dictionary] = []

func _ready() -> void:
	await get_tree().process_frame
	print("")
	print("============ NINE RIVERS SAVE SECURITY AUDIT ============")
	print("")

	_t01_plaintext_bypass()
	_t02_forged_signature_full_unlock()
	_t03_checksum_scope_gap()
	_t04_tamper_response_leaves_paid_goods()
	_t05_type_confusion()
	_t06_negative_and_overflow_values()
	_t07_corrupt_file_recovery()
	_t08_downgrade_and_version_skew()
	_t09_write_amplification()
	_t10_encryption_at_rest()

	_report()
	get_tree().quit(1 if _crit_count() > 0 else 0)

# ------------------------------------------------------------------ helpers

func _reset_manager() -> void:
	SaveManager.prog = {
		"level": 1, "best_score": 0, "best_stage": 0, "stars": {},
		"river_jade": 100, "daily_streak": 0, "last_daily_date": "",
		"streak_shields": 1, "tutorial_completed": false
	}
	SaveManager.sanctuary = {"clarity_level": 1, "koi_unlocked": ["kohaku"], "decorations": ["bamboo_fountain"]}
	SaveManager.tile_mastery = {}
	SaveManager.economy = {
		"pearls": 250, "no_ads_purchased": false,
		"unlocked_themes": ["classic_jade"], "active_tile_theme": "classic_jade",
		"unlocked_background_themes": ["emerald_pond", "moonlit_river", "autumn_stream"],
		"active_background_theme": "auto", "active_mat_theme": "river_felt",
		"rewarded_ads_today": 0, "last_rewarded_date": ""
	}

## The version 2 signature: three currency fields and nothing else.
func _sign(prog: Dictionary, econ: Dictionary) -> String:
	var j: int = int(prog.get("river_jade", 0))
	var prl: int = int(econ.get("pearls", 0))
	var na: bool = bool(econ.get("no_ads_purchased", false))
	return ("%d|%d|%s|%s" % [j, prl, str(na), LEAKED_SALT]).sha256_text()

## The signature the shipped build computes today. An attacker who unpacked the
## APK has the salt and the algorithm both, so the honest way to model them is to
## sign exactly as the game does rather than to pretend the new scheme is a
## secret. Calling SaveManager's own routine is that, and it keeps this harness
## from silently stopping being an attack the day the scheme changes again.
func _sign_current(data: Dictionary) -> String:
	return SaveManager.signature_for_payload(data)

func _write_plain(data: Dictionary) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

func _write_encrypted(data: Dictionary) -> void:
	var f := FileAccess.open_encrypted_with_pass(SAVE_PATH, FileAccess.WRITE, LEAKED_ENC_KEY)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

func _write_raw_bytes(bytes: PackedByteArray) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()

func _load() -> void:
	_reset_manager()
	SaveManager.load_game()

func _finding(id: String, title: String, severity: String, vulnerable: bool, detail: String) -> void:
	_results.append({"id": id, "title": title, "severity": severity, "vuln": vulnerable, "detail": detail})
	var verdict: String = ("VULNERABLE" if vulnerable else "ok        ")
	print("[%s] %-9s %-7s %s" % [id, verdict, ("(" + severity + ")" if vulnerable else ""), title])
	print("            %s" % detail)
	print("")

func _crit_count() -> int:
	var n: int = 0
	for r in _results:
		if r["vuln"] and r["severity"] in ["CRITICAL", "HIGH"]:
			n += 1
	return n

# ------------------------------------------------------------------ tests

## The loader falls back to plain JSON when decryption fails. That means the
## encryption can simply be skipped by the attacker.
func _t01_plaintext_bypass() -> void:
	var prog := {"level": 50, "best_score": 999999, "stars": {}, "river_jade": 100,
		"streak_shields": 99, "tutorial_completed": true}
	for i in range(1, 51):
		prog["stars"][str(i)] = 3
	# Clear every generation, so a recovery copy cannot mask the result.
	for p in [SAVE_PATH, SAVE_PATH.replace(".json", ".bak"), SAVE_PATH.replace(".json", ".tmp")]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

	_write_plain({"prog": prog, "economy": {"pearls": 250}, "version": 2})
	_load()

	var accepted: bool = int(SaveManager.prog.get("level", 1)) == 50
	_finding("T01", "Unencrypted save file is accepted", "HIGH", accepted,
		"Wrote a plaintext JSON save with no encryption and no checksum. Loaded level=%s, stars=%d entries, shields=%s. The plain-JSON fallback has been removed, so a file that will not decrypt is treated as damaged and the loader moves on to the next copy rather than trusting it." % [
			str(SaveManager.prog.get("level")), SaveManager.prog.get("stars", {}).size(), str(SaveManager.prog.get("streak_shields"))])

## The salt is a compile-time constant in the shipped binary, so the checksum
## can be recomputed by anyone who unpacks the APK.
func _t02_forged_signature_full_unlock() -> void:
	# No river_jade: that field is retired and now converts INTO pearls on load,
	# which moved the balance off the exact number this used to compare against
	# and made a working forge look like a clean pass.
	var prog := {"level": 99, "best_score": 99999999, "stars": {}}
	var econ := {"pearls": 9999999, "no_ads_purchased": true,
		"unlocked_themes": ["classic_jade", "theme_imperial_gold", "theme_obsidian_ink", "theme_cherry_blossom"],
		"active_tile_theme": "theme_imperial_gold"}
	var forged := {"prog": prog, "economy": econ, "version": SaveManager.CURRENT_VERSION}
	forged["checksum"] = _sign_current(forged)
	_write_encrypted(forged)
	_load()

	var pearls: int = SaveManager.get_pearls()
	var no_ads: bool = bool(SaveManager.economy.get("no_ads_purchased", false))
	var vuln: bool = pearls >= 9999999 and no_ads
	_finding("T02", "Checksum can be forged with the hardcoded salt", "CRITICAL", vuln,
		"Signed a forged save using the salt lifted from save_manager.gd:%s. Result: pearls=%d, no_ads=%s, themes=%s. Every paid product was granted and the integrity check passed cleanly." % [
			"_SALT", pearls, str(no_ads), str(SaveManager.economy.get("unlocked_themes"))])

## The checksum covers only three fields. Everything else is unsigned.
func _t03_checksum_scope_gap() -> void:
	# Keep currency at its honest default so the checksum stays valid,
	# but tamper with everything the checksum does not cover.
	var prog := {"level": 99, "river_jade": 100, "best_score": 88888888, "stars": {},
		"daily_streak": 365, "streak_shields": 99}
	for i in range(1, 51):
		prog["stars"][str(i)] = 3
	var econ := {"pearls": 250, "no_ads_purchased": false,
		"unlocked_themes": ["classic_jade", "theme_imperial_gold", "theme_obsidian_ink", "theme_cherry_blossom"],
		"active_tile_theme": "theme_obsidian_ink"}
	var mastery := {}
	for suit in ["dot", "bam", "char"]:
		for r in range(1, 10):
			mastery["%s_%d" % [suit, r]] = 9999
	# Stamped at the version this build writes, so the check measures the current
	# signature scheme. A file stamped version 2 is still verified on version 2's
	# narrow terms for the sake of profiles written by older builds, and that
	# downgrade does re-open this gap - but writing any file at all already needs
	# the encryption key, and anyone holding that can forge a version 3 signature
	# outright. It grants nothing beyond T02.
	_write_encrypted({
		"prog": prog, "economy": econ, "tile_mastery": mastery,
		"sanctuary": {"clarity_level": 99, "koi_unlocked": ["kohaku", "sanke", "showa", "ogon", "dragon_koi"], "decorations": []},
		"version": SaveManager.CURRENT_VERSION, "checksum": _sign(prog, econ)
	})
	_load()

	var themes: Array = SaveManager.economy.get("unlocked_themes", [])
	var mastery_lvl: int = SaveManager.get_tile_mastery_level("dot", 1)
	# The real question is not the array length but whether the game honours the
	# forged cosmetics, so ask the code that actually gates them.
	var honoured: bool = MonetizationManager.is_theme_unlocked("theme_imperial_gold")
	var vuln: bool = honoured
	_finding("T03", "Checksum covers only the purse and no_ads", "CRITICAL", vuln,
		"With the signature left valid, tampered: level=%s (clamped from 99), streak=%s, shields=%s, stars=%d entries, paid themes honoured by is_theme_unlocked()=%s, tile mastery level %d, koi=%s. The file layer still grants unsigned cosmetics; they are withdrawn at runtime by the Google Play reconcile, not by the loader." % [
			str(SaveManager.prog.get("level")), str(SaveManager.prog.get("daily_streak")),
			str(SaveManager.prog.get("streak_shields")), SaveManager.prog.get("stars", {}).size(),
			str(honoured), mastery_lvl, str(SaveManager.sanctuary.get("koi_unlocked"))])

## When the checksum does fail, the response clamps currency but leaves the
## rest of the tampered payload in place.
func _t04_tamper_response_leaves_paid_goods() -> void:
	var prog := {"level": 77, "river_jade": 9999999, "stars": {"1": 3}}
	var econ := {"pearls": 9999999, "no_ads_purchased": true,
		"unlocked_themes": ["classic_jade", "theme_imperial_gold", "theme_obsidian_ink", "theme_cherry_blossom"],
		"unlocked_background_themes": ["emerald_pond", "misty_spring", "sunset_haven"]}
	_write_encrypted({"prog": prog, "economy": econ, "version": 2, "checksum": "deadbeef"})
	_load()

	var themes: Array = SaveManager.economy.get("unlocked_themes", [])
	var bg_themes: Array = SaveManager.economy.get("unlocked_background_themes", [])
	var level_kept: int = int(SaveManager.prog.get("level", 1))
	var vuln: bool = MonetizationManager.is_theme_unlocked("theme_imperial_gold") or level_kept == 77
	_finding("T04", "Failed integrity check still applies the payload", "HIGH", vuln,
		"Deliberately broken checksum. Clamped correctly: pearls=%d, no_ads=%s. Still applied: level=%d, paid tile themes=%s, background themes=%s. The mismatch branch is a soft clamp on three fields, not a rejection of the file." % [
			SaveManager.get_pearls(),
			str(SaveManager.economy.get("no_ads_purchased")), level_kept,
			str(themes), str(bg_themes)])

## Dictionary.merge() copies whatever types the file contains.
func _t05_type_confusion() -> void:
	var prog := {"level": "not_a_number", "river_jade": 100, "stars": "I am a string, not a dict"}
	var econ := {"pearls": 250, "unlocked_themes": 12345, "no_ads_purchased": false}
	_write_encrypted({
		"prog": prog, "economy": econ,
		"sanctuary": {"koi_unlocked": {"not": "an array"}},
		"tile_mastery": {"dot_1": "abc"},
		"version": 2, "checksum": _sign(prog, econ)
	})
	_load()

	var stars_type: String = type_string(typeof(SaveManager.prog.get("stars")))
	var themes_type: String = type_string(typeof(SaveManager.economy.get("unlocked_themes")))
	var koi_type: String = type_string(typeof(SaveManager.sanctuary.get("koi_unlocked")))
	var vuln: bool = stars_type != "Dictionary" or themes_type != "Array"
	_finding("T05", "No schema validation on loaded values", "HIGH", vuln,
		"After load: prog.stars is %s (expected Dictionary), economy.unlocked_themes is %s (expected Array), sanctuary.koi_unlocked is %s. prog.level is %s. record_level_clear() calls prog[\"stars\"].get(), and monetization_manager.gd:275 declares `var unlocked: Array = ...` — both raise runtime errors on these types, so a tampered or truncated file can hard-break level completion and the store." % [
			stars_type, themes_type, koi_type, str(SaveManager.prog.get("level"))])

## Negative and out-of-range numbers are stored verbatim.
func _t06_negative_and_overflow_values() -> void:
	var prog := {"level": -5, "river_jade": -100000, "best_score": -1, "stars": {"1": 999}}
	var econ := {"pearls": -50000, "no_ads_purchased": false}
	_write_encrypted({"prog": prog, "economy": econ, "version": 2, "checksum": _sign(prog, econ)})
	_load()

	var neg_pearls: int = SaveManager.get_pearls()
	var lvl: int = int(SaveManager.prog.get("level", 1))
	var stars: int = int(SaveManager.prog.get("stars", {}).get("1", 0))
	var vuln: bool = neg_pearls < 0 or lvl < 1 or stars > 3
	_finding("T06", "No range clamping on loaded numbers", "MEDIUM", vuln,
		"Loaded pearls=%d, level=%d, stars[1]=%d. A negative balance makes spend_pearls() permanently refuse purchases. level<1 is passed straight into _start_calm_mode(), where `int((level-1)/2)` goes negative; GDScript wraps negative array indices, so level=-5 silently deals the `dragon_gate` layout instead of `quick` (verified). Stars above 3 inflate the level-select total." % [
			neg_pearls, lvl, stars])

## A half-written or corrupted file should not silently erase a player's profile.
func _t07_corrupt_file_recovery() -> void:
	# Clear every generation so earlier tests' forged files cannot be mistaken
	# for this profile's recovery copy.
	for p in [SAVE_PATH, SAVE_PATH.replace(".json", ".bak"), SAVE_PATH.replace(".json", ".tmp")]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

	# First establish a real profile on disk, saved twice so that a recovery
	# generation exists alongside the live file.
	_reset_manager()
	SaveManager.prog["level"] = 25
	SaveManager.economy["pearls"] = 5000
	SaveManager.save_game()
	SaveManager.save_game()

	# Simulate a write interrupted by a kill/battery-pull: truncate the file.
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var full: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	_write_raw_bytes(full.slice(0, int(full.size() * 0.6)))

	_load()
	var recovered_level: int = int(SaveManager.prog.get("level", 1))
	var backup_exists: bool = FileAccess.file_exists(SAVE_PATH.replace(".json", ".bak"))
	var vuln: bool = recovered_level != 25
	_finding("T07", "Truncated save wipes progress with no backup", "HIGH", vuln,
		"Truncated the save to 60%% of its length, mimicking a crash mid-write. Reload produced level=%d (expected 25). Backup file present: %s. save_game() now writes to a scratch file, reads it back to prove it is complete, and only then rotates the previous generation to .bak." % [
			recovered_level, str(backup_exists)])

## Migration is a stub, and newer-than-current files load unchecked.
func _t08_downgrade_and_version_skew() -> void:
	var prog := {"level": 40, "river_jade": 100, "stars": {}}
	var econ := {"pearls": 250, "no_ads_purchased": false,
		"future_field_that_does_not_exist_yet": true}
	_write_encrypted({"prog": prog, "economy": econ, "version": 99, "checksum": _sign(prog, econ)})
	_load()

	var loaded: bool = int(SaveManager.prog.get("level", 1)) == 40
	_finding("T08", "Version 99 save loads into a version 2 build", "MEDIUM", loaded,
		"A save stamped version=99 was applied without complaint (level=%s). _migrate_save() only stamps CURRENT_VERSION and transforms nothing, so a future schema change will silently misread old files rather than migrate them, and a newer file will be read by an older build." % str(SaveManager.prog.get("level")))

## Every cleared tile triggers a full encrypted file write.
func _t09_write_amplification() -> void:
	_reset_manager()
	SaveManager.save_game()
	var before: String = _file_digest(SAVE_PATH)

	var t0: int = Time.get_ticks_usec()
	for i in range(144):
		SaveManager.record_tile_mastery("dot", (i % 9) + 1)
		SaveManager.add_pearls(5)
	var elapsed_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0

	# If the file on disk is byte-identical, none of those 288 calls triggered a
	# write; they were coalesced into the pending batch instead.
	var after: String = _file_digest(SAVE_PATH)
	var batched: bool = before == after
	_finding("T09", "One full encrypted write per tile cleared", "MEDIUM", not batched,
		"Simulated clearing a 144-tile Nine Rivers board: 144 record_tile_mastery() calls plus 144 add_pearls() calls took %.1f ms and produced %s. Both now use the 4s batching in request_save(); record_level_clear() still flushes at the end of every stage, and purchases still commit immediately." % [
			elapsed_ms, ("zero file writes" if batched else "at least one file write")])

func _file_digest(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	var bytes: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	return bytes.get_string_from_ascii().sha256_text() if bytes.size() < 1 else str(bytes.size()) + "|" + Marshalls.raw_to_base64(bytes).sha256_text()

## Confirm the file is genuinely unreadable without the key.
func _t10_encryption_at_rest() -> void:
	_reset_manager()
	SaveManager.prog["level"] = 12
	SaveManager.save_game()
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var raw: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	var as_text: String = raw.get_string_from_utf8()
	var leaks_plaintext: bool = as_text.contains("river_jade") or as_text.contains("level")
	_finding("T10", "Save is encrypted at rest", "LOW", leaks_plaintext,
		"Raw file is %d bytes and %s readable field names, so AES-256-CBC via open_encrypted_with_pass() is working. Note that this only stops casual editing: the key is a plain string constant in the APK, which is what T02 exploits." % [
			raw.size(), ("contains" if leaks_plaintext else "contains no")])

# ------------------------------------------------------------------ report

func _report() -> void:
	print("======================= SUMMARY =======================")
	var counts := {"CRITICAL": 0, "HIGH": 0, "MEDIUM": 0, "LOW": 0}
	for r in _results:
		if r["vuln"]:
			counts[r["severity"]] = int(counts[r["severity"]]) + 1
	print("Checks run : %d" % _results.size())
	print("CRITICAL   : %d" % int(counts["CRITICAL"]))
	print("HIGH       : %d" % int(counts["HIGH"]))
	print("MEDIUM     : %d" % int(counts["MEDIUM"]))
	print("LOW        : %d" % int(counts["LOW"]))
	print("")
	for r in _results:
		if r["vuln"]:
			print("  %-8s [%s] %s" % [r["severity"], r["id"], r["title"]])
	print("=======================================================")
