extends Node

## Measures built layout across every modal screen; the logic suites never look
## at geometry.

const UITheme = preload("res://scripts/ui/ui_theme.gd")

const TOUCH_MIN: float = 144.0
## From modal.tscn. Measure against this, not the card's actual size: a child
## wider than the card just stretches it, so that check can never fail.
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
	# The splash tween ends by calling _return_home(), which would replace the
	# screen being measured part-way through. Wait it out.
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

	# Minimum-size checks miss row insets, and containers overflow rather than
	# clip, so measure where the text actually landed.
	var card_left: float = card.global_position.x
	var card_right: float = card_left + card.size.x
	if sb != null:
		card_left += sb.get_margin(SIDE_LEFT)
		card_right -= sb.get_margin(SIDE_RIGHT)
	var spilled: Array[String] = []
	_walk_bounds(content, spilled, card_left, card_right)
	for sp in spilled:
		wide.append(sp)

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

	# Headless pins the viewport square, so measure against a real phone.
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

## Measures the INK, not the label rect: a centred full-width label has a rect
## as wide as the card while its text sits in the middle.
const EDGE_TOLERANCE: float = 1.5

func _walk_bounds(node: Node, out: Array[String], card_left: float, card_right: float) -> void:
	for c in node.get_children():
		if c is Label and c.visible and not (c as Label).text.is_empty():
			_check_label(c as Label, out, card_left, card_right)
		_walk_bounds(c, out, card_left, card_right)

func _check_label(lbl: Label, out: Array[String], card_left: float, card_right: float) -> void:
	var font: Font = lbl.get_theme_font("font")
	if font == null:
		return
	var fs: int = lbl.get_theme_font_size("font_size")
	var text_w: float = font.get_string_size(
		lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if lbl.autowrap_mode != TextServer.AUTOWRAP_OFF:
		text_w = minf(text_w, lbl.size.x)

	var left: float = lbl.global_position.x
	match lbl.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			left += (lbl.size.x - text_w) * 0.5
		HORIZONTAL_ALIGNMENT_RIGHT:
			left += lbl.size.x - text_w
	var right: float = left + text_w
	var label: String = lbl.text.replace("
", " ")

	if right > card_right + EDGE_TOLERANCE or left < card_left - EDGE_TOLERANCE:
		out.append("'%s' clipped by the card (ink %.0f..%.0f vs %.0f..%.0f)" % [
			label, left, right, card_left, card_right])
		return

	var row := lbl.get_parent()
	while row != null and not (row is BoxContainer):
		row = row.get_parent()
	if row is Control:
		var rc: Control = row
		var row_right: float = rc.global_position.x + rc.size.x
		if right > row_right + EDGE_TOLERANCE:
			out.append("'%s' pushed out of its row (ink ends %.0f, row ends %.0f)" % [
				label, right, row_right])
