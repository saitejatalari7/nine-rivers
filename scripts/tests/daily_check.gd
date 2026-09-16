extends Node
const StagePlan = preload("res://scripts/core/stage_plan.gd")
const Main = preload("res://scripts/main.gd")
func _ready() -> void:
	var pool: Array = Main.daily_layout_pool()
	print("daily pool size: %d" % pool.size())
	var seen := {}
	for d in range(365):
		var s: int = 20260101 + d
		var n: String = Main.daily_layout_for_seed(s)
		seen[n] = int(seen.get(n, 0)) + 1
	var mn := 99999
	var mx := 0
	for k in seen:
		mn = mini(mn, int(seen[k]))
		mx = maxi(mx, int(seen[k]))
	print("over 365 days: %d distinct layouts, each used %d-%d times" % [seen.size(), mn, mx])
	get_tree().quit(0)
