extends SceneTree

const BoardGenerator = preload("res://scripts/core/board_generator.gd")
const RiverTile = preload("res://scripts/core/river_tile.gd")

func _init() -> void:
	# Counts tiles and set composition only - it does NOT prove a board can be
	# cleared, despite the historical name. layout_validator does that.
	print("--- Running Nine Rivers Board Deal Test (counts only) ---")
	var layouts: Array[String] = [
		"quick", "gate", "steps", "garden", "lotus", "bridges", "keep", "waterfall", "dragon_gate", "citadel", "turtle"
	]
	var total_tested: int = 0
	var total_passed: int = 0
	
	for l_name in layouts:
		var pos := BoardGenerator.get_layout_positions(l_name)
		var tiles := BoardGenerator.deal_board(l_name)
		total_tested += 1
		
		if tiles.size() != pos.size():
			printerr("FAILED layout: %s. Expected %d tiles, got %d" % [l_name, pos.size(), tiles.size()])
		else:
			var triples := 0
			var wilds := 0
			for t in tiles:
				if t.size == 3:
					triples += 1
				if t.is_wild_suit():
					wilds += 1
			print("DEALT layout: %s (%s) -> %d tiles, %d triple members, %d natural wilds" % [
				l_name, BoardGenerator.LAYOUT_NAMES.get(l_name, ""), tiles.size(), triples, wilds
			])
			total_passed += 1
			
	print("--- Test Complete: %d / %d Layouts Dealt Correctly ---" % [total_passed, total_tested])
	if total_passed == total_tested:
		quit(0)
	else:
		quit(1)
