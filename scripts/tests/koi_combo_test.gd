extends Node

## Koi Rescue (levels 10, 15, 20...): three koi pairs, the last asleep until
## half the board is cleared, rescue wins the level with three stars. And
## Quick Combo on every board.

const StagePlan = preload("res://scripts/core/stage_plan.gd")
const RiverTile = preload("res://scripts/core/river_tile.gd")

var main: Node
var board
var _fails: int = 0


func _ready() -> void:
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = true
	await get_tree().create_timer(0.5).timeout
	main.get_node("Modal").hide_modal()
	board = main.get_node("Board")

	_check("koi levels are 10, 15, 20... not 5 or 31",
		StagePlan.is_koi_level(10) and StagePlan.is_koi_level(15) and not StagePlan.is_koi_level(5) and not StagePlan.is_koi_level(31), "")

	main._start_calm_mode(31)
	await get_tree().create_timer(0.5).timeout
	_check("an ordinary level has no koi", _koi().is_empty(), "%d koi" % _koi().size())

	var checked: int = 0
	for lv in [10, 20, 30, 50, 100, 175, 300]:
		main._start_calm_mode(lv)
		await get_tree().create_timer(0.4).timeout
		var koi: Array = _koi()
		var sleepers: Array = koi.filter(func(t): return t.koi_sleep)
		var total: int = board.live_tiles.size()
		var before: int = 0
		for t in board.live_tiles:
			if sleepers.size() > 0 and t.set_id < sleepers[0].set_id:
				before += 1
		var ok: bool = koi.size() == 6 and sleepers.size() == 2 and before * 2 >= total
		_check("level %d: 3 koi pairs, the sleeping one after halfway" % lv, ok,
			"%s %d koi, sleeping pair after %d%% of the clearing order" % [StagePlan.layout_for_level(lv), koi.size(), before * 100 / maxi(1, total)])
		checked += 1

	main._start_calm_mode(30)
	await get_tree().create_timer(0.5).timeout
	var first: Array = _faces()
	main._start_calm_mode(30)
	await get_tree().create_timer(0.5).timeout
	_check("the same level deals the same koi", first == _faces(), "")

	var sleeper: RiverTile = _koi().filter(func(t): return t.koi_sleep)[0]
	var grid: Dictionary = board.get_spatial_grid(board.get_active_tiles())
	_check("the sleeping koi starts asleep", board.get_tile_blocked_reason(sleeper, grid) == "asleep", "")
	var in_legal: bool = false
	for s in board.get_legal_sets():
		if s.has(sleeper):
			in_legal = true
	_check("and is never offered as a move", not in_legal, "")

	# Play the deal's own clearing order. Sleepers must be awake by the time
	# that order reaches them, and freeing the last koi must win the level.
	var pearls0: int = SaveManager.get_pearls()
	var rescued: Array = []
	board.koi_rescued.connect(func(p, q): rescued.append(q))
	var woke: Array = []
	board.koi_woke.connect(func(): woke.append(board.cleared_fraction()))
	var by_set: Dictionary = {}
	for t in board.live_tiles:
		if not by_set.has(t.set_id):
			by_set[t.set_id] = []
		by_set[t.set_id].append(t)
	var ids: Array = by_set.keys()
	ids.sort()
	var asleep_when_reached: bool = false
	var rescue_paid: int = 0
	for sid in ids:
		if not rescued.is_empty():
			break
		var g: Array = by_set[sid]
		if g[0].is_removed:
			continue
		var gr: Dictionary = board.get_spatial_grid(board.get_active_tiles())
		for t in g:
			if board.get_tile_blocked_reason(t, gr) == "asleep":
				asleep_when_reached = true
		var p_before: int = SaveManager.get_pearls()
		var combo_paid_before: bool = board._combo_paid
		_resolve(g)
		if not rescued.is_empty():
			rescue_paid = SaveManager.get_pearls() - p_before
			if board._combo_paid and not combo_paid_before:
				rescue_paid -= board.COMBO_PEARLS
	_check("the leaf lifts at half the board", woke.size() == 1 and woke[0] >= 0.5 and woke[0] < 0.62, "woke at %s" % [woke])
	_check("so the clearing order never meets a sleeping koi", not asleep_when_reached, "")
	_check("freeing every koi rescues them", rescued.size() == 1, "events=%d" % rescued.size())
	await get_tree().create_timer(5.0).timeout
	var stars: int = int(SaveManager.prog.get("stars", {}).get("30", SaveManager.prog.get("stars", {}).get(30, 0)))
	_check("and wins the level with three stars", stars == 3, "stars=%d screen=%s" % [stars, main.get_node("Modal")._current_screen])
	_check("and the rescue itself pays 25 pearls", rescue_paid == board.KOI_RESCUE_PEARLS, "pearls +%d" % rescue_paid)

	# Quick Combo.
	main.get_node("Modal").hide_modal()
	main._start_calm_mode(33)
	await get_tree().create_timer(0.6).timeout
	var p1: int = SaveManager.get_pearls()
	var made: int = 0
	for i in 6:
		var sets: Array = board.get_legal_sets()
		if sets.is_empty():
			break
		_resolve(sets[0])
		made += 1
	_check("quick matches chain into a combo", board._combo == made and made >= 5, "combo=%d after %d" % [board._combo, made])
	_check("reaching x5 pays five pearls once", SaveManager.get_pearls() - p1 == board.COMBO_PEARLS, "pearls +%d" % (SaveManager.get_pearls() - p1))
	await get_tree().create_timer(2.8).timeout
	var sets2: Array = board.get_legal_sets()
	if not sets2.is_empty():
		_resolve(sets2[0])
	_check("a slow match starts over", board._combo == 1, "combo=%d" % board._combo)

	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _resolve(group: Array) -> void:
	var typed: Array[RiverTile] = []
	for t in group:
		typed.append(t)
	board._resolve_matched_set(typed)


func _koi() -> Array:
	return board.live_tiles.filter(func(t): return t.is_koi)


func _faces() -> Array:
	var out: Array = []
	for t in _koi():
		out.append("%s@%d,%d,%d%s" % [t.get_match_key(), t.x, t.y, t.z, "z" if t.koi_sleep else ""])
	out.sort()
	return out


func _check(name: String, ok: bool, detail: String) -> void:
	print("  %s  %-58s %s" % ["PASS" if ok else "FAIL", name, detail])
	if not ok:
		_fails += 1
