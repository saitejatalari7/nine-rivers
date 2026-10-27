extends Node

## Real levels from the deep half, the ending, and how long the deep deals take.

func _ready() -> void:
	get_window().size = Vector2i(540, 1200)
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = true
	SaveManager.prog["koi_intro_seen"] = true
	MonetizationManager.equip_background_theme("auto")
	var dir: String = OS.get_environment("SHOT_DIR")
	await get_tree().create_timer(1.5).timeout
	var modal = main.get_node("Modal")
	var BC = load("res://scripts/core/board_generator.gd")
	var worst: int = 0
	for lv in range(501, 1001, 7):
		var t0: int = Time.get_ticks_usec()
		var rng := RandomNumberGenerator.new()
		rng.seed = lv
		BC.deal_board(StagePlan.layout_for_level(lv), rng)
		worst = maxi(worst, Time.get_ticks_usec() - t0)
	print("slowest deep deal (every 7th level): %.0f ms" % (worst / 1000.0))
	for lv in [501, 525, 760, 1000]:
		modal.hide_modal()
		main._start_calm_mode(lv)
		await get_tree().create_timer(2.0).timeout
		print("level %d: %s, %d tiles, koi %s" % [lv, GameManager.current_layout_name, main.get_node("Board").get_active_tiles().size(), StagePlan.is_koi_level(lv)])
		await _shot(dir + "/lv_%d.png" % lv)
	SaveManager.prog["level"] = 1001
	main._return_home()
	await get_tree().create_timer(1.2).timeout
	await _shot(dir + "/lv_menu_done.png")
	main._start_calm_mode(1001)
	await get_tree().create_timer(1.0).timeout
	print("after 1000: ", modal._current_screen)
	await _shot(dir + "/lv_finale.png")
	SaveManager.prog["level"] = 31
	get_tree().quit()

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
