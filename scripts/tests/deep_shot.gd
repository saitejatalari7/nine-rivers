extends Node

## The deep 501+ prototypes on a phone-shaped screen: a fresh deal, then the
## same board a few matches in.

const NAMES: Array[String] = ["twin_pagodas", "stone_forest", "stepped_cliffs"]
const RiverTile = preload("res://scripts/core/river_tile.gd")

func _ready() -> void:
	get_window().size = Vector2i(540, 1200)
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = true
	MonetizationManager.equip_background_theme("auto")
	var dir: String = OS.get_environment("SHOT_DIR")
	await get_tree().create_timer(1.5).timeout
	main.get_node("Modal").hide_modal()
	main._start_calm_mode(30)
	await get_tree().create_timer(1.0).timeout
	var board = main.get_node("Board")
	for n in NAMES:
		var rng := RandomNumberGenerator.new()
		rng.seed = 501
		board.load_stage(n, rng)
		main.camera.frame_board(board.board_bounds, get_viewport().get_visible_rect().size)
		await get_tree().create_timer(1.6).timeout
		print("%s: %d tiles, %d free at deal" % [n, board.live_tiles.size(), board.get_free_tiles().size() if board.has_method("get_free_tiles") else -1])
		await _shot(dir + "/deep_%s_deal.png" % n)
		for i in 8:
			var sets: Array = board.get_legal_sets()
			if sets.is_empty():
				break
			var typed: Array[RiverTile] = []
			for t in sets[0]:
				typed.append(t)
			board._resolve_matched_set(typed)
			await get_tree().create_timer(0.25).timeout
		await get_tree().create_timer(1.2).timeout
		await _shot(dir + "/deep_%s_dug.png" % n)
	get_tree().quit()

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
