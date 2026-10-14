extends Node

func _ready() -> void:
	get_window().size = Vector2i(540, 1158)
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = true
	SaveManager.prog["koi_intro_seen"] = false
	await get_tree().create_timer(1.0).timeout
	main.get_node("Modal").hide_modal()
	main._start_calm_mode(10)
	await get_tree().create_timer(1.2).timeout
	var modal = main.get_node("Modal")
	print("first koi level shows: %s (visible %s)" % [modal._current_screen, modal.visible])
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR") + "/koi_intro.png")
	modal.handle_back_pressed()
	await get_tree().create_timer(0.5).timeout
	print("back closes it: visible %s" % modal.visible)
	main._start_calm_mode(15)
	await get_tree().create_timer(1.0).timeout
	print("second koi level shows card again: %s" % (modal.visible and modal._current_screen == "koi_intro"))
	get_tree().quit()
