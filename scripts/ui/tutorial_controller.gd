extends CanvasLayer

## First-run onboarding, taught by doing.
##
## The previous version was three paragraphs of prose behind a Next button -
## "Free tiles gleam with ceramic light; blocked tiles softly slumber in shade"
## - which nobody reads and which never asks the player to do anything. A player
## could click through all of it and still not know what a free tile is.
##
## This is four beats, each completed by an action on the real board:
##
##   1. Tap two matching tiles          - the whole game, in one move
##   2. Tap a covered tile, see it stay  - what "free" means, felt rather than read
##   3. Match again to raise Flow        - the only live multiplier
##   4. Clear the board                  - hand back control
##
## Nothing advances on a button. The board is real, the tiles are the ones in
## play, and board.tutorial_focus keeps a wandering first-timer from walking out
## of the lesson. Skip is always present: a player who already knows Mahjong
## should not be held for thirty seconds.

signal tutorial_finished()

const UITheme = preload("res://scripts/ui/ui_theme.gd")
const RiverTile = preload("res://scripts/core/river_tile.gd")

## Each beat names what it wants and how it is satisfied. `focus` decides which
## tiles answer a tap while the beat is up.
##   pair    - a legal matching set; completed by matching it
##   covered - one blocked tile; completed by tapping it and feeling it refuse
##   free    - any legal set; completed by matching it
##   none    - nothing to point at; completed immediately, the board is theirs
const BEATS: Array[Dictionary] = [
	{
		"text": "Tap these two tiles to match them.",
		"sub": "Two tiles with the same face clear together.",
		"focus": "pair",
	},
	{
		"text": "Now tap the tile with something on top of it.",
		"sub": "It will not move. A tile has to be uncovered first.",
		"focus": "covered",
	},
	{
		"text": "Match another pair.",
		"sub": "Matches in a row build your Flow, worth more each time.",
		"focus": "free",
	},
	{
		"text": "That is all of it. Clear the board.",
		"sub": "",
		"focus": "none",
	},
]

var _beat: int = -1
var _board: Node = null
var _card: PanelContainer
var _line: Label
var _sub: Label
var _dots: Label
var _skip: Button
var _armed_covered: RiverTile = null


func _ready() -> void:
	layer = 12
	visible = false
	_build_ui()


func _build_ui() -> void:
	var wrap := MarginContainer.new()
	wrap.set_anchors_preset(Control.PRESET_TOP_WIDE)
	wrap.offset_top = 232.0
	wrap.offset_left = 28.0
	wrap.offset_right = -28.0
	wrap.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(wrap)

	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_PASS
	_card.add_theme_stylebox_override("panel",
		UITheme.create_panel_box(Color("#11191b"), UITheme.GOLD_CORE, 2, 16, 0.94))
	wrap.add_child(_card)

	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_theme_constant_override("separation", 6)
	_card.add_child(col)

	# PASS, not IGNORE: the Skip button lives in here and has to be tappable,
	# while the row itself must not swallow taps meant for the board.
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_PASS
	head.add_theme_constant_override("separation", 12)
	col.add_child(head)

	_line = Label.new()
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_label(_line, "ui", UITheme.FS_BODY_LG, UITheme.GOLD_BRIGHT, UITheme.W_SEMIBOLD)
	head.add_child(_line)

	_dots = Label.new()
	_dots.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UITheme.style_label(_dots, "ui", UITheme.FS_CAPTION, UITheme.IVORY_MUTED, UITheme.W_MEDIUM)
	head.add_child(_dots)

	# Inside the card, not floating over the HUD. Anchored top-right it landed
	# on the TILES and SETS readout, which is both ugly and a second tappable
	# thing in a place the player is already being asked to look away from.
	_skip = Button.new()
	_skip.text = "Skip"
	_skip.custom_minimum_size = Vector2(132, 96)
	UITheme.style_button(_skip, false, 12)
	_skip.add_theme_font_size_override("font_size", UITheme.FS_CAPTION)
	_skip.pressed.connect(_finish)
	UITheme.add_press_feedback(_skip)
	head.add_child(_skip)

	_sub = Label.new()
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_label(_sub, "ui", UITheme.FS_CAPTION, UITheme.IVORY_MUTED, UITheme.W_MEDIUM)
	col.add_child(_sub)



func start_tutorial(board: Node = null) -> void:
	_board = board
	visible = true
	_beat = -1
	_next_beat()


func _next_beat() -> void:
	_beat += 1
	if _beat >= BEATS.size():
		_finish()
		return

	var b: Dictionary = BEATS[_beat]
	_line.text = String(b["text"])
	_sub.text = String(b["sub"])
	_sub.visible = not _sub.text.is_empty()
	_dots.text = "%d/%d" % [_beat + 1, BEATS.size()]

	_card.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_card, "modulate:a", 1.0, 0.18)

	_apply_focus(String(b["focus"]))


## Points the beat at real tiles on the real board. A beat that cannot find what
## it needs is skipped rather than left hanging - a board where no tile happens
## to be covered is unusual but not impossible, and being stuck on step two of a
## tutorial is the worst outcome available.
func _apply_focus(kind: String) -> void:
	_armed_covered = null
	if _board == null:
		_next_beat_deferred()
		return
	_board.clear_all_hints()
	# Typed through a local: assigning an untyped [] to an Array[RiverTile] held
	# on a dynamically-typed reference is refused at runtime.
	var none: Array[RiverTile] = []
	_board.tutorial_focus = none

	match kind:
		"pair", "free":
			var sets: Array = _board.get_legal_sets()
			if sets.is_empty():
				_next_beat_deferred()
				return
			# The first beat says "two tiles with the same face", so it has to
			# point at two tiles with the same face. Flowers and seasons are
			# wild here and match anything, and sets[0] happily offered a flower
			# beside a character - a first lesson that contradicts its own text.
			var chosen: Array = _plain_pair(sets)
			if chosen.is_empty():
				chosen = sets[0]
			var focus: Array[RiverTile] = []
			for tile in chosen:
				focus.append(tile)
			_board.tutorial_focus = focus
			for tile in chosen:
				var v = _board.tile_views.get(tile)
				if is_instance_valid(v):
					v.set_hint(true)
		"covered":
			var covered: RiverTile = _find_covered()
			if covered == null:
				_next_beat_deferred()
				return
			_armed_covered = covered
			var one: Array[RiverTile] = [covered]
			_board.tutorial_focus = one
			var cv = _board.tile_views.get(covered)
			if is_instance_valid(cv):
				cv.set_hint(true)
		"none":
			pass


## A set of two identical, non-wild tiles, or empty if the board offers none.
func _plain_pair(sets: Array) -> Array:
	for s in sets:
		if s.size() != 2:
			continue
		var a: RiverTile = s[0]
		var b: RiverTile = s[1]
		if a.is_wild_suit() or b.is_wild_suit() or a.is_wild() or b.is_wild():
			continue
		if a.suit == b.suit and a.rank == b.rank:
			return s
	return []


func _find_covered() -> RiverTile:
	var active: Array = _board.get_active_tiles()
	var grid: Dictionary = _board.get_spatial_grid(active)
	for tile in active:
		if _board.get_tile_blocked_reason(tile, grid) == "covered":
			return tile
	return null


func _next_beat_deferred() -> void:
	call_deferred("_next_beat")


## Beat two is complete the moment the player tries the covered tile and it
## refuses. Nothing is matched, so move_completed never fires - the board's
## rejection toast is the signal.
func notify_blocked_tap(tile: RiverTile) -> void:
	if not visible or _armed_covered == null:
		return
	if tile == _armed_covered:
		_armed_covered = null
		_next_beat()


func notify_match() -> void:
	if not visible:
		return
	if _beat < BEATS.size() and String(BEATS[_beat]["focus"]) in ["pair", "free"]:
		_next_beat()


func _finish() -> void:
	if _board != null:
		var clear: Array[RiverTile] = []
		_board.tutorial_focus = clear
		_board.clear_all_hints()
	SaveManager.prog["tutorial_completed"] = true
	SaveManager.request_save()
	var t := create_tween()
	t.tween_property(_card, "modulate:a", 0.0, 0.16)
	t.tween_callback(func():
		visible = false
		tutorial_finished.emit()
	)
