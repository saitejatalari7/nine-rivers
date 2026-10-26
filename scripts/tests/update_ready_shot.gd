extends Node

func _ready() -> void:
	get_window().size = Vector2i(540, 1158)
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = true
	await get_tree().create_timer(1.0).timeout
	UpdateManager.ready_to_install = true
	UpdateManager.restart_offered = false
	main.get_node("Modal").show_main_menu()
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR") + "/update_ready.png")
	UpdateManager.ready_to_install = false
	get_tree().quit()
