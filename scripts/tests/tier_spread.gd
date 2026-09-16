extends Node
const StagePlan = preload("res://scripts/core/stage_plan.gd")
func _ready() -> void:
	for t in range(1, StagePlan.TIERS + 1):
		var pool: Array = StagePlan.layouts_in_tier(t)
		print("  tier %d: %d layouts" % [t, pool.size()])
	get_tree().quit(0)
