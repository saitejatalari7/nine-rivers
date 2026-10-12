extends Node

func _ready() -> void:
	get_window().size = Vector2i(540, 1158)
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = true
	await get_tree().create_timer(1.0).timeout
	main.get_node("Modal").hide_modal()
	main._start_calm_mode(31)
	await get_tree().create_timer(0.3).timeout
	var hud = main.get_node("HUD")
	hud.show_toast("River Fog: Deep river mist conceals all blocked tiles until freed")
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR") + "/toast_long.png")
	hud.show_toast("Board reshuffled!")
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR") + "/toast_short.png")
	var p: Control = hud.toast_panel
	print("short toast x=%.0f w=%.0f vp=%.0f" % [p.position.x, p.size.x, get_viewport().get_visible_rect().size.x])
	get_tree().quit(0)
