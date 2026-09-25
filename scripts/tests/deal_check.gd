extends SceneTree

## Deals every changed layout a few times and reports it. A layout is ASCII art
## until it has been dealt: the peel generator has to find a clearing order over
## the shape, and a shape it cannot solve stalls rather than fails - which is
## exactly what happened to an untested 9x12 block-out earlier today.

const BoardGenerator = preload("res://scripts/core/board_generator.gd")
const LayoutData = preload("res://scripts/core/layout_data.gd")

func _init() -> void:
	var names: Array = LayoutData.LAYOUTS.keys()
	var bad: Array = []
	var slow: Array = []
	for name in names:
		var pos: Array = BoardGenerator.get_layout_positions(name)
		var t0: int = Time.get_ticks_msec()
		var ok: int = 0
		for i in range(2):
			var rng := RandomNumberGenerator.new()
			rng.seed = 1000 + i
			var tiles: Array = BoardGenerator.deal_board(name, rng)
			if tiles.size() == pos.size():
				ok += 1
		var ms: int = Time.get_ticks_msec() - t0
		if ok < 2:
			bad.append("%s (%d positions, %d ms)" % [name, pos.size(), ms])
		elif ms > 3000:
			slow.append("%s (%d ms)" % [name, ms])
	print("layouts checked: %d" % names.size())
	print("undealable: %d" % bad.size())
	for b in bad:
		print("  FAIL %s" % b)
	print("slow: %d" % slow.size())
	for sl in slow:
		print("  SLOW %s" % sl)
	quit(0)
