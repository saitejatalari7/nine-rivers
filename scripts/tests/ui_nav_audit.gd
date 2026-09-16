extends Node

## Nine Rivers — UI Navigation Audit
##
## Boots the real main.tscn and walks the interface as a player would: it opens
## every screen, presses every on-screen control, and records where each press
## landed. The result is a state graph, which is then searched to answer the one
## question a player cares about — "can I always get back to the main menu?"
##
## Two reachabilities are computed separately:
##   on-screen  - following only real controls the player can see and tap
##   with-back  - additionally allowing the Android back gesture
## A state that is only escapable with the hardware back button is a trap on a
## gesture-navigation phone, so on-screen failures are errors.
##
## Run: godot --headless --audio-driver Dummy --path . scenes/ui_nav_audit.tscn

const UITheme = preload("res://scripts/ui/ui_theme.gd")

const MAX_STATES: int = 48
const MAX_PRESSES: int = 420
## Stage tokens in the level grid are all the same control; probing every one
## would dominate the run without testing anything new.
const MAX_BUTTONS_PER_STATE: int = 18

var main: Node2D
var modal: Node
var sanctuary: Control
var hud: CanvasLayer
var board: Node

var fails: Array[String] = []
var notes: Array[String] = []
var presses: int = 0

## state key -> {"path": {...}, "edges": {target: label}, "back": target, "buttons": int}
var graph: Dictionary = {}

func _ready() -> void:
	await _boot()
	await _explore()
	_audit_daily_layouts()
	await _audit_live_flows()
	await _audit_sanctuary_view()
	_check_reachability()
	_report()
	get_tree().quit(1 if not fails.is_empty() else 0)

# ---------------------------------------------------------------- boot

func _boot() -> void:
	SaveManager.prog["tutorial_completed"] = true
	# Mid-campaign: the level map needs unlocked chapters to draw a grid, and the
	# bazaar needs a purse so buy rows are live rather than uniformly disabled.
	SaveManager.prog["level"] = 6
	SaveManager.prog["stars"] = {"1": 3, "2": 3, "3": 2, "4": 3, "5": 1}
	SaveManager.prog["river_jade"] = 9000
	# Pristine entitlements, or a theme bought during an earlier run of this
	# harness would leave the catalogue's buy rows untested for good.
	SaveManager.economy["pearls"] = 5000
	SaveManager.economy["no_ads_purchased"] = false
	SaveManager.economy["unlocked_themes"] = ["classic_jade"]
	SaveManager.economy["active_tile_theme"] = "classic_jade"
	SaveManager.economy["unlocked_background_themes"] = ["emerald_pond", "moonlit_river", "autumn_stream"]
	SaveManager.economy["active_background_theme"] = "auto"
	SaveManager.economy["entitlement_source"] = {}
	SaveManager.economy["rewarded_ads_today"] = 0
	SaveManager.economy["last_rewarded_date"] = ""
	SaveManager.sanctuary["koi_unlocked"] = ["kohaku"]
	SaveManager.sanctuary["decorations"] = ["bamboo_fountain"]
	_snapshot_profile()

	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	modal = main.get_node("Modal")
	sanctuary = main.get_node("SanctuaryLayer/Sanctuary")
	hud = main.get_node("HUD")
	board = main.get_node("Board")

	# The splash tween finishes by calling _return_home(), which would silently
	# replace whatever screen is being measured.
	var splash: Node = main.get_node_or_null("SplashScreen")
	if splash != null:
		splash.visible = false
	await get_tree().create_timer(1.2).timeout

	print("viewport: %s" % get_viewport().get_visible_rect().size)

# ---------------------------------------------------------------- state

func _state_key() -> String:
	if is_instance_valid(sanctuary) and sanctuary.visible:
		return "sanctuary_view"
	if modal.visible:
		return "modal:%s" % modal._current_screen
	if board.visible:
		return "board+hud" if hud.visible else "board-NOHUD"
	return "nothing-visible"

## hide_modal() fades over 0.12s and only clears `visible` in its tween
## callback, so a shorter wait would sample the screen mid-transition and read a
## still-open modal as closed.
func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout
	await get_tree().process_frame

## Probing presses every control, including ones that spend jade and pearls. The
## profile is rolled back before each replay so that walking the same path twice
## always builds the same screen; without this a purchase made early in the
## sweep silently removes the buy rows a later replay expects to press.
var _profile: Dictionary = {}

func _snapshot_profile() -> void:
	_profile = {
		"prog": SaveManager.prog.duplicate(true),
		"economy": SaveManager.economy.duplicate(true),
		"sanctuary": SaveManager.sanctuary.duplicate(true),
		"mastery": SaveManager.tile_mastery.duplicate(true),
	}

func _restore_profile() -> void:
	if _profile.is_empty():
		return
	SaveManager.prog = (_profile["prog"] as Dictionary).duplicate(true)
	SaveManager.economy = (_profile["economy"] as Dictionary).duplicate(true)
	SaveManager.sanctuary = (_profile["sanctuary"] as Dictionary).duplicate(true)
	SaveManager.tile_mastery = (_profile["mastery"] as Dictionary).duplicate(true)

func _reset() -> void:
	_restore_profile()
	main._return_home()
	await _settle()

## Walks the live tree for controls the player could actually tap. CanvasLayer
## breaks Control.is_visible_in_tree(), so ancestor visibility is checked by hand.
func _collect_buttons() -> Array:
	var out: Array = []
	_walk_buttons(main, out)
	return out

func _walk_buttons(node: Node, out: Array) -> void:
	for c in node.get_children():
		if "visible" in c and not c.visible:
			continue
		if c is Button:
			var b: Button = c
			if not b.disabled and b.size.x > 0.5 and b.size.y > 0.5:
				out.append(b)
		_walk_buttons(c, out)

func _label_of(b: Button) -> String:
	if not b.text.is_empty():
		return b.text.replace("\n", " ")
	var bits: Array[String] = []
	_collect_label_text(b, bits)
	if bits.is_empty():
		return b.name
	return " / ".join(bits)

func _collect_label_text(node: Node, bits: Array[String]) -> void:
	for c in node.get_children():
		if c is Label and not (c as Label).text.is_empty():
			bits.append((c as Label).text.replace("\n", " "))
		_collect_label_text(c, bits)

# ---------------------------------------------------------------- exploration

## Puts the game into the mode a screen is really reached from, so "resume" and
## "next stage" have a board to return to rather than an empty pond.
func _apply_pre(mode: String) -> void:
	match mode:
		"calm":
			main._start_calm_mode(3)
		"run":
			main._start_run_mode()
		"daily":
			main._start_daily_mode()
	if not mode.is_empty():
		await _settle()

## The seed screens. Anything else reachable from them is discovered and
## explored by the worklist below.
func _seed_paths() -> Array:
	return [
		{"builder": "show_main_menu", "args": []},
		{"builder": "show_level_select", "args": []},
		{"builder": "show_pause_menu", "args": [], "pre": "calm"},
		{"builder": "show_level_clear", "args": [12, 4820, 3], "pre": "calm"},
		{"builder": "show_daily_clear", "args": [3100, 7, 4], "pre": "daily"},
		{"builder": "show_boon_draft", "args": [], "pre": "run"},
		{"builder": "show_game_over", "args": ["No moves remain"], "pre": "run"},
		{"builder": "show_sanctuary_menu", "args": []},
		{"builder": "show_bazaar_modal", "args": []},
		{"builder": "show_tile_catalog_modal", "args": []},
		{"builder": "show_tile_detail_modal", "args": ["theme_imperial_gold"]},
		{"builder": "show_background_catalog_modal", "args": []},
		{"builder": "show_background_detail_modal", "args": ["moonlit_river"]},
		{"builder": "show_treasury_modal", "args": []},
		{"builder": "show_daily_offerings_modal", "args": []},
		{"builder": "show_settings_menu", "args": []},
		{"builder": "show_privacy_modal", "args": []},
		{"builder": "show_credits_modal", "args": []},
	]

## Replays a path from a clean home state so a state can be revisited.
func _goto(path: Dictionary) -> bool:
	await _reset()
	await _apply_pre(String(path.get("pre", "")))
	modal.callv(path["builder"], path["args"])
	await _settle()
	for idx in path.get("presses", []):
		var btns: Array = _collect_buttons()
		if idx >= btns.size():
			return false
		btns[idx].pressed.emit()
		presses += 1
		await _settle()
	return true

func _explore() -> void:
	var worklist: Array = _seed_paths()
	var seen_builders: Dictionary = {}

	while not worklist.is_empty() and graph.size() < MAX_STATES and presses < MAX_PRESSES:
		var path: Dictionary = worklist.pop_front()
		var ok: bool = await _goto(path)
		if not ok:
			continue
		var key: String = _state_key()

		# A screen builder that leaves nothing on screen is broken on arrival.
		if path.get("presses", []).is_empty():
			var b_name: String = path["builder"]
			if not seen_builders.has(b_name):
				seen_builders[b_name] = true
				if key == "nothing-visible":
					_fail("%s() builds its content but never shows the modal — the screen is invisible." % b_name)

		if graph.has(key):
			continue

		var entry: Dictionary = {"path": path, "edges": {}, "back": "", "buttons": 0, "dead": []}
		graph[key] = entry

		# Where does the Android back gesture lead from here?
		main._handle_back_action()
		await _settle()
		entry["back"] = _state_key()

		# Now every on-screen control, each from a fresh replay of this state.
		await _goto(path)
		var n: int = _collect_buttons().size()
		entry["buttons"] = n
		var limit: int = mini(n, MAX_BUTTONS_PER_STATE)

		for i in range(limit):
			if presses >= MAX_PRESSES:
				break
			await _goto(path)
			var btns: Array = _collect_buttons()
			if i >= btns.size():
				break
			var btn: Button = btns[i]
			var label: String = _label_of(btn)
			var before: String = _state_key()

			if btn.pressed.get_connections().is_empty():
				entry["dead"].append(label)
				_fail("%s: control '%s' is wired to nothing — pressing it does nothing at all." % [key, label])
				continue

			btn.pressed.emit()
			presses += 1
			await _settle()
			var after: String = _state_key()

			if after == "nothing-visible":
				_fail("%s: pressing '%s' leaves a blank screen with no UI at all." % [key, label])

			if after != before:
				entry["edges"][after] = label
				if not graph.has(after) and graph.size() + worklist.size() < MAX_STATES:
					var child: Dictionary = {
						"builder": path["builder"], "args": path["args"],
						"pre": path.get("pre", ""),
						"presses": (path.get("presses", []) as Array) + [i]
					}
					worklist.append(child)

	await _reset()

# ---------------------------------------------------------------- reachability

const HOME: String = "modal:main"

func _reachable_set(use_back: bool) -> Dictionary:
	# Reverse BFS from the main menu over the recorded edges.
	var incoming: Dictionary = {}
	for src in graph:
		var e: Dictionary = graph[src]
		var targets: Array = (e["edges"] as Dictionary).keys()
		if use_back and not String(e["back"]).is_empty():
			targets.append(e["back"])
		for t in targets:
			if not incoming.has(t):
				incoming[t] = []
			(incoming[t] as Array).append(src)

	var reached: Dictionary = {HOME: true}
	var queue: Array = [HOME]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		for src in incoming.get(cur, []):
			if not reached.has(src):
				reached[src] = true
				queue.append(src)
	return reached

func _check_reachability() -> void:
	var on_screen: Dictionary = _reachable_set(false)
	var with_back: Dictionary = _reachable_set(true)

	print("")
	print("---- state graph (%d states, %d presses) ----" % [graph.size(), presses])
	for key in graph:
		var e: Dictionary = graph[key]
		var tag := "ok"
		if not on_screen.has(key):
			tag = "NO ON-SCREEN WAY HOME"
		elif not with_back.has(key):
			tag = "UNREACHABLE"
		print("  %-26s buttons %2d  back->%-22s %s" % [
			key, e["buttons"], e["back"], tag])
		for t in (e["edges"] as Dictionary):
			print("        '%s' -> %s" % [(e["edges"] as Dictionary)[t], t])

	for key in graph:
		if key == HOME:
			continue
		if not on_screen.has(key):
			if with_back.has(key):
				_fail("%s is a dead end on screen: the only way out is the Android back gesture." % key)
			else:
				_fail("%s is a hard dead end: neither a control nor the back gesture leads home." % key)

	if String((graph.get(HOME, {}) as Dictionary).get("back", "")) == HOME:
		_note("main menu: the back gesture does nothing (does not offer to exit the app).")

# ---------------------------------------------------------------- daily tide

## The Daily Tide used to hardcode one 40-tile shape, so the date changed the
## deal but never the board. This checks the date now chooses the shape, that it
## chooses the same one every time, and that a year of dates covers the pool.
func _audit_daily_layouts() -> void:
	var pool: Array = main.daily_layout_pool()
	print("")
	print("---- daily tide ----")
	print("  pool (%d shapes): %s" % [pool.size(), ", ".join(pool)])

	if pool.is_empty():
		_fail("The Daily Tide has no layouts to choose from.")
		return

	var seen: Dictionary = {}
	for day in range(365):
		var seed_value: int = 20250101 + day
		var a: String = main.daily_layout_for_seed(seed_value)
		var b: String = main.daily_layout_for_seed(seed_value)
		if a != b:
			_fail("The Daily Tide is not deterministic: seed %d gave %s then %s." % [
				seed_value, a, b])
			return
		if not pool.has(a):
			_fail("The Daily Tide chose '%s', which is not in its own pool." % a)
			return
		seen[a] = int(seen.get(a, 0)) + 1

	print("  a year of dates visits %d of %d shapes" % [seen.size(), pool.size()])
	for name in seen:
		print("      %-14s %3d days" % [name, seen[name]])

	if seen.size() < mini(pool.size(), 4):
		_fail("The Daily Tide only ever deals %d distinct shapes across a year." % seen.size())
	if pool.size() < 4:
		_note("Only %d shapes are large enough for the Daily Tide; it will repeat often." % pool.size())

# ---------------------------------------------------------------- live flows

## The screen-by-screen sweep drives modals directly. This plays the real thing:
## deal a board, clear it by clicking tiles, and check the reward screen leaves
## the player somewhere they can still steer from.
const MAX_CLICKS: int = 4000

var _cleared: bool = false

func _clear_board() -> bool:
	_cleared = false
	if not board.board_cleared.is_connected(_on_cleared):
		board.board_cleared.connect(_on_cleared)
	var clicks: int = 0
	while not _cleared and clicks < MAX_CLICKS:
		var sets: Array = board.get_legal_sets()
		if sets.is_empty():
			if not board.shuffle_remaining_tiles():
				return false
			await get_tree().process_frame
			continue
		for t in sets[0]:
			var view = board.tile_views.get(t)
			if not is_instance_valid(view):
				break
			if t.is_frozen:
				board._on_tile_clicked(view)
			if t.is_removed or not is_instance_valid(view):
				break
			board._on_tile_clicked(view)
			clicks += 1
		await get_tree().process_frame
	return _cleared

func _on_cleared() -> void:
	_cleared = true

## Presses the first control whose label contains `needle`.
func _press_labelled(needle: String) -> bool:
	for b in _collect_buttons():
		if _label_of(b).to_lower().contains(needle.to_lower()):
			b.pressed.emit()
			presses += 1
			await _settle()
			return true
	return false

func _audit_live_flows() -> void:
	print("")
	print("---- live flows ----")

	for flow in [
		{"name": "Continue Journey (Calm)", "pre": "calm", "expect": "modal:level_clear",
			"go_on": "next stage"},
		{"name": "Timed Rapids (Run)", "pre": "run", "expect": "modal:boon_draft",
			"go_on": ""},
		{"name": "The Daily Tide", "pre": "daily", "expect": "modal:daily_clear",
			"go_on": ""},
	]:
		await _reset()
		await _apply_pre(String(flow["pre"]))
		var tiles: int = board.live_tiles.size()
		var ok: bool = await _clear_board()
		if not ok:
			_note("%s: could not be cleared by greedy play; reward screen not exercised." % flow["name"])
			continue
		await _settle()
		var reward: String = _state_key()
		print("  %-26s %3d tiles -> %s" % [flow["name"], tiles, reward])
		if reward != flow["expect"]:
			_fail("%s: clearing the board led to %s, expected %s." % [
				flow["name"], reward, flow["expect"]])
			continue

		# Carry on the way a player would, then check they are not stranded.
		var carried: bool = false
		if not String(flow["go_on"]).is_empty():
			carried = await _press_labelled(String(flow["go_on"]))
		else:
			var btns: Array = _collect_buttons()
			# The boon draft's relics carry no button text; take the first one.
			if reward == "modal:boon_draft" and not btns.is_empty():
				btns[0].pressed.emit()
				presses += 1
				await _settle()
				carried = true
		if not carried:
			continue

		var after: String = _state_key()
		print("        carried on -> %s" % after)
		if after == "board-NOHUD":
			_fail("%s: after carrying on, the board is dealt with the HUD hidden — no menu button, no timer, no props, and no on-screen way back to the main menu." % flow["name"])
		elif after == "nothing-visible":
			_fail("%s: after carrying on, nothing is on screen at all." % flow["name"])

	await _reset()

# ---------------------------------------------------------------- sanctuary

func _audit_sanctuary_view() -> void:
	await _reset()
	main._open_sanctuary()
	await _settle()

	if not sanctuary.visible:
		_fail("Koi Sanctuary did not open from the main menu.")
		return

	var checked: Array = [
		["TopBar/BtnBack", sanctuary.get_node_or_null("TopBar/BtnBack")],
		["BottomBar/BtnShop", sanctuary.get_node_or_null("BottomBar/BtnShop")],
		["ShopDrawer/Body/DrawerHead/BtnCloseShop", sanctuary.get_node_or_null("ShopDrawer/Body/DrawerHead/BtnCloseShop")],
	]
	for pair in checked:
		var c: Control = pair[1]
		if c == null:
			_fail("Sanctuary: %s is missing." % pair[0])
			continue
		var w: float = maxf(c.size.x, c.custom_minimum_size.x)
		var h: float = maxf(c.size.y, c.custom_minimum_size.y)
		if h < UITheme.TOUCH_MIN - 1.0 or w < UITheme.TOUCH_MIN - 1.0:
			_fail("Sanctuary: %s is %.0fx%.0f, under the %.0f touch minimum." % [
				pair[0], w, h, UITheme.TOUCH_MIN])

	var small_type: Array[String] = []
	_walk_font_sizes(sanctuary, small_type)
	for s in small_type:
		_fail("Sanctuary: %s" % s)

	var top_bar: Control = sanctuary.get_node_or_null("TopBar")
	if top_bar != null:
		var insets: Vector2 = UITheme.get_safe_insets(get_viewport())
		var need: float = maxf(insets.x, UITheme.SAFE_TOP_FLOOR)
		if top_bar.offset_top < need - 1.0:
			_fail("Sanctuary: TopBar sits at %.0f, inside the %.0f status-bar inset." % [
				top_bar.offset_top, need])

	# Open the shop drawer, then confirm it closes and the screen still exits.
	var drawer: Control = sanctuary.get_node("ShopDrawer")
	drawer.visible = false
	await _settle()
	sanctuary.get_node("BottomBar/BtnShop").pressed.emit()
	await _settle()
	if not drawer.visible:
		_fail("Sanctuary: the shop button did not open the shop drawer.")
	sanctuary.get_node("ShopDrawer/Body/DrawerHead/BtnCloseShop").pressed.emit()
	await _settle()
	if drawer.visible:
		_fail("Sanctuary: the shop drawer's close button did not close it.")

	sanctuary.get_node("TopBar/BtnBack").pressed.emit()
	await _settle()
	if _state_key() != HOME:
		_fail("Sanctuary: Back landed on %s instead of the main menu." % _state_key())

func _walk_font_sizes(node: Node, out: Array[String]) -> void:
	for c in node.get_children():
		if c is Label and not (c as Label).text.is_empty() and (c as Label).visible:
			var fs: int = (c as Label).get_theme_font_size("font_size")
			if fs > 0 and fs < UITheme.FS_CAPTION:
				out.append("'%s' is set at %dpx (%.1fsp), under the %dpx floor." % [
					(c as Label).text.replace("\n", " "), fs, fs / 3.0, UITheme.FS_CAPTION])
		_walk_font_sizes(c, out)

# ---------------------------------------------------------------- report

func _fail(msg: String) -> void:
	if not fails.has(msg):
		fails.append(msg)

func _note(msg: String) -> void:
	if not notes.has(msg):
		notes.append(msg)

func _report() -> void:
	print("")
	if not notes.is_empty():
		print("---- notes ----")
		for n in notes:
			print("  - %s" % n)
		print("")
	if fails.is_empty():
		print("==================================================")
		print("--- UI NAVIGATION AUDIT PASSED: every screen has a way home. ---")
		print("==================================================")
	else:
		print("---- %d navigation failures ----" % fails.size())
		for f in fails:
			print("  [FAIL] %s" % f)
