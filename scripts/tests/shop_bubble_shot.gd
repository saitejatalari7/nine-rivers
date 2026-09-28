extends Node

## The Shop with its rewarded-video bubble, and a check that the bubble shows
## on the Shop only and pays 20 pearls.

var _fails: int = 0

func _ready() -> void:
	get_window().size = Vector2i(1080, 1920)
	await get_tree().process_frame
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = true
	SaveManager.economy["rewarded_ads_today"] = 0
	await get_tree().create_timer(1.2).timeout
	var m = main.get_node("Modal")
	m.show_bazaar_modal()
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://release/shop_bubble.png"))
	_check("bubble shows on the Shop", m._reward_bubble != null and m._reward_bubble.visible, "")
	var before: int = MonetizationManager.get_pearls()
	m._on_watch_reward()
	await get_tree().create_timer(0.3).timeout
	_check("a video pays 20 pearls", MonetizationManager.get_pearls() - before == 20,
		"%d" % (MonetizationManager.get_pearls() - before))
	for s in ["show_main_menu", "show_settings_menu", "show_tile_catalog_modal", "show_treasury_modal"]:
		m.call(s)
		await get_tree().create_timer(0.3).timeout
		_check("no bubble on %s" % s, not m._reward_bubble.visible, "")
	m.hide_modal()
	main._start_calm_mode(5)
	await get_tree().create_timer(0.8).timeout
	_check("no bubble on the board", not m._reward_bubble.visible, "")
	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)

func _check(what: String, ok: bool, detail: String) -> void:
	if not ok:
		_fails += 1
	print("  %s  %-36s %s" % ["PASS" if ok else "FAIL", what, detail])
