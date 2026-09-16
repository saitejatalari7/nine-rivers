extends Node

## Walks every modal screen and measures the built layout, because the logic
## suites never look at geometry - which is how 11dp tap targets and clipped
## content survived 32 passing suites.

const UITheme = preload("res://scripts/ui/ui_theme.gd")

const TOUCH_MIN: float = 144.0
## The card's declared width, from modal.tscn. The budget has to be measured
## against THIS and not against the card's actual size: a child wider than the
## card simply stretches the card, so comparing to the measured width always
## passes and hides the overflow. Ask for the design width instead.
const CARD_W: float = 920.0
const DESIGN_W: float = 1080.0
## Buttons that are deliberately smaller than a finger target and are not the
## only way to reach their action.
const EXEMPT: Array[String] = []

var fails: int = 0
var checked: int = 0

func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	# main.tscn runs its intro splash on boot, and the splash tween ends by
	# calling _return_home(), which forces the main menu. If that lands while
	# the probe is part-way through, it silently replaces whatever screen is
	# being measured - and the measurement still reports "ok". Wait it out
	# before touching anything.
	var splash: Node = main.get_node_or_null("SplashScreen")
	if splash != null:
		splash.visible = false
	await get_tree().create_timer(1.2).timeout

	var modal: Node = main.get_node("Modal")
	var vp_h: float = get_viewport().get_visible_rect().size.y
	print("viewport: %s" % get_viewport().get_visible_rect().size)

	var screens: Array = [
		["main", func(): modal.show_main_menu()],
		["level_select", func(): modal.show_level_select()],
		["pause", func(): modal.show_pause_menu()],
		["level_clear", func(): modal.show_level_clear(12, 4820, 3)],
		["daily_clear", func(): modal.show_daily_clear(3100, 7, 4)],
		["boon_draft", func(): modal.show_boon_draft()],
		["game_over", func(): modal.show_game_over("No moves remain")],
		["sanctuary", func(): modal.show_sanctuary_menu()],
		["bazaar", func(): modal.show_bazaar_modal()],
		["tile_catalog", func(): modal.show_tile_catalog_modal()],
		["tile_detail", func(): modal.show_tile_detail_modal("theme_imperial_gold")],
		["bg_catalog", func(): modal.show_background_catalog_modal()],
		["bg_detail", func(): modal.show_background_detail_modal("moonlit_river")],
		["treasury", func(): modal.show_treasury_modal()],
		["daily_offerings", func(): modal.show_daily_offerings_modal()],
		["settings", func(): modal.show_settings_menu()],
		["privacy", func(): modal.show_privacy_modal()],
		["credits", func(): modal.show_credits_modal()],
	]

	for entry in screens:
		var name: String = entry[0]
		var builder: Callable = entry[1]
		builder.call()
		# One frame to build, one for the deferred fit, one to settle layout.
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		_audit_screen(name, modal, vp_h)

	print("")
	print("Checked %d controls across %d screens." % [checked, screens.size()])
	print("Failures: %d" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func _audit_screen(name: String, modal: Node, vp_h: float) -> void:
	var scroll: ScrollContainer = modal.get_node("Center/Card/Scroll")
	var content: Control = modal.get_node("Center/Card/Scroll/Content")
	var card: Control = modal.get_node("Center/Card")

	var content_h: float = content.get_combined_minimum_size().y
	var scroll_h: float = scroll.size.y
	var card_h: float = card.size.y
	var reachable: bool = content_h <= scroll_h + 1.0 or scroll.get_v_scroll_bar().max_value > scroll_h

	var pad: float = 0.0
	var sb: StyleBox = card.get_theme_stylebox("panel")
	if sb != null:
		pad = sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT)
	var budget: float = CARD_W - pad

	var small: Array[String] = []
	var wide: Array[String] = []
	_walk(content, small, wide, budget)

	var status := "ok"
	if card.get_combined_minimum_size().x > DESIGN_W:
		status = "CARD WIDER THAN SCREEN (%d)" % int(card.get_combined_minimum_size().x)
		fails += 1
	elif card_h > vp_h + 1.0:
		status = "CARD OVERFLOWS SCREEN"
		fails += 1
	elif not reachable:
		status = "CONTENT UNREACHABLE"
		fails += 1
	elif not small.is_empty():
		status = "SMALL TARGETS"
		fails += 1
	elif not wide.is_empty():
		status = "HORIZONTAL OVERFLOW"
		fails += 1

	# Headless pins the root viewport square, so scroll_h above is measured
	# against more height than a phone has. This is the real budget: 1920 design
	# px minus the status bar and the gesture pill, minus the card's padding.
	var chrome: float = card_h - scroll_h
	var phone_budget: float = 1920.0 - UITheme.SAFE_TOP_FLOOR - UITheme.SAFE_BOTTOM_FLOOR - chrome
	var on_phone: String = "SCROLLS" if content_h > phone_budget else "fits"
	if content_h > phone_budget and not reachable:
		status = "UNREACHABLE ON PHONE"
		fails += 1

	var scrolls: String = "scrolls" if content_h > scroll_h + 1.0 else "fits"
	print("  %-16s kids %2d  card %4d  content %4d  budget %4d  desktop:%-7s phone:%-7s %s" % [
		name, content.get_child_count(), int(card_h), int(content_h), int(phone_budget), scrolls, on_phone, status])
	for s in small:
		print("        small target: %s" % s)
	for w in wide:
		print("        too wide: %s" % w)

func _walk(node: Node, small: Array[String], wide: Array[String], max_w: float) -> void:
	for c in node.get_children():
		if c is Button and c.visible:
			checked += 1
			var b: Button = c
			if b.name in EXEMPT:
				continue
			var h: float = maxf(b.size.y, b.custom_minimum_size.y)
			var w: float = maxf(b.size.x, b.custom_minimum_size.x)
			if h < TOUCH_MIN - 1.0 or w < TOUCH_MIN - 1.0:
				small.append("%s %.0fx%.0f (%s)" % [b.name, w, h, b.text.replace("\n", " ")])
		if c is Control and c.visible:
			var cw: float = (c as Control).get_combined_minimum_size().x
			if cw > max_w + 1.0:
				wide.append("%s needs %.0f > %.0f  [%s]" % [
					c.name, cw, max_w, _describe(c)])
		_walk(c, small, wide, max_w)

## Names the text inside a container so an overflow report points at the row
## that is actually too wide, not at an anonymous HBoxContainer.
func _describe(node: Node) -> String:
	var bits: Array[String] = []
	_collect_text(node, bits)
	return " | ".join(bits)

func _collect_text(node: Node, bits: Array[String]) -> void:
	for c in node.get_children():
		if c is Label and not (c as Label).text.is_empty():
			bits.append("%s(%.0f)" % [
				(c as Label).text.replace("
", " "),
				(c as Label).get_combined_minimum_size().x])
		elif c is Button and not (c as Button).text.is_empty():
			bits.append("[%s](%.0f)" % [
				(c as Button).text.replace("
", " "),
				(c as Button).get_combined_minimum_size().x])
		_collect_text(c, bits)
