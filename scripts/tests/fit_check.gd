extends Node

## Every layout, dealt and framed on a tall phone (1080x2316) and a 16:9 one:
## no tile may land under the HUD bars or off the sides.

const StagePlan = preload("res://scripts/core/stage_plan.gd")
var _fails: int = 0

func _ready() -> void:
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = true
	await get_tree().create_timer(1.0).timeout
	main.get_node("Modal").hide_modal()
	for size in [Vector2i(540, 1158), Vector2i(540, 960)]:
		get_window().size = size
		await get_tree().create_timer(0.3).timeout
		var vp: Vector2 = get_viewport().get_visible_rect().size
		var top: float = main.get_node("HUD/TopBar").get_global_rect().end.y
		var bottom: float = main.get_node("HUD/PropsBar").get_global_rect().position.y
		var worst_scale: float = 99.0
		var seen := {}
		for lv in range(1, 351, 3):
			var layout: String = StagePlan.layout_for_level(lv)
			if seen.has(layout):
				continue
			seen[layout] = true
			main._start_calm_mode(lv)
			await get_tree().create_timer(0.5).timeout
			var cam: Camera2D = main.get_node("Camera2D")
			worst_scale = minf(worst_scale, cam.zoom.x)
			var xf: Transform2D = get_viewport().get_canvas_transform()
			var board = main.get_node("Board")
			var r: Rect2 = Rect2()
			var first := true
			for t in board.get_active_tiles():
				var v = board.tile_views.get(t)
				if v == null:
					continue
				var gr: Rect2 = xf * Rect2(v.global_position, Vector2(64, 84 + 6))
				r = gr if first else r.merge(gr)
				first = false
			var ok: bool = r.position.x >= 0 and r.end.x <= vp.x and r.position.y >= top - 1 and r.end.y <= bottom + 1
			if not ok:
				_fails += 1
				print("  FAIL %s %-18s x %.0f..%.0f  y %.0f..%.0f  (bars %.0f..%.0f)" % [size, layout, r.position.x, r.end.x, r.position.y, r.end.y, top, bottom])
		print("%s: %d layouts, smallest zoom %.2f" % [size, seen.size(), worst_scale])
	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
