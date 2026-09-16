extends Node

func _ready() -> void:
	await get_tree().process_frame
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = true
	SaveManager.add_jade(4000)
	await get_tree().create_timer(1.4).timeout

	var sanc = main.get_node("Sanctuary")
	main._open_sanctuary()
	await get_tree().create_timer(0.8).timeout
	await _shot("sanc_1_pond")

	sanc.get_node("BottomBar/BtnShop").pressed.emit()
	await get_tree().create_timer(0.6).timeout
	await _shot("sanc_2_shop")

	# Leave and come back: the drawer must not still be open.
	main._return_home_from_sanctuary()
	await get_tree().create_timer(0.4).timeout
	main._open_sanctuary()
	await get_tree().create_timer(0.8).timeout
	await _shot("sanc_3_revisit")
	print("drawer visible on revisit: %s" % str(sanc.get_node("ShopDrawer").visible))

	var rows := sanc.get_node("ShopDrawer/Body/Scroll/ShopList").get_children()
	var worst := 99999.0
	for r in rows:
		for c in r.get_children():
			if c is Button:
				worst = minf(worst, maxf(c.size.y, c.custom_minimum_size.y))
	print("smallest shop row button: %.0f px" % worst)
	get_tree().quit(0)

func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	var p := "res://assets/branding/screens/real_game/%s.png" % n
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(p))
	print("  " + p)
