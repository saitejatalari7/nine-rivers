extends Node

## Renders a real dealt board so a layout can be judged on screen.

func _ready() -> void:
	await get_tree().process_frame
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = true
	await get_tree().create_timer(1.4).timeout

	var board = main.get_node("Board")
	var modal = main.get_node("Modal")
	modal.hide_modal()
	for entry in [["board_turtle", "turtle"], ["board_pagoda", "pagoda"]]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 20260916
		board.load_stage(entry[1], rng)
		board.visible = true
		main.get_node("HUD").visible = true
		main.get_node("Camera2D").frame_board(board.board_bounds, get_viewport().get_visible_rect().size)
		await get_tree().create_timer(1.1).timeout
		await RenderingServer.frame_post_draw
		var path := "res://assets/branding/screens/real_game/%s.png" % entry[0]
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		print("  " + path)
	get_tree().quit(0)
