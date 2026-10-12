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
	main._start_calm_mode(30)
	await get_tree().create_timer(1.8).timeout
	var out: String = OS.get_environment("SHOT_DIR")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/koi_board.png")
	var board = main.get_node("Board")
	for i in 3:
		var sets: Array = board.get_legal_sets()
		var typed: Array[RiverTile] = []
		for t in sets[0]:
			typed.append(t)
		board._resolve_matched_set(typed)
		await get_tree().create_timer(0.7 if i < 2 else 0.35).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/koi_combo.png")
	main.get_node("HUD").show_bonus("KOI TRIO!", "+2000  ·  +10 ◈")
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + "/koi_trio.png")
	get_tree().quit(0)
