extends Node

## Deep Rivers: locked until stage 25 is cleared, its own progress, stars and
## chapters, the unlock card in the flow and once for upgraders, and the two
## campaign endings. SHOT_DIR, when set, also saves the new screens.

var _fails: int = 0
var main
var modal


func _ready() -> void:
	get_window().size = Vector2i(540, 1200)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	modal = main.get_node("Modal")
	var keep: Dictionary = SaveManager.prog.duplicate(true)
	SaveManager.prog["tutorial_completed"] = true
	SaveManager.prog["koi_intro_seen"] = true
	SaveManager.prog["level"] = 20
	SaveManager.prog["deep_level"] = 501
	SaveManager.prog["deep_intro_seen"] = false
	SaveManager.prog["stars"] = {}
	await get_tree().create_timer(1.2).timeout

	_check("locked before stage 25 is cleared", not SaveManager.deep_unlocked(), "")
	modal.show_main_menu()
	_check("the menu shows it locked", _menu_has("Unlocks at stage 25"), "")
	await _shot("deep_menu_locked")

	SaveManager.record_level_clear(25, 100, 3)
	_check("clearing 25 opens it", SaveManager.deep_unlocked(), str(SaveManager.prog["level"]))
	main._continue_after(25)
	await get_tree().process_frame
	_check("and the unlock card follows the clear", modal._current_screen == "deep_unlocked", modal._current_screen)
	await _shot("deep_unlocked_card")
	modal.handle_back_pressed()
	await get_tree().create_timer(0.8).timeout
	_check("back carries on to classic stage 26", GameManager.current_level == 26, str(GameManager.current_level))
	main._continue_after(25)
	await get_tree().process_frame
	_check("the card is shown once", not (modal.visible and modal._current_screen == "deep_unlocked"), modal._current_screen)

	main._start_calm_mode(501)
	await get_tree().create_timer(0.8).timeout
	_check("the HUD numbers deep stages from 1", main.get_node("HUD").lbl_level.text == "D1", main.get_node("HUD").lbl_level.text)
	SaveManager.record_level_clear(501, 100, 3)
	_check("a deep clear moves the deep pointer", SaveManager.deep_level() == 502, str(SaveManager.deep_level()))
	_check("and not the classic one", int(SaveManager.prog["level"]) == 26, str(SaveManager.prog["level"]))
	_check("deep stars count only for deep", StagePlan.track_stars(SaveManager.prog["stars"], true) == 3, "")
	_check("deep chapter 1 needs no stars", StagePlan.stars_required(StagePlan.chapter_of(501)) == 0, "")
	_check("deep chapter 2 needs 90 deep stars", StagePlan.stars_required(StagePlan.chapter_of(551)) == 90, str(StagePlan.stars_required(StagePlan.chapter_of(551))))
	_check("deep stages are named within their campaign", StagePlan.stage_name(512) == "Deep Stage 12", StagePlan.stage_name(512))

	MonetizationManager.equip_theme("classic_jade")
	var had_indigo: bool = MonetizationManager.is_theme_unlocked("theme_indigo")
	var econ: Dictionary = SaveManager.economy.duplicate(true)
	var themes: Array = SaveManager.economy.get("unlocked_themes", []).duplicate()
	themes.erase("theme_indigo")
	SaveManager.economy["unlocked_themes"] = themes
	main._start_calm_mode(560)
	await get_tree().create_timer(0.8).timeout
	main._on_board_cleared()
	await get_tree().create_timer(0.5).timeout
	_check("a deep clear does not hand out stage 50's set", not MonetizationManager.is_theme_unlocked("theme_indigo"), "")
	SaveManager.economy = econ

	modal.show_level_select(true)
	await get_tree().process_frame
	_check("the deep levels screen opens", modal._current_screen == "level_select", "")
	await _shot("deep_levels")
	modal.show_main_menu()
	_check("the menu shows deep progress", _menu_has("D%d/500" % (SaveManager.deep_level() - 500)), str(SaveManager.deep_level()))
	await _shot("deep_menu_open")

	SaveManager.prog["deep_intro_seen"] = false
	SaveManager.prog["level"] = 140
	modal.show_main_menu()
	_check("an upgrader past 25 is told once", modal._current_screen == "deep_unlocked", modal._current_screen)
	modal.handle_back_pressed()
	_check("then the menu", modal._current_screen == "main", modal._current_screen)

	main._continue_after(500)
	await get_tree().process_frame
	_check("stage 500 ends the classic campaign", modal._current_screen == "campaign_complete" and _menu_has("Play Deep Rivers"), "")
	await _shot("classic_complete")
	main._continue_after(1000)
	await get_tree().process_frame
	_check("stage 1000 ends Deep Rivers", modal._current_screen == "campaign_complete" and _menu_has("Deep Rivers Complete"), "")

	SaveManager.prog = keep
	SaveManager.save_game()
	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _menu_has(text: String) -> bool:
	return _find(modal, text)


func _find(n: Node, text: String) -> bool:
	if (n is Label or n is Button) and String(n.text).to_lower().contains(text.to_lower()):
		return true
	for c in n.get_children():
		if _find(c, text):
			return true
	return false


func _shot(name: String) -> void:
	var dir: String = OS.get_environment("SHOT_DIR")
	if dir.is_empty():
		return
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir + "/" + name + ".png")


func _check(what: String, ok: bool, detail: String) -> void:
	if not ok:
		_fails += 1
	print("  %s  %-50s %s" % ["PASS" if ok else "FAIL", what, detail])
