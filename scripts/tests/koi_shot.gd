extends Node

const RiverTile = preload("res://scripts/core/river_tile.gd")

func _ready() -> void:
	get_window().size = Vector2i(540, 1158)
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = true
	await get_tree().create_timer(1.0).timeout
	main.get_node("Modal").hide_modal()
	var lv: int = int(OS.get_environment("KOI_LEVEL")) if OS.get_environment("KOI_LEVEL") != "" else 30
	main._start_calm_mode(lv)
	await get_tree().create_timer(2.0).timeout
	var out: String = OS.get_environment("SHOT_DIR")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/koi_board.png")
	var board = main.get_node("Board")
	# Clear to just under half, so the ring shows progress.
	var by_set: Dictionary = {}
	for t in board.live_tiles:
		if not by_set.has(t.set_id):
			by_set[t.set_id] = []
		by_set[t.set_id].append(t)
	var ids: Array = by_set.keys()
	ids.sort()
	for sid in ids:
		if board.cleared_fraction() >= 0.42:
			break
		var g: Array = by_set[sid]
		if g[0].is_removed or g[0].is_koi:
			continue
		var typed: Array[RiverTile] = []
		for t in g:
			typed.append(t)
		board._resolve_matched_set(typed)
	await get_tree().create_timer(1.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/koi_ring.png")
	main.get_node("HUD").show_bonus("KOI RESCUED!", "Level complete  ·  +25 ◈")
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/koi_trio.png")
	get_tree().quit(0)
