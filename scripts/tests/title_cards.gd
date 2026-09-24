extends Node

## Three title treatments, built from the game's own pond, tiles and type
## rather than painted separately. Whatever is chosen has to look like the game
## it opens, and the current splash is the only art in the project that does
## not come from the renderer.
##
## Run: godot --path . --rendering-driver opengl3 res://scenes/title_cards.tscn

const TileViewScene = preload("res://scenes/tile.tscn")
const RiverTile = preload("res://scripts/core/river_tile.gd")
const TileLighting = preload("res://scripts/ui/tile_lighting.gd")
const UITheme = preload("res://scripts/ui/ui_theme.gd")

var main: Node2D
var overlay: CanvasLayer
var _card: int = 0


func _ready() -> void:
	await get_tree().process_frame
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	main.get_node("HUD").visible = false
	SaveManager.prog["tutorial_completed"] = true
	await get_tree().create_timer(1.2).timeout
	main.get_node("Modal").hide_modal()

	overlay = CanvasLayer.new()
	overlay.layer = 50
	add_child(overlay)

	await _card_a_rack()
	await _card_b_ink()
	await _card_c_board()
	get_tree().quit(0)


## A: three tiles standing on the pond, the way the rack reads on the menu.
func _card_a_rack() -> void:
	main.get_node("Board").clear_board()
	_clear_overlay()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	row.position = Vector2(540, 1120)
	overlay.add_child(row)
	for s in [["dot", 9], ["bam", 1], ["char", 1]]:
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(64 * 4.2, 84 * 4.2)
		row.add_child(holder)
		var v = TileViewScene.instantiate()
		holder.add_child(v)
		v.setup(RiverTile.new(0, 0, 0, String(s[0]), int(s[1])), true)
		v.pivot_offset = Vector2.ZERO
		v.scale = Vector2(4.2, 4.2)
	row.position = Vector2(540 - 430, 860)
	_title(320, true)
	await _shot("title_a_rack")


## B: type alone on the felt. The quietest of the three, and the only one that
## survives being shown at thumbnail size in a store listing.
func _card_b_ink() -> void:
	main.get_node("Board").clear_board()
	_clear_overlay()
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(64 * 6.0, 84 * 6.0)
	holder.position = Vector2(540 - 64 * 3.0, 1000)
	overlay.add_child(holder)
	var v = TileViewScene.instantiate()
	holder.add_child(v)
	v.setup(RiverTile.new(0, 0, 0, "char", 9), true)
	v.pivot_offset = Vector2.ZERO
	v.scale = Vector2(6.0, 6.0)
	_title(560, false)
	await _shot("title_b_ink")


## C: the real board, shot as a hero. What the player actually gets.
func _card_c_board() -> void:
	_clear_overlay()
	main._start_calm_mode(14)
	await get_tree().create_timer(1.2).timeout
	# _start_calm_mode turns the HUD back on, and the modifier toast lands a
	# moment later. A title card is the board, not the furniture around it.
	main.get_node("HUD").visible = false
	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.09, 0.07, 0.55)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(scrim)
	_title(380, true)
	await _shot("title_c_board")


func _title(y: float, with_tagline: bool) -> void:
	var t := Label.new()
	t.text = "NINE RIVERS"
	t.size = Vector2(1080, 160)
	t.position = Vector2(0, y)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(t, "ui", 128, UITheme.GOLD_CORE, UITheme.W_SEMIBOLD, 6)
	overlay.add_child(t)
	if not with_tagline:
		return
	var s := Label.new()
	s.text = "MAHJONG SOLITAIRE"
	s.size = Vector2(1080, 60)
	s.position = Vector2(0, y + 170)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(s, "ui", 44, UITheme.IVORY_MUTED, UITheme.W_MEDIUM, 8)
	overlay.add_child(s)


func _clear_overlay() -> void:
	for c in overlay.get_children():
		c.queue_free()


func _shot(name: String) -> void:
	await get_tree().create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	var p := "res://assets/branding/screens/real_game/%s.png" % name
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(p))
	print("  " + p)
