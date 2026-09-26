extends Node

## A few tiles arrive wearing a set the player does not own, and the clear
## screen leads to the page where it can be bought. This replaces the
## time-limited trial that was proposed: a trial needs an expiry, a clock the
## player cannot wind forward, and a rule for what happens when it lapses
## mid-board. A sample needs none of that and is not persisted at all.

var _fails: int = 0
var main: Node2D
var board
var modal


func _ready() -> void:
	await get_tree().process_frame
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = true
	await get_tree().create_timer(1.2).timeout
	board = main.get_node("Board")
	modal = main.get_node("Modal")
	SaveManager.economy["unlocked_themes"] = ["classic_jade"]
	SaveManager.economy["active_tile_theme"] = "classic_jade"

	await _t1_a_sample_stage_shows_a_locked_set()
	await _t2_other_stages_are_left_alone()
	await _t4_stage_5_clear_offers_shop_or_skip()
	_t5_daily_samples_every_third_day()
	await _t3_an_owner_is_not_sold_what_they_own()

	print("")
	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _t1_a_sample_stage_shows_a_locked_set() -> void:
	print("--- #1  a sample stage dresses a few tiles ---")
	main._start_calm_mode(5)
	await get_tree().create_timer(0.9).timeout

	var theme: String = main.sampled_theme
	_check("a locked set is chosen", not theme.is_empty(), "theme=%s" % theme)
	_check("and it is the cheapest one", theme == "theme_imperial_gold",
		"%s at %d" % [theme, MonetizationManager.get_pearl_cost(theme)])
	_check("and not one that cannot be bought",
		not MonetizationManager.is_earn_only(theme), "earn_only=%s" % MonetizationManager.is_earn_only(theme))

	var dressed: int = 0
	for t in board.get_active_tiles():
		var v = board.tile_views.get(t)
		if v != null and String(v.theme_override) == theme:
			dressed += 1
	_check("a handful of tiles wear it, not the board",
		dressed > 0 and dressed <= main.SAMPLE_TILES,
		"%d of %d tiles" % [dressed, board.get_active_tiles().size()])

	# Nothing is persisted: this is the whole reason it is a sample and not a
	# trial with an expiry.
	_check("the player still does not own it",
		not MonetizationManager.is_theme_unlocked(theme), "")
	_check("and their equipped set is untouched",
		MonetizationManager.get_active_theme() == "classic_jade",
		MonetizationManager.get_active_theme())

	modal.show_level_clear(5, 1200, 3, theme)
	await get_tree().create_timer(0.4).timeout
	_check("the clear screen offers it", _find_text(modal, "Keep the") != "",
		_find_text(modal, "Keep the"))


func _t2_other_stages_are_left_alone() -> void:
	print("--- #2  most boards are just boards ---")
	modal.hide_modal()
	for lv in [6, 10]:
		main._start_calm_mode(lv)
		await get_tree().create_timer(0.9).timeout
		_check("stage %d shows nothing" % lv, main.sampled_theme.is_empty(),
			"sampled=%s" % main.sampled_theme)
	var dressed: int = 0
	for t in board.get_active_tiles():
		var v = board.tile_views.get(t)
		if v != null and not String(v.theme_override).is_empty():
			dressed += 1
	_check("and no tile is dressed", dressed == 0, "%d dressed" % dressed)


func _t3_an_owner_is_not_sold_what_they_own() -> void:
	print("--- #3  nothing is pitched to someone who owns it all ---")
	SaveManager.economy["unlocked_themes"] = [
		"classic_jade", "theme_imperial_gold", "theme_obsidian_ink",
		"theme_cherry_blossom", "theme_indigo"]
	main._start_calm_mode(5)
	await get_tree().create_timer(0.9).timeout
	_check("a player who owns every set is shown none", main.sampled_theme.is_empty(),
		"sampled=%s" % main.sampled_theme)


func _t4_stage_5_clear_offers_shop_or_skip() -> void:
	print("--- #4  clearing stage 5 asks: shop or skip ---")
	modal.hide_modal()
	main._start_calm_mode(5)
	await get_tree().create_timer(0.9).timeout
	main._on_board_cleared()
	await get_tree().create_timer(0.4).timeout
	_check("the offer card is shown", modal._current_screen == "premium_offer",
		modal._current_screen)
	_check("with a shop button", _find_text(modal, "Go to Shop") != "", "")
	_check("and a skip", _find_text(modal, "Skip") != "", "")
	modal.next_stage_requested.emit()
	await get_tree().create_timer(0.4).timeout
	_check("skip carries on to the clear screen", modal._current_screen == "level_clear",
		modal._current_screen)
	modal.hide_modal()


func _t5_daily_samples_every_third_day() -> void:
	print("--- #5  the daily puzzle wears them every third day ---")
	var hits: int = 0
	var start: int = 1_760_000_000
	for d in 30:
		if main.is_daily_sample_day(start + d * 86400):
			hits += 1
	_check("10 days in 30", hits == 10, "%d" % hits)
	_check("with 10 tiles", main.DAILY_SAMPLE_TILES == 10, "")


func _find_text(node: Node, needle: String) -> String:
	for c in node.get_children():
		if c is Button and String((c as Button).text).contains(needle):
			return (c as Button).text
		if c is Label and String((c as Label).text).contains(needle):
			return (c as Label).text
		var deeper := _find_text(c, needle)
		if deeper != "":
			return deeper
	return ""


func _check(what: String, ok: bool, detail: String) -> void:
	if not ok:
		_fails += 1
	print("  %s  %-46s %s" % ["PASS" if ok else "FAIL", what, detail])
