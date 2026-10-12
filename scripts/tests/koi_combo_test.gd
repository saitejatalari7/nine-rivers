extends Node

## Koi pairs and Quick Combo: the right tiles are marked, the same ones every
## time a board is dealt, the bonuses land once, and Undo cannot farm them.

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

	var lv: int = 30
	main._start_calm_mode(lv)
	await get_tree().create_timer(0.6).timeout
	var koi: Array = _koi_tiles()
	var faces: Dictionary = {}
	for t in board.get_active_tiles():
		faces[t.get_match_key()] = int(faces.get(t.get_match_key(), 0)) + 1
	var only_twice: bool = true
	for t in koi:
		if int(faces[t.get_match_key()]) != 2:
			only_twice = false
	_check("a board has three koi pairs", koi.size() == 6, "%d koi tiles of %d" % [koi.size(), board.get_active_tiles().size()])
	_check("every koi face is dealt exactly twice", only_twice, "")
	var first: Array = _koi_faces()
	main._start_calm_mode(lv)
	await get_tree().create_timer(0.6).timeout
	_check("the same stage deals the same koi", first == _koi_faces(), "%s" % [first])

	# Clear the koi pairs.
	var pearls0: int = SaveManager.get_pearls()
	var trio_events: Array = []
	board.koi_trio.connect(func(p, q): trio_events.append(p))
	var pairs: Array = _koi_pairs()
	var score0: int = GameManager.score
	for i in pairs.size():
		await get_tree().create_timer(2.8).timeout  # outside the combo window
		_resolve(pairs[i])
	await get_tree().process_frame
	_check("catching every koi pays once", trio_events.size() == 1, "events=%d" % trio_events.size())
	_check("with the bonus in the score", GameManager.score - score0 >= board.KOI_TRIO_POINTS, "score +%d" % (GameManager.score - score0))
	_check("and ten pearls", SaveManager.get_pearls() - pearls0 == board.KOI_TRIO_PEARLS, "pearls +%d" % (SaveManager.get_pearls() - pearls0))

	board.undo_last_move()
	await get_tree().create_timer(0.3).timeout
	_resolve(pairs[pairs.size() - 1])
	await get_tree().process_frame
	_check("undo and redo does not pay again", trio_events.size() == 1 and SaveManager.get_pearls() - pearls0 == board.KOI_TRIO_PEARLS, "events=%d" % trio_events.size())

	# Quick Combo.
	main._start_calm_mode(lv + 3)
	await get_tree().create_timer(0.6).timeout
	var p1: int = SaveManager.get_pearls()
	var s_before: int = GameManager.score
	var made: int = 0
	for i in 6:
		var sets: Array = board.get_legal_sets()
		if sets.is_empty():
			break
		_resolve(_plain(sets))
		made += 1
	await get_tree().process_frame
	_check("quick matches chain into a combo", board._combo == made and made >= 5, "combo=%d after %d matches" % [board._combo, made])
	_check("reaching x5 pays five pearls once", SaveManager.get_pearls() - p1 == board.COMBO_PEARLS, "pearls +%d" % (SaveManager.get_pearls() - p1))
	await get_tree().create_timer(2.8).timeout
	var sets2: Array = board.get_legal_sets()
	if not sets2.is_empty():
		_resolve(_plain(sets2))
	_check("a slow match starts over", board._combo == 1, "combo=%d" % board._combo)

	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _plain(sets: Array) -> Array:
	for s in sets:
		var ok: bool = true
		for t in s:
			if t.is_koi:
				ok = false
		if ok:
			return s
	return sets[0]


func _resolve(group: Array) -> void:
	var typed: Array[RiverTile] = []
	for t in group:
		typed.append(t)
	board._resolve_matched_set(typed)


func _koi_tiles() -> Array:
	var out: Array = []
	for t in board.get_active_tiles():
		if t.is_koi:
			out.append(t)
	return out


func _koi_faces() -> Array:
	var out: Array = []
	for t in _koi_tiles():
		out.append("%s@%d,%d,%d" % [t.get_match_key(), t.x, t.y, t.z])
	out.sort()
	return out


func _koi_pairs() -> Array:
	var by: Dictionary = {}
	for t in _koi_tiles():
		if not by.has(t.set_id):
			by[t.set_id] = []
		by[t.set_id].append(t)
	return by.values()


func _check(name: String, ok: bool, detail: String) -> void:
	print("  %s  %-44s %s" % ["PASS" if ok else "FAIL", name, detail])
	if not ok:
		_fails += 1
