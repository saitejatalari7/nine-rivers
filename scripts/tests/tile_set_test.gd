extends Node

## A dealt board should look like a real mahjong set: four copies of a type,
## not an arbitrary spread.

const BoardGenerator = preload("res://scripts/core/board_generator.gd")
const LayoutData = preload("res://scripts/core/layout_data.gd")

func _ready() -> void:
	var fails := 0
	var worst_overall := 0
	print("layout         tiles  distinct  max copies  flowers  seasons")
	var names: Array = LayoutData.LAYOUTS.keys()
	names.sort()
	for name in names:
		var counts := {}
		var flowers := 0
		var seasons := 0
		var rng := RandomNumberGenerator.new()
		rng.seed = 5150
		var tiles := BoardGenerator.deal_board(name, rng)
		for t in tiles:
			if t.suit == "flower":
				flowers += 1
			elif t.suit == "season":
				seasons += 1
			else:
				var k: String = t.get_match_key()
				counts[k] = int(counts.get(k, 0)) + 1
		var worst := 0
		for k in counts:
			worst = maxi(worst, int(counts[k]))
		worst_overall = maxi(worst_overall, worst)
		# One set gives four of a type. A board needing more than the set holds
		# has to reuse, so the bound rises with size, but never arbitrarily.
		var allowed: int = 4 if tiles.size() <= 136 else 6
		var flag := ""
		if worst > allowed:
			flag = "  FAIL (max %d allowed)" % allowed
			fails += 1
		print("%-14s %5d  %8d  %10d  %7d  %7d%s" % [
			name, tiles.size(), counts.size(), worst, flowers, seasons, flag])

	print("")
	print("worst copies of any one tile, all layouts: %d" % worst_overall)
	print("Failures: %d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
