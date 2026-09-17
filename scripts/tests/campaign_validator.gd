extends Node

## Every level the campaign will actually deal, checked with the seed it will
## actually use. layout_validator checks LAYOUTS with arbitrary seeds; this
## checks LEVELS. deal_board falls back to a plain shuffle when peel_dynamic
## fails after 150 attempts, and that fallback carries no solvability
## guarantee, so a single unlucky level seed could ship an unclearable board.

const StagePlan = preload("res://scripts/core/stage_plan.gd")
const BoardGenerator = preload("res://scripts/core/board_generator.gd")
const RiverTile = preload("res://scripts/core/river_tile.gd")

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
	var fallbacks: Array[int] = []
	var replay_fails: Array[int] = []
	var tile_total: int = 0
	var by_tier := {}

	for lv in range(1, StagePlan.TOTAL_LEVELS + 1):
		var plan: Dictionary = StagePlan.describe(lv)
		var rng := RandomNumberGenerator.new()
		rng.seed = int(plan["seed"])
		var tiles := BoardGenerator.deal_board(String(plan["layout"]), rng)
		var order: Array = BoardGenerator.last_deal_order.duplicate()
		tile_total += tiles.size()
		by_tier[plan["tier"]] = int(by_tier.get(plan["tier"], 0)) + 1

		if order.is_empty():
			fallbacks.append(lv)
			continue
		_load(tiles)
		if not _replay(order):
			replay_fails.append(lv)

	print("levels checked     : %d" % StagePlan.TOTAL_LEVELS)
	print("tiles dealt        : %d" % tile_total)
	var tiers := ""
	for t in range(1, StagePlan.TIERS + 1):
		tiers += "T%d:%d  " % [t, int(by_tier.get(t, 0))]
	print("levels per tier    : %s" % tiers)
	print("shuffle fallbacks  : %d %s" % [fallbacks.size(), str(fallbacks.slice(0, 8))])
	print("replay failures    : %d %s" % [replay_fails.size(), str(replay_fails.slice(0, 8))])
	var fails: int = fallbacks.size() + replay_fails.size()
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

func _replay(order: Array) -> bool:
	var at := {}
	for i in range(_n):
		at[Vector3i(_x[i], _y[i], _z[i])] = i
	var grid := {}
	for i in range(_n):
		grid[Vector3i(_x[i], _y[i], _z[i])] = i
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
		if not _legal(idx):
			return false
		for i in idx:
			_alive[i] = false
			grid.erase(Vector3i(_x[i], _y[i], _z[i]))
	for i in range(_n):
		if _alive[i]:
			return false
	return true

func _legal(idx: Array[int]) -> bool:
	var wilds := 0
	var keys := {}
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
	return idx.size() == 3 and (has_triple or wilds > 0)

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
