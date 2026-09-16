extends Node

## How buried a layout is at deal time. Tile count says how long a board takes;
## this says how constrained it is, which is the other half of difficulty.

const BoardGenerator = preload("res://scripts/core/board_generator.gd")
const LayoutData = preload("res://scripts/core/layout_data.gd")

func _ready() -> void:
	print("layout         tiles  layers  free  ratio")
	var names: Array = LayoutData.LAYOUTS.keys()
	names.sort()
	for name in names:
		var pos := BoardGenerator.get_layout_positions(name)
		var free := 0
		var max_z := 0
		for p in pos:
			if BoardGenerator.is_slot_free(p, pos):
				free += 1
			max_z = maxi(max_z, int(p["z"]))
		print("%-14s %5d  %6d  %4d  %.3f" % [
			name, pos.size(), max_z + 1, free, float(free) / maxf(1.0, float(pos.size()))])
	get_tree().quit(0)
