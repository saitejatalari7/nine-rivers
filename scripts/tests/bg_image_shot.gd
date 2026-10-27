extends Node

## Each painted background behind the main menu and behind a board in play.

const IDS: Array[String] = ["bamboo_grove", "mountain_temple", "lotus_lake", "sakura_bridge"]

func _ready() -> void:
	get_window().size = Vector2i(540, 1200)
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = true
	var dir: String = OS.get_environment("SHOT_DIR")
	var modal = main.get_node("Modal")
	await get_tree().create_timer(1.5).timeout
	for id in IDS:
		MonetizationManager.unlock_background_theme(id)
		MonetizationManager.equip_background_theme(id)
		main._return_home()
		await get_tree().create_timer(1.8).timeout
		await _shot(dir + "/bg_%s_menu.png" % id)
		modal.hide_modal()
		main._start_calm_mode(24)
		await get_tree().create_timer(2.0).timeout
		await _shot(dir + "/bg_%s_play.png" % id)
	MonetizationManager.equip_background_theme("auto")
	var bgs: Array = SaveManager.economy.get("unlocked_background_themes", [])
	bgs.erase("lotus_lake")
	SaveManager.economy["unlocked_background_themes"] = bgs
	main._return_home()
	await get_tree().create_timer(0.5).timeout
	modal.show_background_catalog_modal()
	await get_tree().create_timer(0.6).timeout
	await _shot(dir + "/bg_catalog.png")
	modal.show_background_detail_modal("lotus_lake")
	await get_tree().create_timer(0.6).timeout
	await _shot(dir + "/bg_detail_locked.png")
	print("iap ids include painted: ", Array(MonetizationManager._iap_ids()).any(func(i): return i in ["bg_bamboo_grove", "bg_lotus_lake"]))
	get_tree().quit()

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("shot ", path.get_file())
