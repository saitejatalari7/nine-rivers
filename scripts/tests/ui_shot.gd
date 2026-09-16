extends Node
## Captures the main menu and one sub-screen so UI changes can be judged
## against the real renderer rather than a mockup.
func _ready() -> void:
	await get_tree().process_frame
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = true
	SaveManager.prog["level"] = 26
	await get_tree().create_timer(2.2).timeout
	var modal = main.get_node("Modal")
	modal.show_main_menu()
	await get_tree().create_timer(0.5).timeout
	await _shot("ui_main_rack")
	modal.show_settings_menu()
	await get_tree().create_timer(0.4).timeout
	await _shot("ui_sub_settings")
	get_tree().quit(0)

func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	var p := "res://assets/branding/screens/real_game/%s.png" % n
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(p))
	print("  " + p)
