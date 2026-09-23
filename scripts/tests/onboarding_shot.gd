extends Node
func _ready() -> void:
	await get_tree().process_frame
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = false
	await get_tree().create_timer(1.2).timeout
	main.get_node("Modal").hide_modal()
	main._start_calm_mode(1)
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("res://assets/branding/screens/real_game/onboarding.png"))
	print("  shot written")
	get_tree().quit(0)
