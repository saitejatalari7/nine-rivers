extends Node

func _ready() -> void:
	await get_tree().process_frame
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = true
	SaveManager.economy["unlocked_themes"] = ["classic_jade"]
	SaveManager.economy["active_tile_theme"] = "classic_jade"
	await get_tree().create_timer(1.2).timeout
	main.get_node("Modal").hide_modal()
	main._start_calm_mode(5)
	await get_tree().create_timer(1.4).timeout
	await RenderingServer.frame_post_draw
	var p := "res://assets/branding/screens/real_game/theme_sample.png"
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(p))
	print("  " + p)

	main.get_node("Modal").show_level_clear(5, 1200, 3, main.sampled_theme)
	await get_tree().create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	var p2 := "res://assets/branding/screens/real_game/theme_sample_offer.png"
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(p2))
	print("  " + p2)
	get_tree().quit(0)
