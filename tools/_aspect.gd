extends SceneTree

const BoardGenerator = preload("res://scripts/core/board_generator.gd")

func _init() -> void:
	print("%-14s %5s %5s %6s %6s  %s" % ["layout", "cols", "rows", "w", "h", "w:h"])
	for name in BoardGenerator.LADDER:
		var pos: Array = BoardGenerator.get_layout_positions(name)
		var mx := 0; var my := 0; var mz := 0
		for p in pos:
			mx = maxi(mx, int(p[0])); my = maxi(my, int(p[1])); mz = maxi(mz, int(p[2]))
		var w: float = (mx * 0.5) * 64.0 + 64.0 + mz * 8.0
		var h: float = (my * 0.5) * 84.0 + 84.0 + mz * 10.0
		print("%-14s %5d %5d %6.0f %6.0f  %.2f  tiles=%d" % [name, mx, my, w, h, w / h, pos.size()])
	quit(0)
