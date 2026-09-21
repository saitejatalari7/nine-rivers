extends Node

const SAVE_PATH := "user://nine_rivers_save.json"
## Previous good generation, kept so an interrupted write can never lose a profile.
const BACKUP_PATH := "user://nine_rivers_save.bak"
## Scratch file. A save is written here in full and verified before it replaces SAVE_PATH.
const TEMP_PATH := "user://nine_rivers_save.tmp"

var prog: Dictionary = {
	"level": 1,
	"best_score": 0,
	"best_stage": 0,
	"stars": {},
	"river_jade": 100,
	"daily_streak": 0,
	"last_daily_date": "",
	"streak_shields": 1,
	"tutorial_completed": false
}

var sanctuary: Dictionary = {
	"clarity_level": 1,
	"koi_unlocked": ["kohaku"],
	"decorations": ["bamboo_fountain"]
}

var tile_mastery: Dictionary = {}

var economy: Dictionary = {
	"pearls": 250,
	"no_ads_purchased": false,
	"unlocked_themes": ["classic_jade"],
	"active_tile_theme": "classic_jade",
	"unlocked_background_themes": ["emerald_pond", "moonlit_river", "autumn_stream"],
	"active_background_theme": "auto",
	"active_mat_theme": "river_felt",
	"rewarded_ads_today": 0,
	"last_rewarded_date": "",
	# How each non-consumable was obtained: product_id -> "iap" | "pearls" | "jade".
	# Anything marked "iap" is owned by Google Play, not by this file, and is
	# re-checked against Play on every launch. See MonetizationManager.
	"entitlement_source": {}
}

var settings: Dictionary = {
	"music": true,
	"sfx": true,
	"haptics": true,
	"motion": "full",
	"magnetic_assist": true,
	"color_blind_mode": "none",
	"high_contrast_borders": false
}

## 2 -> 3 is a signature-scheme change only, not a data change: version 2 signed
## three currency fields, version 3 signs the whole profile. Version 2 files are
## still accepted on their own terms and re-signed the next time they are saved,
## so existing players keep their progress.
const CURRENT_VERSION: int = 3
const NARROW_CHECKSUM_VERSION: int = 2

var _is_dirty: bool = false
var _batch_timer: float = 0.0
const BATCH_INTERVAL: float = 4.0

func _ready() -> void:
	load_game()

func _process(delta: float) -> void:
	if _is_dirty:
		_batch_timer += delta
		if _batch_timer >= BATCH_INTERVAL:
			_flush_save()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		if _is_dirty:
			_flush_save()

func request_save() -> void:
	_is_dirty = true

func _flush_save() -> void:
	_is_dirty = false
	_batch_timer = 0.0
	save_game()

const _ENC_KEY := "NR_9R_ZenJade_k892X_P0nd!"
const _SALT := "NR_ZenPond_Salt_9Rivers_2026!"

## The version 2 signature. Kept only to verify files written by older builds.
func _compute_checksum(p: Dictionary, e: Dictionary) -> String:
	var j: int = int(p.get("river_jade", 0))
	var prl: int = int(e.get("pearls", 0))
	var na: bool = bool(e.get("no_ads_purchased", false))
	return ("%d|%d|%s|%s" % [j, prl, str(na), _SALT]).sha256_text()

## A stable text rendering of a loaded value, so the same profile always hashes
## to the same digest. Dictionary keys are sorted because insertion order is an
## accident of how the file was parsed, and arrays are sorted because every
## signed list here is a set of ids whose order carries no meaning.
func _canonical(value: Variant) -> String:
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort_custom(func(a, b): return str(a) < str(b))
		var parts: PackedStringArray = PackedStringArray()
		for k in keys:
			parts.append("%s=%s" % [str(k), _canonical(value[k])])
		return "{" + ",".join(parts) + "}"
	if value is Array:
		var items: PackedStringArray = PackedStringArray()
		for item in value:
			items.append(_canonical(item))
		items.sort()
		return "[" + ",".join(items) + "]"
	if value is bool:
		return "true" if value else "false"
	if value is float:
		# JSON hands whole numbers back as floats; 26 and 26.0 must not differ.
		return str(int(value)) if is_equal_approx(value, floor(value)) else str(value)
	return str(value)

## The version 3 signature: everything a player could gain by editing the file.
##
## It is computed from the SANITIZED payload rather than the raw one, and
## save_game() signs the same way. That symmetry is the point - a value the
## loader would clamp or drop is signed in its clamped form by both sides, so an
## honest profile can never sign itself into a file it will then reject.
##
## settings are deliberately left out: nothing there is worth anything, and
## signing them would mean a preference change could invalidate a profile.
func signature_for_payload(data: Dictionary) -> String:
	var parts: Array[String] = [
		"v3",
		_canonical(_sanitize_prog(data.get("prog"))),
		_canonical(_sanitize_economy(data.get("economy"))),
		_canonical(_sanitize_sanctuary(data.get("sanctuary"))),
		_canonical(_sanitize_mastery(data.get("tile_mastery"))),
		_SALT,
	]
	return "|".join(parts).sha256_text()

## Writes the profile atomically: the new data goes to a scratch file and is read
## back to prove it is complete, and only then does it replace the live save. The
## previous generation is rotated to BACKUP_PATH rather than discarded, so a write
## interrupted at any point still leaves at least one loadable profile on disk.
## Returns false if the profile could not be persisted; the old file is untouched.
func save_game() -> bool:
	_is_dirty = false
	_batch_timer = 0.0
	var data := {
		"prog": prog,
		"sanctuary": sanctuary,
		"tile_mastery": tile_mastery,
		"settings": settings,
		"economy": economy,
		"version": CURRENT_VERSION,
	}
	data["checksum"] = signature_for_payload(data)

	# 1. Write the full payload to the scratch file.
	var file := FileAccess.open_encrypted_with_pass(TEMP_PATH, FileAccess.WRITE, _ENC_KEY)
	if file == null:
		push_error("Nine Rivers: could not open save scratch file (error %d). Profile not written." % FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	# 2. Read it back. A truncated or unflushed write fails here, before it can
	#    replace the good file.
	if _read_save_dict(TEMP_PATH).is_empty():
		push_error("Nine Rivers: save verification failed. Keeping the previous profile.")
		_remove(TEMP_PATH)
		return false

	# 3. Rotate. From here every interruption still leaves a loadable file:
	#    between 3a and 3b the backup holds the old profile, and the verified
	#    scratch file holds the new one.
	if FileAccess.file_exists(SAVE_PATH):
		_remove(BACKUP_PATH)
		if DirAccess.rename_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(BACKUP_PATH)) != OK:
			# Could not preserve the old generation; the scratch file is still
			# verified, so continue rather than lose the new progress.
			_remove(SAVE_PATH)
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(TEMP_PATH), ProjectSettings.globalize_path(SAVE_PATH)) != OK:
		push_error("Nine Rivers: could not commit the save file. Recovery copy retained.")
		return false
	return true

func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

## Reads and parses one save file. Returns an empty Dictionary if the file is
## missing, unreadable, truncated, or not a JSON object.
func _read_save_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var content := ""
	var file := FileAccess.open_encrypted_with_pass(path, FileAccess.READ, _ENC_KEY)
	if file != null:
		content = file.get_as_text()
		file.close()

	# Encrypted only. There is deliberately no plain-JSON fallback: accepting an
	# unreadable file as plaintext let anyone skip the encryption entirely by
	# handing the game an unencrypted save (audit T01). A file that will not
	# decrypt is treated as damaged, and load_game() moves on to the next copy.
	var json := JSON.new()
	if not content.is_empty() and json.parse(content) == OK and json.data is Dictionary:
		return json.data
	return {}

# ============================ LOAD VALIDATION ============================
## Everything arriving from disk is untrusted: it may be truncated, hand-edited,
## or written by a different build. Each field is coerced to its expected type and
## clamped to a sane range before it reaches the live dictionaries, so a damaged
## file degrades to defaults instead of breaking the game.
##
## This also fixes a quieter problem: JSON has no integer type, so every whole
## number returns from a reload as a float (26 -> 26.0). Coercing here keeps the
## types stable no matter how many save/load cycles a profile survives.

const MAX_LEVEL: int = 1000

const VALID_TILE_THEMES: Array[String] = [
	"classic_jade", "theme_imperial_gold", "theme_obsidian_ink", "theme_cherry_blossom"
]
const VALID_BG_THEMES: Array[String] = [
	"emerald_pond", "moonlit_river", "autumn_stream", "misty_spring", "sunset_haven"
]
const VALID_KOI: Array[String] = ["kohaku", "sanke", "showa", "ogon", "dragon_koi"]
const VALID_DECORATIONS: Array[String] = [
	"bamboo_fountain", "stone_lantern", "pink_lotus", "stepping_stones"
]
const VALID_MOTION: Array[String] = ["full", "reduced"]
const VALID_COLOR_BLIND: Array[String] = ["none", "deuteranopia", "protanopia", "tritanopia"]
const VALID_ENTITLEMENT_SOURCES: Array[String] = ["iap", "pearls", "jade"]

## A whole number, clamped. Accepts the floats that JSON hands back.
func _vint(value: Variant, fallback: int, min_v: int = -2147483648, max_v: int = 2147483647) -> int:
	if not (value is int or value is float or value is bool):
		return fallback
	var n: float = float(value)
	if is_nan(n) or is_inf(n):
		return fallback
	return clampi(int(n), min_v, max_v)

func _vbool(value: Variant, fallback: bool) -> bool:
	return bool(value) if (value is bool or value is int or value is float) else fallback

## A string restricted to a known set, so an unknown id can never be equipped.
func _vstr(value: Variant, fallback: String, allowed: Array = []) -> String:
	if not (value is String or value is StringName):
		return fallback
	var s := String(value)
	if not allowed.is_empty() and not (s in allowed):
		return fallback
	return s

## A list of known ids: unknown entries dropped, duplicates removed, `required`
## entries always present.
func _vid_list(value: Variant, allowed: Array, required: Array) -> Array:
	var out: Array = []
	for item in required:
		out.append(item)
	if value is Array:
		for item in value:
			if not (item is String or item is StringName):
				continue
			var s := String(item)
			if s in allowed and not (s in out):
				out.append(s)
	return out

func _sanitize_prog(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not (raw is Dictionary):
		return out
	var d: Dictionary = raw

	# level is a pointer to the next unplayed stage, so MAX_LEVEL + 1 means "all done".
	if d.has("level"): out["level"] = _vint(d["level"], 1, 1, MAX_LEVEL + 1)
	if d.has("best_score"): out["best_score"] = _vint(d["best_score"], 0, 0)
	if d.has("best_stage"): out["best_stage"] = _vint(d["best_stage"], 0, 0)
	if d.has("river_jade"): out["river_jade"] = _vint(d["river_jade"], 0, 0)
	if d.has("daily_streak"): out["daily_streak"] = _vint(d["daily_streak"], 0, 0)
	if d.has("streak_shields"): out["streak_shields"] = _vint(d["streak_shields"], 0, 0, 99)
	if d.has("last_daily_date"): out["last_daily_date"] = _vstr(d["last_daily_date"], "")
	if d.has("tutorial_completed"): out["tutorial_completed"] = _vbool(d["tutorial_completed"], false)

	# stars: {"<level>": 0..3}. Anything not shaped like that is discarded rather
	# than copied in, which is what used to break record_level_clear() forever.
	var stars: Dictionary = {}
	if d.get("stars") is Dictionary:
		for k in d["stars"].keys():
			var key := str(k)
			if not key.is_valid_int():
				continue
			var lvl: int = int(key)
			if lvl < 1 or lvl > MAX_LEVEL:
				continue
			stars[key] = _vint(d["stars"][k], 0, 0, 3)
	out["stars"] = stars
	return out

func _sanitize_economy(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not (raw is Dictionary):
		return out
	var d: Dictionary = raw

	if d.has("pearls"): out["pearls"] = _vint(d["pearls"], 0, 0)
	if d.has("no_ads_purchased"): out["no_ads_purchased"] = _vbool(d["no_ads_purchased"], false)
	if d.has("rewarded_ads_today"): out["rewarded_ads_today"] = _vint(d["rewarded_ads_today"], 0, 0, 99)
	if d.has("last_rewarded_date"): out["last_rewarded_date"] = _vstr(d["last_rewarded_date"], "")

	var themes: Array = _vid_list(d.get("unlocked_themes"), VALID_TILE_THEMES, ["classic_jade"])
	out["unlocked_themes"] = themes
	# Never leave an unowned or unknown tile set equipped.
	out["active_tile_theme"] = _vstr(d.get("active_tile_theme"), "classic_jade", themes)

	var bgs: Array = _vid_list(d.get("unlocked_background_themes"), VALID_BG_THEMES,
		["emerald_pond", "moonlit_river", "autumn_stream"])
	out["unlocked_background_themes"] = bgs
	var bg_allowed: Array = bgs.duplicate()
	bg_allowed.append("auto")
	out["active_background_theme"] = _vstr(d.get("active_background_theme"), "auto", bg_allowed)
	if d.has("active_mat_theme"): out["active_mat_theme"] = _vstr(d["active_mat_theme"], "river_felt")

	var sources: Dictionary = {}
	if d.get("entitlement_source") is Dictionary:
		for k in d["entitlement_source"].keys():
			var src := _vstr(d["entitlement_source"][k], "", VALID_ENTITLEMENT_SOURCES)
			if not src.is_empty():
				sources[str(k)] = src
	out["entitlement_source"] = sources
	return out

func _sanitize_sanctuary(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not (raw is Dictionary):
		return out
	var d: Dictionary = raw
	if d.has("clarity_level"): out["clarity_level"] = _vint(d["clarity_level"], 1, 1, 10)
	out["koi_unlocked"] = _vid_list(d.get("koi_unlocked"), VALID_KOI, ["kohaku"])
	out["decorations"] = _vid_list(d.get("decorations"), VALID_DECORATIONS, ["bamboo_fountain"])
	return out

func _sanitize_settings(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not (raw is Dictionary):
		return out
	var d: Dictionary = raw
	for key in ["music", "sfx", "haptics", "magnetic_assist"]:
		if d.has(key): out[key] = _vbool(d[key], true)
	if d.has("high_contrast_borders"): out["high_contrast_borders"] = _vbool(d["high_contrast_borders"], false)
	if d.has("motion"): out["motion"] = _vstr(d["motion"], "full", VALID_MOTION)
	if d.has("color_blind_mode"): out["color_blind_mode"] = _vstr(d["color_blind_mode"], "none", VALID_COLOR_BLIND)
	return out

## tile_mastery drives a permanent score multiplier, so it is bounded too.
func _sanitize_mastery(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not (raw is Dictionary):
		return out
	for k in raw.keys():
		var key := str(k)
		var parts := key.split("_")
		if parts.size() != 2 or not parts[1].is_valid_int():
			continue
		out[key] = _vint(raw[k], 0, 0, 999999)
	return out

## Each step transforms the payload from one schema to the next. 2 -> 3 changed
## only how the file is signed, so there is nothing to move; the entry is here so
## that the chain is complete and the next real migration has somewhere to go.
func _migrate_save(data: Dictionary, from_version: int) -> Dictionary:
	var v: int = maxi(1, from_version)
	while v < CURRENT_VERSION:
		match v:
			1, 2:
				pass
			_:
				push_warning("Nine Rivers: no migration step for save version %d." % v)
		v += 1
	data["version"] = CURRENT_VERSION
	return data

## Loads the profile, trying each generation in turn: the live save, then a
## verified scratch file left by a write that was interrupted after verification,
## then the previous generation. Progress is only lost if every copy is unreadable.
func load_game() -> void:
	# Ordered newest-first. TEMP_PATH only survives a crash mid-rotation, and its
	# contents were verified before that rotation began, so it outranks the backup.
	var candidates: Array[String] = [SAVE_PATH, TEMP_PATH, BACKUP_PATH]

	for i in range(candidates.size()):
		var data: Dictionary = _read_save_dict(candidates[i])
		if data.is_empty():
			continue
		if not _apply_save_data(data):
			continue
		if i > 0:
			# The live save was missing or damaged. Rewrite it from the copy that
			# loaded so the player is not one more bad launch away from losing it.
			push_warning("Nine Rivers: primary save unreadable, recovered from %s." % candidates[i])
			save_game()
		return

	if FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_PATH):
		push_error("Nine Rivers: every save copy was unreadable. Starting a fresh profile.")

## Verifies one candidate file and, only if it passes, applies it. Returns false
## if the file was refused, so load_game() can fall through to the next copy.
##
## Refusal is the whole point. The old behaviour clamped three currency fields on
## a signature mismatch and then applied the rest of the tampered payload
## regardless, which meant a forged file did not have to beat the checksum to
## hand out levels, cosmetics, streaks and koi - it only had to be present.
func _apply_save_data(data: Dictionary) -> bool:
	var file_version: int = int(data.get("version", 1))

	# A file from a build that does not exist yet cannot be read correctly, and
	# guessing at it is how a newer profile gets quietly mangled by an older
	# install. Leave it alone and try the next copy.
	if file_version > CURRENT_VERSION:
		push_warning("Nine Rivers: save version %d is newer than this build (%d). Refusing it." % [file_version, CURRENT_VERSION])
		return false

	if not data.has("checksum"):
		push_warning("Nine Rivers: save has no integrity signature. Refusing it.")
		return false

	var supplied: String = str(data["checksum"])
	var verified: bool = supplied == signature_for_payload(data)
	if not verified and file_version <= NARROW_CHECKSUM_VERSION:
		# Written by a build that only signed jade / pearls / no_ads. Accept it on
		# those terms; the next save re-signs the whole profile at version 3.
		verified = supplied == _compute_checksum(
			_sanitize_prog(data.get("prog")), _sanitize_economy(data.get("economy")))
	if not verified:
		push_warning("Nine Rivers: save integrity check failed. Refusing it.")
		return false

	if file_version < CURRENT_VERSION:
		data = _migrate_save(data, file_version)

	# Coerce and clamp before anything is merged, so the rest of this function —
	# and the whole game after it — only ever sees well-formed values.
	var loaded_prog: Dictionary = _sanitize_prog(data.get("prog"))
	var loaded_econ: Dictionary = _sanitize_economy(data.get("economy"))

	if not loaded_prog.is_empty():
		prog.merge(loaded_prog, true)
	var loaded_sanctuary: Dictionary = _sanitize_sanctuary(data.get("sanctuary"))
	if not loaded_sanctuary.is_empty():
		sanctuary.merge(loaded_sanctuary, true)
	if data.has("tile_mastery"):
		tile_mastery = _sanitize_mastery(data["tile_mastery"])
	var loaded_settings: Dictionary = _sanitize_settings(data.get("settings"))
	if not loaded_settings.is_empty():
		settings.merge(loaded_settings, true)
	if not loaded_econ.is_empty():
		economy.merge(loaded_econ, true)
	return true

func add_pearls(amount: int) -> void:
	economy["pearls"] = maxi(0, int(economy.get("pearls", 0)) + amount)
	request_save()

func get_pearls() -> int:
	return int(economy.get("pearls", 0))

func spend_pearls(amount: int) -> bool:
	var cur: int = get_pearls()
	if cur >= amount:
		economy["pearls"] = cur - amount
		request_save()
		return true
	return false

func add_jade(amount: int) -> void:
	var final_amount: int = amount
	if amount > 0:
		var SanctuaryManager = load("res://scripts/core/sanctuary_manager.gd")
		if SanctuaryManager and SanctuaryManager.is_koi_unlocked("sanke"):
			final_amount = int(ceil(float(amount) * 1.05))
	prog["river_jade"] = int(prog.get("river_jade", 0)) + final_amount
	# Batched: jade trickles in several times per board, and record_level_clear()
	# flushes at the end of every stage anyway.
	request_save()

func get_jade() -> int:
	return int(prog.get("river_jade", 0))

func spend_jade(amount: int) -> bool:
	var cur: int = get_jade()
	if cur >= amount:
		prog["river_jade"] = cur - amount
		# Batched like spend_pearls(): the caller flushes once the item it paid
		# for has also been granted, so a crash cannot take the currency without
		# the goods.
		request_save()
		return true
	return false

func record_level_clear(lvl: int, score: int, stars_earned: int) -> void:
	prog["level"] = max(int(prog.get("level", 1)), lvl + 1)
	prog["best_score"] = max(int(prog.get("best_score", 0)), score)
	if not prog.has("stars"):
		prog["stars"] = {}
	var prev_stars: int = int(prog["stars"].get(str(lvl), 0))
	prog["stars"][str(lvl)] = max(prev_stars, stars_earned)
	add_jade(50 * stars_earned)
	save_game()

func record_daily_play() -> void:
	var dt := Time.get_date_dict_from_system(true)
	var today_str := "%04d-%02d-%02d" % [dt["year"], dt["month"], dt["day"]]
	if prog.get("last_daily_date", "") == today_str:
		return
		
	var yesterday_dt := Time.get_date_dict_from_unix_time(Time.get_unix_time_from_system() - 86400)
	var yesterday_str := "%04d-%02d-%02d" % [yesterday_dt["year"], yesterday_dt["month"], yesterday_dt["day"]]
	
	if prog.get("last_daily_date", "") == yesterday_str:
		prog["daily_streak"] = int(prog.get("daily_streak", 0)) + 1
	else:
		if int(prog.get("streak_shields", 0)) > 0 and not str(prog.get("last_daily_date", "")).is_empty():
			prog["streak_shields"] = int(prog.get("streak_shields", 1)) - 1
			prog["daily_streak"] = int(prog.get("daily_streak", 0)) + 1
		else:
			prog["daily_streak"] = 1
			
	prog["last_daily_date"] = today_str
	save_game()

func record_tile_mastery(suit: String, rank: int) -> int:
	var key := "%s_%d" % [suit, rank]
	var current_count: int = int(tile_mastery.get(key, 0)) + 1
	tile_mastery[key] = current_count
	# Called once per tile cleared — up to 144 times on a single Nine Rivers
	# board. Writing the whole encrypted file each time was needless flash wear
	# and a stutter source, and it widened the window for an interrupted write.
	request_save()
	return current_count

func get_tile_mastery_level(suit: String, rank: int) -> int:
	var key := "%s_%d" % [suit, rank]
	var count: int = int(tile_mastery.get(key, 0))
	if count >= 80:
		return 3
	elif count >= 30:
		return 2
	elif count >= 10:
		return 1
	return 0

