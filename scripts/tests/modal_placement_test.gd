extends Node

## Every menu must float mid-screen. Settings and Levels are taller than the
## screen and used to sit against the top edge while the rest were centred.

var _fails: int = 0


func _ready() -> void:
	await get_tree().process_frame
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = true
	await get_tree().create_timer(1.2).timeout
	var m = main.get_node("Modal")
	var screens: Array = [
		"show_main_menu", "show_settings_menu", "show_bazaar_modal",
		"show_tile_catalog_modal", "show_background_catalog_modal", "show_treasury_modal",
		"show_level_select", "show_pause_menu", "show_privacy_modal", "show_credits_modal",
	]
	for size in [Vector2i(576, 1024), Vector2i(576, 1280)]:
		get_window().size = size
		await get_tree().create_timer(0.3).timeout
		print("== window %s  visible %s" % [size, m.get_viewport().get_visible_rect().size])
		for s in screens:
			m.call(s)
			await get_tree().process_frame
			await get_tree().process_frame
			var early: float = m.scroll_view.custom_minimum_size.y
			await get_tree().create_timer(0.5).timeout
			var got: float = m.scroll_view.custom_minimum_size.y
			var want: float = m.card_container.get_combined_minimum_size().y
			var top: float = m.card_panel.global_position.y
			var h: float = m.get_viewport().get_visible_rect().size.y
			var ok: bool = top >= m.CARD_MARGIN * 0.9 and early == got
			if not ok:
				_fails += 1
			print("  %s  %-32s top=%.0f height=%.0f content=%.0f" % ["PASS" if ok else "FAIL", s, top, got, want])
	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
