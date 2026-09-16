extends Node

## Proves boards can actually be cleared.
##
## The old solver test only compared tile counts, so it would have passed a
## board with no legal move at all. With 1000 generated levels that has to be
## checked rather than assumed.
##
## Three independent checks per board:
##
##   1. PEEL     - deal_board builds the board by reverse-peeling free slots.
##                 While that succeeds the board is solvable by construction.
##                 After 150 failed attempts it falls back to a plain shuffle,
##                 which carries no such guarantee, so the fallback is a
##                 failure here.
##   2. REPLAY   - the peel order is itself a clearing sequence. Replaying it
##                 against the DEALT tiles proves the type assignment did not
##                 break the guarantee. This is the definitive check.
##   3. SEARCH   - an independent greedy solver with restarts, which knows
##                 nothing about the peel order. Finding a clear is a proof;
##                 failing to is NOT a proof of unsolvability, and is reported
##                 as "not proven", never as "unsolvable".
##
## The move rules in _moves() are a second implementation of the ones in
## BoardController.get_legal_sets, so _cross_check() asserts the two agree on
## real boards before any verdict is trusted.

const BoardGenerator = preload("res://scripts/core/board_generator.gd")
const LayoutData = preload("res://scripts/core/layout_data.gd")
const RiverTile = preload("res://scripts/core/river_tile.gd")

const SEEDS_PER_LAYOUT: int = 12
const GREEDY_RESTARTS: int = 60

var _x: PackedInt32Array
var _y: PackedInt32Array
var _z: PackedInt32Array
var _size: PackedInt32Array
var _key: PackedStringArray
var _wild: Array[bool]
var _alive: Array[bool]
var _n: int = 0
var _top_z: int = 0


func _ready() -> void:
	var layouts: Array = BoardGenerator.LADDER.duplicate()
	for extra in LayoutData.LAYOUTS.keys():
		if not layouts.has(extra):
			layouts.append(extra)

	if not _cross_check():
		print("  FAIL  move rules disagree with BoardController - no verdict trusted")
		print("Failures: 1")
		get_tree().quit(1)
		return
	print("  PASS  move rules agree with BoardController.get_legal_sets")
	print("")
	print("layout         tiles   peel   replay  search   note")

	var fails := 0
	for name in layouts:
		var peel_ok := 0
		var replay_ok := 0
		var search_ok := 0
		var tiles_n := 0
		var notes: Array[String] = []
		for s in range(SEEDS_PER_LAYOUT):
			var rng := RandomNumberGenerator.new()
			rng.seed = 990000 + s * 7919
			var tiles := BoardGenerator.deal_board(name, rng)
			var order: Array = BoardGenerator.last_deal_order.duplicate()
			tiles_n = tiles.size()

			if order.is_empty():
				notes.append("seed %d fell back to shuffle" % s)
			else:
				peel_ok += 1

			_load(tiles)
			if not order.is_empty() and _replay(order):
				replay_ok += 1
			elif not order.is_empty():
				notes.append("seed %d replay rejected" % s)

			_load(tiles)
			if _greedy_solve():
				search_ok += 1

		var note := ""
		if peel_ok < SEEDS_PER_LAYOUT or replay_ok < SEEDS_PER_LAYOUT:
			note = "  FAIL: " + ", ".join(notes)
			fails += 1
		elif search_ok < SEEDS_PER_LAYOUT:
			note = "  (%d not proven by greedy; peel replay holds)" % (SEEDS_PER_LAYOUT - search_ok)
		print("%-14s %5d  %3d/%-3d %3d/%-3d %3d/%-3d%s" % [
			name, tiles_n, peel_ok, SEEDS_PER_LAYOUT, replay_ok, SEEDS_PER_LAYOUT,
			search_ok, SEEDS_PER_LAYOUT, note])

	print("")
	print("Failures: %d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func _load(tiles: Array) -> void:
	_n = tiles.size()
	_x = PackedInt32Array(); _x.resize(_n)
	_y = PackedInt32Array(); _y.resize(_n)
	_z = PackedInt32Array(); _z.resize(_n)
	_size = PackedInt32Array(); _size.resize(_n)
	_key = PackedStringArray(); _key.resize(_n)
	_wild = []; _wild.resize(_n)
	_alive = []; _alive.resize(_n)
	_top_z = 0
	for i in range(_n):
		var t: RiverTile = tiles[i]
		_x[i] = t.x; _y[i] = t.y; _z[i] = t.z
		_size[i] = t.size
		_key[i] = t.get_match_key()
		_wild[i] = t.is_wild_suit()
		_alive[i] = true
		_top_z = maxi(_top_z, t.z)


## Plays the peel order against the dealt tiles: every group must be a legal
## set AND every tile in it free at the moment it is taken.
func _replay(order: Array) -> bool:
	var at: Dictionary = {}
	for i in range(_n):
		at[Vector3i(_x[i], _y[i], _z[i])] = i
	var grid := _grid()
	for group in order:
		var idx: Array[int] = []
		for slot in group["slots"]:
			var v := Vector3i(int(slot["x"]), int(slot["y"]), int(slot["z"]))
			if not at.has(v):
				return false
			idx.append(at[v])
		for i in idx:
			if not _alive[i] or not _free(i, grid):
				return false
		if not _is_legal_set(idx):
			return false
		for i in idx:
			_alive[i] = false
			grid.erase(Vector3i(_x[i], _y[i], _z[i]))
	for i in range(_n):
		if _alive[i]:
			return false
	return true


func _is_legal_set(idx: Array[int]) -> bool:
	var wilds := 0
	var keys: Dictionary = {}
	var has_triple := false
	for i in idx:
		if _wild[i]:
			wilds += 1
		else:
			keys[_key[i]] = true
		if _size[i] == 3:
			has_triple = true
	if keys.size() > 1:
		return false
	if idx.size() == 2:
		return true
	if idx.size() == 3:
		return has_triple or wilds > 0
	return false


func _free(i: int, grid: Dictionary) -> bool:
	for dz in range(_z[i] + 1, _top_z + 1):
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				if grid.has(Vector3i(_x[i] + dx, _y[i] + dy, dz)):
					return false
	var left := false
	var right := false
	for dy in range(-1, 2):
		if grid.has(Vector3i(_x[i] - 2, _y[i] + dy, _z[i])):
			left = true
		if grid.has(Vector3i(_x[i] + 2, _y[i] + dy, _z[i])):
			right = true
	return not (left and right)


func _grid() -> Dictionary:
	var g := {}
	for i in range(_n):
		if _alive[i]:
			g[Vector3i(_x[i], _y[i], _z[i])] = i
	return g


func _free_indices(grid: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for i in range(_n):
		if _alive[i] and _free(i, grid):
			out.append(i)
	return out


func _moves(free_list: Array[int]) -> Array:
	var wilds: Array[int] = []
	var by_key: Dictionary = {}
	for i in free_list:
		if _wild[i]:
			wilds.append(i)
		else:
			if not by_key.has(_key[i]):
				by_key[_key[i]] = [] as Array[int]
			by_key[_key[i]].append(i)

	var moves: Array = []
	for k in by_key.keys():
		var list: Array = by_key[k]
		var s2: Array = []
		for i in list:
			if _size[i] == 2:
				s2.append(i)
		for a in range(s2.size()):
			for b in range(a + 1, s2.size()):
				moves.append([s2[a], s2[b]])
		if list.size() >= 3:
			for a in range(list.size()):
				for b in range(a + 1, list.size()):
					for c in range(b + 1, list.size()):
						if _size[list[a]] == 3 or _size[list[b]] == 3 or _size[list[c]] == 3:
							moves.append([list[a], list[b], list[c]])
		if not wilds.is_empty() and list.size() >= 2:
			for a in range(list.size()):
				for b in range(a + 1, list.size()):
					if _size[list[a]] == 3 or _size[list[b]] == 3:
						for w in wilds:
							moves.append([list[a], list[b], w])
		if wilds.size() >= 2:
			for i in list:
				if _size[i] == 3:
					for w1 in range(wilds.size()):
						for w2 in range(w1 + 1, wilds.size()):
							moves.append([i, wilds[w1], wilds[w2]])
	for a in range(wilds.size()):
		for b in range(a + 1, wilds.size()):
			moves.append([wilds[a], wilds[b]])
	for w in wilds:
		for i in free_list:
			if not _wild[i] and _size[i] == 2:
				moves.append([w, i])
	return moves


## Randomised greedy with restarts, biased toward the deepest tiles. Knows
## nothing about the peel order, so a clear here is independent evidence.
func _greedy_solve() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var snapshot := _alive.duplicate()
	for attempt in range(GREEDY_RESTARTS):
		_alive = snapshot.duplicate()
		var remaining := _n
		while remaining > 0:
			var grid := _grid()
			var moves := _moves(_free_indices(grid))
			if moves.is_empty():
				break
			moves.sort_custom(func(a, b): return _depth(a) > _depth(b))
			# Mostly take the deepest move; occasionally take another so the
			# restarts explore genuinely different lines.
			var pick: int = 0
			if attempt > 0 and moves.size() > 1 and rng.randf() < 0.35:
				pick = rng.randi_range(0, mini(moves.size() - 1, 5))
			for i in moves[pick]:
				_alive[i] = false
				remaining -= 1
		if remaining == 0:
			return true
	return false


func _depth(move: Array) -> int:
	var d := 0
	for i in move:
		d += _z[i]
	return d


func _cross_check() -> bool:
	var board = load("res://scenes/board.tscn").instantiate()
	add_child(board)
	var ok := true
	for name in ["quick", "garden", "turtle"]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 4242
		board.load_stage(name, rng)
		var theirs: int = board.get_legal_sets().size()
		var tiles: Array = board.get_active_tiles()
		_load(tiles)
		var mine: int = _moves(_free_indices(_grid())).size()
		if mine != theirs:
			print("  cross-check %s: mine %d vs game %d" % [name, mine, theirs])
			ok = false
	board.queue_free()
	return ok
