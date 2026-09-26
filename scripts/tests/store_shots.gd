extends Node

## Play Store phone screenshots at the full 1080x1920 design size.
##
## Play wants 16:9 portrait and at least 1080 px on a side to feature an app.
## The window normally opens at 576x1024, which would upscale blurry, so it is
## resized to the design size before anything is captured.

const StagePlan = preload("res://scripts/core/stage_plan.gd")
const RiverTile = preload("res://scripts/core/river_tile.gd")
const OUT := "res://release/store/screenshots/"

var main: Node


func _ready() -> void:
	get_window().size = Vector2i(1080, 1920)
	await get_tree().process_frame
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = true
	SaveManager.prog["level"] = 18
	SaveManager.economy["pearls"] = 1240
	SaveManager.prog["daily_streak"] = 6
	SaveManager.economy["unlocked_themes"] = [
		"classic_jade", "theme_imperial_gold", "theme_obsidian_ink",
		"theme_cherry_blossom", "theme_indigo"]
	SaveManager.economy["unlocked_background_themes"] = [
		"auto", "emerald_pond", "moonlit_river", "autumn_stream",
		"misty_spring", "sunset_haven"]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await get_tree().create_timer(1.5).timeout
	print("viewport: %s" % get_viewport().get_visible_rect().size)

	var modal = main.get_node("Modal")
	modal.show_main_menu()
	await _shot("01_main_menu")

	await _board("classic_jade", "emerald_pond", 12, "02_board_jade")
	await _board("theme_imperial_gold", "moonlit_river", 33, "03_board_gold")
	await _board("theme_cherry_blossom", "misty_spring", 57, "04_board_blossom")

	main.get_node("HUD").visible = false
	main.get_node("Board").visible = false
	modal.show_tile_detail_modal("theme_obsidian_ink")
	await _shot("05_tile_set")

	modal.show_level_select()
	await _shot("06_stages")

	MonetizationManager.equip_theme("classic_jade")
	MonetizationManager.equip_background_theme("auto")
	get_tree().quit(0)


func _plain_stage(from: int) -> int:
	for lv in range(from, from + 40):
		if StagePlan.modifier_for_level(lv) == 0:
			return lv
	return from


## A board a few moves in: a score on the HUD and gaps in the layout read as a
## game being played, where a fresh deal reads as a menu background.
func _board(tiles: String, pond: String, from_stage: int, name: String) -> void:
	main.get_node("Modal").hide_modal()
	MonetizationManager.equip_theme(tiles)
	MonetizationManager.equip_background_theme(pond)
	main._start_calm_mode(_plain_stage(from_stage))
	await get_tree().create_timer(1.5).timeout
	var board = main.get_node("Board")
	for i in 5:
		var sets: Array = board.get_legal_sets()
		if sets.is_empty():
			break
		var typed: Array[RiverTile] = []
		for t in sets[i % sets.size()]:
			typed.append(t)
		board._resolve_matched_set(typed)
		await get_tree().create_timer(0.5).timeout
	await get_tree().create_timer(1.5).timeout
	await _shot(name)


func _shot(name: String) -> void:
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var p: String = ProjectSettings.globalize_path(OUT + name + ".png")
	img.save_png(p)
	print("  %s  %dx%d" % [name, img.get_width(), img.get_height()])
