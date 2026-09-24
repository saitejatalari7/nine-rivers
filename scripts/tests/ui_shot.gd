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
	for entry in [
		["ui_main_rack", func():
			SaveManager.prog["rapids_runs_today"] = SaveManager.RAPIDS_RUNS_PER_DAY
			SaveManager.prog["last_rapids_date"] = SaveManager._today_utc()
			modal.show_main_menu()],
		["ui_sub_settings", func(): modal.show_settings_menu()],
		["ui_sub_levels", func(): modal.show_level_select()],
		["ui_sub_bazaar", func(): modal.show_bazaar_modal()],
		["ui_sub_treasury", func(): modal.show_treasury_modal()],
	]:
		entry[1].call()
		await get_tree().create_timer(0.45).timeout
		await _shot(entry[0])
	get_tree().quit(0)

func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	var p := "res://assets/branding/screens/real_game/%s.png" % n
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(p))
	print("  " + p)
