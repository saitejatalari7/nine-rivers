extends Node

## The three lesson boards and the closing card, as a first-time player sees
## them.

func _ready() -> void:
	await get_tree().process_frame
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = false
	SaveManager.prog["level"] = 1
	await get_tree().create_timer(1.2).timeout
	main.get_node("Modal").hide_modal()
	main._start_calm_mode(1)
	await get_tree().create_timer(1.0).timeout

	var tut = main.get_node("TutorialController")
	for i in range(4):
		await _shot("onboarding_%d" % (i + 1))
		if i < 3:
			tut._next_beat()
			await get_tree().create_timer(0.9).timeout
	get_tree().quit(0)


func _shot(name: String) -> void:
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var p := "res://assets/branding/screens/real_game/%s.png" % name
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(p))
	print("  " + p)
