extends Node

const SAVE_PATH := "user://nine_rivers_save.json"

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
	"last_rewarded_date": ""
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

const CURRENT_VERSION: int = 2

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

func _compute_checksum(p: Dictionary, e: Dictionary) -> String:
	var j: int = int(p.get("river_jade", 0))
	var prl: int = int(e.get("pearls", 0))
	var na: bool = bool(e.get("no_ads_purchased", false))
	return ("%d|%d|%s|%s" % [j, prl, str(na), _SALT]).sha256_text()

func save_game() -> void:
	_is_dirty = false
	_batch_timer = 0.0
	var data := {
		"prog": prog,
		"sanctuary": sanctuary,
		"tile_mastery": tile_mastery,
		"settings": settings,
		"economy": economy,
		"version": CURRENT_VERSION,
		"checksum": _compute_checksum(prog, economy)
	}
	var file := FileAccess.open_encrypted_with_pass(SAVE_PATH, FileAccess.WRITE, _ENC_KEY)
	if file:
		var json_string := JSON.stringify(data, "\t")
		file.store_string(json_string)
		file.close()

func _migrate_save(data: Dictionary, from_version: int) -> Dictionary:
	# Extensible migration chain for future versions
	if from_version < 1:
		data["version"] = 1
	data["version"] = CURRENT_VERSION
	return data

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
		
	var content := ""
	var file := FileAccess.open_encrypted_with_pass(SAVE_PATH, FileAccess.READ, _ENC_KEY)
	if file:
		content = file.get_as_text()
		file.close()
	
	var json := JSON.new()
	var err := json.parse(content)
	
	# Fallback to plain JSON for backwards compatibility or initial migration
	if err != OK or not (json.data is Dictionary):
		file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			content = file.get_as_text()
			file.close()
			err = json.parse(content)
			if err == OK and json.data is Dictionary:
				_apply_save_data(json.data)
				save_game() # Re-save in encrypted format immediately
				return
		return
		
	_apply_save_data(json.data)

func _apply_save_data(data: Dictionary) -> void:
	var file_version: int = int(data.get("version", 1))
	if file_version < CURRENT_VERSION:
		data = _migrate_save(data, file_version)
		
	var loaded_prog: Dictionary = data.get("prog", {}) if data.has("prog") and data["prog"] is Dictionary else {}
	var loaded_econ: Dictionary = data.get("economy", {}) if data.has("economy") and data["economy"] is Dictionary else {}
	
	# Anti-tampering: verify cryptographic integrity checksum if present
	if data.has("checksum"):
		var expected := _compute_checksum(loaded_prog, loaded_econ)
		if str(data["checksum"]) != expected:
			push_warning("Nine Rivers save integrity mismatch. Enforcing safe currency bounds.")
			if loaded_econ.has("pearls"):
				loaded_econ["pearls"] = mini(250, int(loaded_econ["pearls"]))
			if loaded_prog.has("river_jade"):
				loaded_prog["river_jade"] = mini(500, int(loaded_prog["river_jade"]))
			loaded_econ["no_ads_purchased"] = false
		
	if not loaded_prog.is_empty():
		prog.merge(loaded_prog, true)
	if data.has("sanctuary") and data["sanctuary"] is Dictionary:
		sanctuary.merge(data["sanctuary"], true)
	if data.has("tile_mastery") and data["tile_mastery"] is Dictionary:
		tile_mastery = data["tile_mastery"]
	if data.has("settings") and data["settings"] is Dictionary:
		settings.merge(data["settings"], true)
	if not loaded_econ.is_empty():
		economy.merge(loaded_econ, true)
		
	# Enforce required default collections
	if not sanctuary.has("koi_unlocked") or sanctuary["koi_unlocked"].is_empty():
		sanctuary["koi_unlocked"] = ["kohaku"]
	if not economy.has("unlocked_background_themes") or economy["unlocked_background_themes"].is_empty():
		economy["unlocked_background_themes"] = ["emerald_pond", "moonlit_river", "autumn_stream"]
	else:
		for free_th in ["emerald_pond", "moonlit_river", "autumn_stream"]:
			if not (free_th in economy["unlocked_background_themes"]):
				economy["unlocked_background_themes"].append(free_th)
	if not economy.has("active_background_theme"):
		economy["active_background_theme"] = "auto"

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
	save_game()

func get_jade() -> int:
	return int(prog.get("river_jade", 0))

func spend_jade(amount: int) -> bool:
	var cur: int = get_jade()
	if cur >= amount:
		prog["river_jade"] = cur - amount
		save_game()
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
	save_game()
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

