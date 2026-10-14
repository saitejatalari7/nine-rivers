extends SceneTree

## For every layout: the fewest tiles that must be removed before each
## position can be freed (a strict lower bound), and how deep the deepest is.

const LayoutData = preload("res://scripts/core/layout_data.gd")
const BoardGenerator = preload("res://scripts/core/board_generator.gd")
const StagePlan = preload("res://scripts/core/stage_plan.gd")

var grid: Dictionary = {}
var cover_memo: Dictionary = {}
var side_memo: Dictionary = {}

func _init() -> void:
	var rows: Array = []
	for name in LayoutData.LAYOUTS.keys():
		var pos: Array = BoardGenerator.get_layout_positions(name)
		grid.clear(); cover_memo.clear(); side_memo.clear()
		for p in pos:
			grid[Vector3i(p["x"], p["y"], p["z"])] = true
		var n: int = pos.size()
		var best: float = 0.0
		var over_half: int = 0
		for p in pos:
			var k := Vector3i(p["x"], p["y"], p["z"])
			var f: float = float(must(k).size()) / float(n)
			best = maxf(best, f)
			if f >= 0.5:
				over_half += 1
		rows.append([name, n, best, over_half])
	rows.sort_custom(func(a, b): return a[2] > b[2])
	for r in rows:
		print("%-18s %3d tiles  deepest needs %3d%%  positions>=50%%: %d" % [r[0], r[1], int(r[2] * 100.0), r[3]])
	var koi_levels: Array = []
	for lv in range(10, StagePlan.TOTAL_LEVELS + 1, 5):
		koi_levels.append("%d:%s" % [lv, StagePlan.layout_for_level(lv)])
	print("koi levels -> ", " ".join(koi_levels))
	quit()

func cover(k: Vector3i) -> Dictionary:
	if cover_memo.has(k):
		return cover_memo[k]
	var out: Dictionary = {}
	for kk in grid.keys():
		if kk.z > k.z and absi(kk.x - k.x) <= 1 and absi(kk.y - k.y) <= 1:
			out[kk] = true
			for c in cover(kk).keys():
				out[c] = true
	cover_memo[k] = out
	return out

func side(k: Vector3i, dir: int) -> Dictionary:
	var key := Vector4i(k.x, k.y, k.z, dir)
	if side_memo.has(key):
		return side_memo[key]
	var out: Dictionary = {}
	for dy in range(-1, 2):
		var nb := Vector3i(k.x + 2 * dir, k.y + dy, k.z)
		if grid.has(nb):
			out[nb] = true
			for c in cover(nb).keys():
				out[c] = true
			for c in side(nb, dir).keys():
				out[c] = true
	side_memo[key] = out
	return out

func must(k: Vector3i) -> Dictionary:
	var c: Dictionary = cover(k)
	var best: Dictionary = {}
	var best_n: int = 1 << 30
	for dir in [-1, 1]:
		var u: Dictionary = c.duplicate()
		for s in side(k, dir).keys():
			u[s] = true
		if u.size() < best_n:
			best_n = u.size()
			best = u
	return best
