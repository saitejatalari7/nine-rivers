extends Node

## Nine Rivers — Autoplay Test Bot
## Boots the real main.tscn, plays Calm Journey levels 1..TARGET_LEVEL through the
## genuine tile-click path, and verifies that SaveManager records progression
## correctly (level pointer, stars, pearls, mastery) and that it survives a reload.
##
## Run: godot --headless --audio-driver Dummy --path . scenes/bot_runner.tscn

const BoardGenerator = preload("res://scripts/core/board_generator.gd")

const TARGET_LEVEL: int = 25
## Override with: godot ... scenes/bot_runner.tscn -- --seed=12345
var BASE_SEED: int = 700001
const MAX_CLICKS_PER_LEVEL: int = 4000
const MAX_RESTARTS_PER_LEVEL: int = 6

var main: Node2D
var board
var modal

var _cleared_flag: bool = false
var _failures: Array[String] = []
var _level_reports: Array[Dictionary] = []

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			BASE_SEED = int(arg.substr(7))
	print("bot seed: %d" % BASE_SEED)
	await get_tree().process_frame
	await _boot()
	await _run()
	_report()
	get_tree().quit(1 if not _failures.is_empty() else 0)

# ---------------------------------------------------------------- boot

func _boot() -> void:
	# Start from a pristine profile so level progression is measured from zero.
	_wipe_save()

	var packed: PackedScene = load("res://scenes/main.tscn")
	main = packed.instantiate()
	add_child(main)
	await get_tree().process_frame

	board = main.get_node("Board")
	modal = main.get_node("Modal")

	# Skip the boot splash and the first-run tutorial overlay.
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = true
	board.visible = true
	await get_tree().process_frame

	board.board_cleared.connect(func(): _cleared_flag = true)

func _wipe_save() -> void:
	var p := "user://nine_rivers_save.json"
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	SaveManager.prog = {
		"level": 1, "best_score": 0, "best_stage": 0, "stars": {},
		"river_jade": 0, "daily_streak": 0, "last_daily_date": "",
		"streak_shields": 1, "tutorial_completed": true
	}
	SaveManager.tile_mastery = {}
	SaveManager.economy["pearls"] = 250
	SaveManager.save_game()

# ---------------------------------------------------------------- main loop

func _run() -> void:
	print("")
	print("==================== NINE RIVERS AUTOPLAY BOT ====================")
	print("Target: clear Calm Journey levels 1..%d" % TARGET_LEVEL)
	print("")

	for lvl in range(1, TARGET_LEVEL + 1):
		var jade_before: int = SaveManager.get_pearls()
		var report: Dictionary = await _play_level(lvl, jade_before)
		_level_reports.append(report)
		_verify_level_save(lvl, report)

	await _verify_persistence()

func _play_level(lvl: int, jade_before: int) -> Dictionary:
	var restarts: int = 0
	var shuffles_used: int = 0
	var clicks: int = 0
	var tiles_total: int = 0

	while restarts <= MAX_RESTARTS_PER_LEVEL:
		_cleared_flag = false
		# Varies per restart so a retry gets a different board, but is the same
		# board on every run of the same BASE_SEED.
		BoardGenerator.forced_seed = BASE_SEED + lvl * 1000 + restarts
		main._start_calm_mode(lvl)
		await get_tree().process_frame
		tiles_total = board.live_tiles.size()

		var local_clicks: int = 0
		var local_shuffles: int = 0
		var ok := true

		while not _cleared_flag:
			if local_clicks > MAX_CLICKS_PER_LEVEL:
				_fail("L%d: exceeded %d clicks without clearing (possible infinite loop)" % [lvl, MAX_CLICKS_PER_LEVEL])
				ok = false
				break

			var sets: Array = board.get_legal_sets()
			if sets.is_empty():
				# Dead end reached by greedy play. Shuffle and retry.
				if local_shuffles < 3 and board.shuffle_remaining_tiles():
					local_shuffles += 1
					await get_tree().process_frame
					continue
				ok = false
				break

			var chosen: Array = _choose_set(sets)
			local_clicks += await _play_set(chosen)
			await get_tree().process_frame

		clicks += local_clicks
		shuffles_used += local_shuffles

		if ok and _cleared_flag:
			await get_tree().process_frame
			return _mk_report(lvl, tiles_total, clicks, restarts, shuffles_used, jade_before, true)
		restarts += 1

	_fail("L%d: could not be cleared in %d attempts" % [lvl, MAX_RESTARTS_PER_LEVEL + 1])
	return _mk_report(lvl, tiles_total, clicks, restarts, shuffles_used, jade_before, false)

func _mk_report(lvl: int, tiles: int, clicks: int, restarts: int, shuffles: int, jade_before: int, cleared: bool) -> Dictionary:
	return {
		"level": lvl, "tiles": tiles, "clicks": clicks,
		"restarts": restarts, "shuffles": shuffles,
		"score": GameManager.score, "best_flow": GameManager.best_flow,
		"misplays": GameManager.misplays, "props_used": GameManager.props_used,
		"jade_before": jade_before, "cleared": cleared
	}

## Clicks every tile of a set through BoardController's real input handler.
func _play_set(group: Array) -> int:
	var n: int = 0
	for t in group:
		var view = board.tile_views.get(t)
		if not is_instance_valid(view):
			break
		# Winter Frost: the first tap only shatters the ice, so tap twice.
		if t.is_removed or not is_instance_valid(view):
			break
		board._on_tile_clicked(view)
		n += 1
	return n

## Greedy heuristic: prefer high stacks (frees the board faster), avoid burning
## wild tiles early, and favour staying in-suit to build Flow.
func _choose_set(sets: Array) -> Array:
	var best: Array = sets[0]
	var best_score: float = -1000000.0
	for s in sets:
		var sc: float = 0.0
		for t in s:
			sc += float(t.z) * 10.0
			if t.is_wild():
				sc -= 25.0
		if s.size() >= 3:
			sc += 8.0
		if not s.is_empty() and s[0].suit == GameManager.flow_suit:
			sc += 5.0
		if sc > best_score:
			best_score = sc
			best = s
	return best

# ---------------------------------------------------------------- assertions

func _verify_level_save(lvl: int, r: Dictionary) -> void:
	if not r.get("cleared", false):
		return
	var expected_stars: int = 1
	if int(r["misplays"]) <= 2: expected_stars += 1
	if int(r["props_used"]) == 0: expected_stars += 1

	var saved_level: int = int(SaveManager.prog.get("level", 0))
	if saved_level != lvl + 1:
		_fail("L%d: prog.level is %d, expected %d" % [lvl, saved_level, lvl + 1])

	var stars_map: Dictionary = SaveManager.prog.get("stars", {})
	if not stars_map.has(str(lvl)):
		_fail("L%d: no star entry written to prog.stars" % lvl)
	elif int(stars_map[str(lvl)]) != expected_stars:
		_fail("L%d: stars recorded %d, expected %d" % [lvl, int(stars_map[str(lvl)]), expected_stars])

	if int(SaveManager.prog.get("best_score", 0)) < int(r["score"]):
		_fail("L%d: best_score %d is below this run's score %d" % [lvl, int(SaveManager.prog.get("best_score", 0)), int(r["score"])])

	var pearl_gain: int = SaveManager.get_pearls() - int(r["jade_before"])
	if pearl_gain < SaveManager.PEARLS_PER_STAR * expected_stars:
		_fail("L%d: pearls gained %d is below the %d-star reward" % [lvl, pearl_gain, expected_stars])

	var stars_label: String = "*".repeat(expected_stars) + "-".repeat(3 - expected_stars)
	print("L%-3d %-14s tiles=%-4d taps=%-4d restarts=%d shuf=%d  [%s]  score=%-8d flow=x%-2d misplays=%-2d  save.level=%d" % [
		lvl, BoardGenerator.LAYOUT_NAMES.get(GameManager.current_layout_name, "?"),
		int(r["tiles"]), int(r["clicks"]), int(r["restarts"]), int(r["shuffles"]), stars_label,
		int(r["score"]), int(r["best_flow"]), int(r["misplays"]), saved_level
	])

## Force a flush, blow away in-memory state, reload from disk, and diff.
func _verify_persistence() -> void:
	print("")
	print("---- Persistence check (flush -> wipe RAM -> reload from disk) ----")
	SaveManager.save_game()

	var expect_prog: Dictionary = SaveManager.prog.duplicate(true)
	var expect_mastery: Dictionary = SaveManager.tile_mastery.duplicate(true)
	var expect_econ: Dictionary = SaveManager.economy.duplicate(true)

	SaveManager.prog = {}
	SaveManager.tile_mastery = {}
	SaveManager.economy = {}
	SaveManager.load_game()
	await get_tree().process_frame

	for k in expect_prog.keys():
		if k == "stars":
			continue
		if str(SaveManager.prog.get(k)) != str(expect_prog[k]):
			_fail("persistence: prog.%s reloaded as %s, expected %s" % [k, str(SaveManager.prog.get(k)), str(expect_prog[k])])

	var reloaded_stars: Dictionary = SaveManager.prog.get("stars", {})
	var expect_stars: Dictionary = expect_prog.get("stars", {})
	for lvl in range(1, TARGET_LEVEL + 1):
		var key: String = str(lvl)
		if int(reloaded_stars.get(key, -1)) != int(expect_stars.get(key, -2)):
			_fail("persistence: stars[%s] reloaded as %s, expected %s" % [key, str(reloaded_stars.get(key)), str(expect_stars.get(key))])

	if SaveManager.tile_mastery.size() != expect_mastery.size():
		_fail("persistence: tile_mastery has %d keys after reload, expected %d" % [SaveManager.tile_mastery.size(), expect_mastery.size()])
	if int(SaveManager.economy.get("pearls", -1)) != int(expect_econ.get("pearls", -2)):
		_fail("persistence: pearls reloaded as %s, expected %s" % [str(SaveManager.economy.get("pearls")), str(expect_econ.get("pearls"))])

	print("reloaded level=%s  best_score=%s  stars=%d entries  mastery=%d keys  pearls=%s" % [
		str(SaveManager.prog.get("level")),
		str(SaveManager.prog.get("best_score")), reloaded_stars.size(),
		SaveManager.tile_mastery.size(), str(SaveManager.economy.get("pearls"))
	])

func _fail(msg: String) -> void:
	_failures.append(msg)
	printerr("FAIL: " + msg)

func _report() -> void:
	print("")
	print("==================== BOT SUMMARY ====================")
	var cleared: int = 0
	var total_clicks: int = 0
	var total_restarts: int = 0
	var total_shuffles: int = 0
	for r in _level_reports:
		if r.get("cleared", false): cleared += 1
		total_clicks += int(r.get("clicks", 0))
		total_restarts += int(r.get("restarts", 0))
		total_shuffles += int(r.get("shuffles", 0))
	print("Levels cleared      : %d / %d" % [cleared, TARGET_LEVEL])
	print("Total tile taps     : %d" % total_clicks)
	print("Dead-end restarts   : %d" % total_restarts)
	print("Dead-end shuffles   : %d" % total_shuffles)
	print("Final saved level   : %s" % str(SaveManager.prog.get("level")))
	print("Final Spirit Pearls : %s" % str(SaveManager.get_pearls()))
	print("Assertion failures  : %d" % _failures.size())
	if not _failures.is_empty():
		print("Reproduce with     : --fixed-fps 60 ... -- --seed=%d" % BASE_SEED)
	for f in _failures:
		print("   - " + f)
	print("=====================================================")
