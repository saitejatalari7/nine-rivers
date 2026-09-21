extends Node

## Fails if any HUD control that is not meant to be tapped sits over the board
## and still accepts input.
##
## modulate.a = 0 hides a Control but does not stop it eating clicks, and a
## PanelContainer or a BoxContainer defaults to MOUSE_FILTER_STOP. Between them
## TimerWrap and FlowBanner were swallowing taps across the top ~115px of every
## board - FlowBanner permanently, because it is only ever faded and never
## hidden. Nothing in the game announced that; it just felt like dead tiles.
##
## Only the props buttons and the menu button are allowed to intercept, and
## only where they sit. Everything else in the band the camera gives the board
## has to be transparent to input.

const TOP_BAR_END: float = 208.0
const PROPS_BAR_H: float = 195.0
## Names permitted to accept input anywhere; these are the real controls.
const INTERACTIVE: Array[String] = ["BtnMenu", "BtnUndo", "BtnHint", "BtnShuffle"]

var _fails: int = 0


func _ready() -> void:
	await get_tree().process_frame
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = true
	await get_tree().create_timer(1.4).timeout
	# The HUD starts hidden behind the main menu, and an invisible Control is
	# skipped by the check below - which is how the first version of this
	# harness passed while the bug it was written for was still in the scene.
	# A board has to actually be up for the audit to mean anything.
	var board = main.get_node("Board")
	main.get_node("Modal").hide_modal()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260921
	board.load_stage("turtle", rng)
	board.visible = true
	main.get_node("HUD").visible = true
	GameManager.flow_updated.emit(4, "bam", false)
	await get_tree().create_timer(0.6).timeout
	if not main.get_node("HUD").visible:
		print("HUD never became visible - audit is meaningless, failing")
		get_tree().quit(1)
		return

	var vp: Vector2 = get_viewport().get_visible_rect().size
	var board_band := Rect2(0.0, TOP_BAR_END, vp.x, vp.y - PROPS_BAR_H - TOP_BAR_END)
	print("")
	print("board band: y %.0f .. %.0f" % [board_band.position.y, board_band.end.y])
	print("node                      filter  rect")

	var hud := main.get_node("HUD")
	_walk(hud, board_band)

	print("")
	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _walk(n: Node, band: Rect2) -> void:
	for child in n.get_children():
		if child is Control:
			_check(child as Control, band)
		_walk(child, band)


func _check(c: Control, band: Rect2) -> void:
	if c.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return
	if c.name in INTERACTIVE:
		return
	var r := Rect2(c.global_position, c.size)
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	if not r.intersects(band):
		return
	# visible = false genuinely stops input, so a hidden node is not a fault.
	# Anything that is merely transparent is, which is the whole point.
	if not c.is_visible_in_tree():
		return
	_fails += 1
	print("%-25s %-7s (%.0f,%.0f %.0fx%.0f)  BLOCKS THE BOARD" % [
		c.name, str(c.mouse_filter), r.position.x, r.position.y, r.size.x, r.size.y])
