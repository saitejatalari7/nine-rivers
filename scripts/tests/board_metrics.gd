extends Node

## What size a tile actually ends up on a phone, per layout. The 48dp touch
## rule applied to the menus; this measures whether it can apply to the board.

const BoardGenerator = preload("res://scripts/core/board_generator.gd")

const TW: float = 64.0
const TH: float = 84.0
const LAYER_OFF_X: float = 8.0
const LAYER_OFF_Y: float = 10.0
const DESIGN_W: float = 1080.0
const DESIGN_H: float = 1920.0
const PX_PER_DP: float = 3.0

func _ready() -> void:
	print("layout          tiles  cols rows  board px      fit    tile dp   mm")
	for name in BoardGenerator.LADDER + ["pagoda"]:
		var pos := BoardGenerator.get_layout_positions(name)
		var max_x := 0
		var max_y := 0
		var max_z := 0
		for p in pos:
			max_x = maxi(max_x, int(p["x"]))
			max_y = maxi(max_y, int(p["y"]))
			max_z = maxi(max_z, int(p["z"]))
		var bw: float = (max_x * 0.5) * TW + TW + max_z * LAYER_OFF_X
		var bh: float = (max_y * 0.5) * TH + TH + max_z * LAYER_OFF_Y

		# Same arithmetic as CameraController.frame_board.
		var padding := Vector2(70.0, 190.0 + 230.0 + 40.0)
		var avail := Vector2(DESIGN_W, DESIGN_H) - padding
		var fit: float = clampf(minf(avail.x / bw, avail.y / bh) * 0.95, 0.70, 3.5)

		var tile_px: float = TW * fit
		var tile_dp: float = tile_px / PX_PER_DP
		print("%-14s %5d  %4d %4d  %4dx%-4d  %5.2f  %6.1f  %5.1f" % [
			name, pos.size(), int(max_x / 2) + 1, int(max_y / 2) + 1,
			int(bw), int(bh), fit, tile_dp, tile_dp * 0.1588])
	get_tree().quit(0)
