extends CanvasLayer

## First-run onboarding, taught by doing, on boards of its own.
##
## This used to run on stage 1: four captions laid over the player's real first
## level, the last of which said "clear the board" - thirty-six tiles of
## homework before they had decided they wanted to play. Quitting halfway left
## stage 1 half-played, and it taught by BLOCKING every tile except the answer,
## which is coercion rather than instruction.
##
## Now it is three small boards of its own, each teaching one rule and each
## ending in a win, then a card about stars. Nothing here is a level: no score,
## no timer, no props, no stars, and the player's progress is not touched. See
## tutorial_boards.gd for the boards and why they are hand-authored.
##
## Skip is present from the first frame. Someone who has played mahjong before
## should not be held for a minute to be told what a pair is.

signal tutorial_finished()

const UITheme = preload("res://scripts/ui/ui_theme.gd")
const RiverTile = preload("res://scripts/core/river_tile.gd")

const TutorialBoards = preload("res://scripts/ui/tutorial_boards.gd")

## One beat per board, plus a closing card with no board at all. `board` is the
## layout to deal; a beat with none is read and dismissed.
const BEATS: Array[Dictionary] = [
	{
		"text": "Tap two tiles with the same face.",
		"sub": "They clear together. That is the whole game.",
		"board": "A",
	},
	{
		"text": "Some tiles will not lift.",
		"sub": "A tile needs a clear side and nothing on top. Take the ones on the ends first.",
		"board": "B",
	},
	{
		"text": "Flowers and seasons are wild.",
		"sub": "A wild tile matches any tile at all. Pair each one with a tile that has no partner.",
		"board": "W",
	},
	{
		"text": "A gold underline means three.",
		"sub": "Those tiles clear in threes, not pairs. Tap all three of a kind.",
		"board": "T",
	},
	{
		"text": "Clear the top to reach what is under it.",
		"sub": "Tiles stack in layers. The flower on top is still wild.",
		"board": "C",
	},
	{
		"text": "Three stars for a clean board.",
		"sub": "One for clearing it, one for two mistakes or fewer, one for using no undo, hint or shuffle.",
		"board": "",
	},
]

var _beat: int = -1
var _board: Node = null
var _card: PanelContainer
var _line: Label
var _sub: Label
var _dots: Label
var _skip: Button
var _done: Button = null
var _col: VBoxContainer = null


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

	_col = VBoxContainer.new()
	_col.mouse_filter = Control.MOUSE_FILTER_PASS
	_col.add_theme_constant_override("separation", 6)
	_card.add_child(_col)

	# PASS, not IGNORE: the Skip button lives in here and has to be tappable,
	# while the row itself must not swallow taps meant for the board.
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_PASS
	head.add_theme_constant_override("separation", 12)
	_col.add_child(head)

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
	_col.add_child(_sub)



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

	_deal(String(b["board"]))


## Lays out the beat's board. The closing card has none, so it takes an empty
## board and a button rather than a match to move on.
func _deal(which: String) -> void:
	if _board == null:
		return
	var layout: Array = []
	match which:
		"A": layout = TutorialBoards.A_MATCH
		"B": layout = TutorialBoards.B_BLOCKED
		"W": layout = TutorialBoards.W_WILD
		"T": layout = TutorialBoards.T_TRIPLE
		"C": layout = TutorialBoards.C_LAYERS
		_:
			_board.clear_board()
			_show_done_button()
			return
	_hide_done_button()
	# duplicate(true): restore_stage reads these dictionaries into live tiles,
	# and the constants must survive being played through more than once.
	_board.restore_stage(layout.duplicate(true))
	_frame_board()


## The tutorial boards are a tenth the size of a real one, so the camera has to
## be told - left alone it keeps the framing of whatever was on screen before
## and these sit as a postage stamp in the middle.
func _frame_board() -> void:
	var cam = _board.get_parent().get_node_or_null("Camera2D")
	if cam != null and cam.has_method("frame_board"):
		cam.frame_board(_board.board_bounds, get_viewport().get_visible_rect().size)


func _show_done_button() -> void:
	if _done != null:
		_done.visible = true
		return
	_done = Button.new()
	_done.text = "Play"
	_done.custom_minimum_size = Vector2(0, UITheme.TOUCH_MIN)
	UITheme.style_button(_done, true, 16)
	_done.pressed.connect(_finish)
	UITheme.add_press_feedback(_done)
	_col.add_child(_done)


func _hide_done_button() -> void:
	if _done != null:
		_done.visible = false


## Beat two is complete the moment the player tries the covered tile and it
## refuses. Nothing is matched, so move_completed never fires - the board's
## rejection toast is the signal.
func notify_blocked_tap(_tile: RiverTile) -> void:
	return


## A beat is finished when its board is empty - not when a particular pair is
## matched. The player can clear these in any order they like, which is the
## point: they are being taught, not steered.
func notify_match() -> void:
	if not visible or _board == null:
		return
	if _board.get_active_tiles().is_empty():
		call_deferred("_next_beat")


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
