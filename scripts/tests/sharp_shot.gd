extends Node

## Renders a board at a real phone's pixel size, to judge sharpness 1:1.

func _ready() -> void:
	get_window().size = Vector2i(1080, 2316)
	await get_tree().process_frame
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = true
	await get_tree().create_timer(1.0).timeout
	main.get_node("Modal").hide_modal()
	main._start_calm_mode(31)
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	print("window=%s image=%dx%d zoom=%.2f" % [get_window().size, img.get_width(), img.get_height(), main.get_node("Camera2D").zoom.x])
	img.save_png(OS.get_environment("SHOT_DIR") + "/sharp_full.png")
	var cam: Camera2D = main.get_node("Camera2D")
	cam.zoom = Vector2(cam.max_zoom, cam.max_zoom)
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	print("pinch zoom=%.2f" % cam.zoom.x)
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR") + "/sharp_zoomed.png")
	get_tree().quit(0)
