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
	await _check_reachability()
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
	# Every back this audit drives would otherwise quit the moment it reaches the
	# main menu, taking the audit down with it. Attempts are still counted.
	main.quit_suppressed = true
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	modal = main.get_node("Modal")
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
	# The timed modes are capped per day, and this file starts several of them.
	# Clearing the counters keeps the audit about navigation; the caps have their
	# own test.
	SaveManager.prog["last_daily_date"] = ""
	SaveManager.prog["rapids_runs_today"] = 0
	SaveManager.prog["last_rapids_date"] = ""
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
		# The buttons that start a mode also close the menu; calling the start
		# function directly does not, and a stale modal left up here reads as the
		# screen state for the whole flow.
		modal.hide_modal()
		await _settle()

## The seed screens. Anything else reachable from them is discovered and
## explored by the worklist below.
func _seed_paths() -> Array:
	return [
		{"builder": "show_main_menu", "args": []},
		{"builder": "show_level_select", "args": []},
		{"builder": "show_pause_menu", "args": [], "pre": "calm"},
		{"builder": "show_level_clear", "args": [12, 4820, 3], "pre": "calm", "after_clear": true},
		{"builder": "show_daily_clear", "args": [3100, 7, 4], "pre": "daily", "after_clear": true},
		{"builder": "show_game_over", "args": ["No moves remain"], "pre": "run", "after_clear": true},
		{"builder": "show_bazaar_modal", "args": []},
		{"builder": "show_tile_catalog_modal", "args": []},
		{"builder": "show_tile_detail_modal", "args": ["theme_imperial_gold"]},
		{"builder": "show_background_catalog_modal", "args": []},
		{"builder": "show_background_detail_modal", "args": ["moonlit_river"]},
		{"builder": "show_treasury_modal", "args": []},
		{"builder": "show_settings_menu", "args": []},
		{"builder": "show_privacy_modal", "args": []},
		{"builder": "show_credits_modal", "args": []},
	]

## Replays a path from a clean home state so a state can be revisited.
func _goto(path: Dictionary) -> bool:
	await _reset()
	await _apply_pre(String(path.get("pre", "")))
	# Only the reward screens follow _on_board_cleared(), which hides the HUD.
	# Seeding them with it up gave daily_clear seven buttons where a player sees
	# two; hiding it everywhere instead invented a pause->resume state with no
	# HUD, which no player can reach either.
	if bool(path.get("after_clear", false)):
		hud.visible = false
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

	# The main menu is the root, so back should arm an exit rather than navigate.
	# Godot quits on the back gesture by default, which closed the game mid-board
	# until quit_on_go_back was turned off; the exit now lives here instead.
	if ProjectSettings.get_setting("application/config/quit_on_go_back", true):
		_fail("quit_on_go_back is on: the Android back gesture closes the game "
			+ "instead of opening the pause menu.")
	# Back leaves the game from the main menu and only from there. It is the
	# Android convention and nothing is lost: no board is in play here. What must
	# not happen is back navigating somewhere unexpected instead.
	#
	# The quit itself is suppressed - an audit that really quit would take itself
	# down at this line and report nothing.
	await _goto({"builder": "show_main_menu", "args": []})
	var before: int = main.quit_attempts
	main._handle_back_action()
	await _settle()
	if _state_key() != HOME:
		_fail("main menu: back moved off the main menu; it should quit, not navigate.")
	elif main.quit_attempts == before:
		_fail("main menu: back did nothing; it should quit the game.")
	else:
		print("  main menu: back quits rather than navigating (verified)")

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
	var shuffles: int = 0
	while not _cleared and clicks < MAX_CLICKS:
		var sets: Array = board.get_legal_sets()
		if sets.is_empty():
			# This branch does not consume a click, so MAX_CLICKS cannot bound
			# it. shuffle_remaining_tiles() only refuses below two tiles, so a
			# blocked board with tiles left shuffled forever and the run hung
			# until the outer timeout killed it.
			if shuffles >= 8 or not board.shuffle_remaining_tiles():
				return false
			shuffles += 1
			await get_tree().process_frame
			continue
		for t in _best_set(sets):
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

## Naive first-set play stalls on the denser boards - the layout validator puts
## greedy at 2-5 clears out of 12 on tier 3+ - which made the daily flow look
## broken when it is only hard. This is bot_runner's heuristic: take the
## deepest set, avoid spending wilds, prefer the flow suit.
func _best_set(sets: Array) -> Array:
	var best: Array = sets[0]
	var best_score: float = -1000000.0
	for st in sets:
		var sc: float = 0.0
		for t in st:
			sc += float(t.z) * 10.0
			if t.is_wild():
				sc -= 25.0
		if st.size() >= 3:
			sc += 8.0
		if not st.is_empty() and st[0].suit == GameManager.flow_suit:
			sc += 5.0
		if sc > best_score:
			best_score = sc
			best = st
	return best


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
		# Rapids no longer stops for a relic draft: a cleared stage leads straight
		# to the next board, so there is no reward screen to carry on from and the
		# check is that the next stage actually arrives with its HUD.
		{"name": "Timed Rapids (Run)", "pre": "run", "expect": "board+hud",
			"go_on": "", "auto_carries": true},
		# The daily has no continue row by design - it is one board a day - so
		# the check is that it lands home, not that it carries on.
		{"name": "The Daily Tide", "pre": "daily", "expect": "modal:daily_clear",
			"go_on": "", "ends_run": true},
	]:
		await _reset()
		await _apply_pre(String(flow["pre"]))
		var tiles: int = board.live_tiles.size()
		var ok: bool = await _clear_board()
		if not ok:
			_fail("%s: greedy play could not clear the board, so the reward screen and the carry-on path were never exercised." % flow["name"])
			continue
		await _settle()
		if bool(flow.get("auto_carries", false)):
			# No reward screen to sample: this mode deals the next stage after a
			# short beat, so sampling immediately catches the gap in between.
			await get_tree().create_timer(1.8).timeout
			await _settle()
		var reward: String = _state_key()
		print("  %-26s %3d tiles -> %s" % [flow["name"], tiles, reward])
		if reward != flow["expect"]:
			_fail("%s: clearing the board led to %s, expected %s." % [
				flow["name"], reward, flow["expect"]])
			continue

		# Carry on the way a player would, then check they are not stranded.
		if bool(flow.get("ends_run", false)):
			# Terminal screen: assert the player can get home rather than on.
			var home: bool = await _press_labelled("main menu")
			if not home:
				_fail("%s: the reward screen has no way back to the main menu." % flow["name"])
			else:
				await _settle()
				print("        ends run -> %s" % _state_key())
				if _state_key() != "modal:main":
					_fail("%s: leaving the reward screen did not land on the main menu." % flow["name"])
			continue

		var carried: bool = false
		if bool(flow.get("auto_carries", false)):
			# Already carried: the wait above let the next stage deal itself.
			carried = true
		elif not String(flow["go_on"]).is_empty():
			carried = await _press_labelled(String(flow["go_on"]))
		if not carried:
			_fail("%s: nothing on the reward screen carried the player onward, so the state after continuing was never checked." % flow["name"])
			continue

		var after: String = _state_key()
		print("        carried on -> %s" % after)
		if after == "board-NOHUD":
			_fail("%s: after carrying on, the board is dealt with the HUD hidden — no menu button, no timer, no props, and no on-screen way back to the main menu." % flow["name"])
		elif after == "nothing-visible":
			_fail("%s: after carrying on, nothing is on screen at all." % flow["name"])

	await _reset()

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
