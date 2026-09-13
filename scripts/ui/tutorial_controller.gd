class_name TutorialController
extends CanvasLayer

## Nine Rivers (九河) — Interactive First-Time User Experience (FTUE) Tutorial
## Elegantly introduces the Principle of Freedom, Matching Pairs, and Flow Multipliers.

signal tutorial_finished()

var step: int = 0
var banner_panel: PanelContainer
var title_label: Label
var desc_label: Label
var action_btn: Button
var pointer: Control
var pointer_tween: Tween

const STEPS: Array[Dictionary] = [
	{
		"title": "🏮 The Principle of Freedom",
		"desc": "A tile is FREE if its left or right edge is unobstructed, and no tile rests directly upon it. Free tiles gleam with ceramic light; blocked tiles softly slumber in shade.",
		"btn": "Next: Matching →"
	},
	{
		"title": "🥢 Harmony of the Pairs",
		"desc": "Select two identical free tiles to match them. They dissolve into molten gold dust, freeing the trapped tiles beneath and behind them.",
		"btn": "Next: The Nine Flows →"
	},
	{
		"title": "🌊 The Flow of Nine Rivers",
		"desc": "Making successive matches without pausing increases your Flow Multiplier (×2, ×3 ... up to ×9 Overdrive!). Clear all tiles to complete the stage.",
		"btn": "Begin Journey ⛩️"
	}
]

func _ready() -> void:
	layer = 12
	visible = false
	_build_ui()

func _build_ui() -> void:
	banner_panel = PanelContainer.new()
	banner_panel.anchors_preset = Control.PRESET_BOTTOM_WIDE
	banner_panel.custom_minimum_size = Vector2(0, 260)
	banner_panel.offset_left = 32
	banner_panel.offset_right = -32
	banner_panel.offset_bottom = -120
	banner_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	
	var sb := UITheme.create_panel_box(Color(0.04, 0.14, 0.10, 0.98), UITheme.GOLD_CORE, 2, 18, 0.6)
	banner_panel.add_theme_stylebox_override("panel", sb)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	banner_panel.add_child(margin)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	
	title_label = Label.new()
	UITheme.style_label(title_label, "ui", 25, UITheme.GOLD_BRIGHT)
	vbox.add_child(title_label)
	
	desc_label = Label.new()
	UITheme.style_label(desc_label, "ui", 18, UITheme.IVORY_BASE)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(hbox)
	
	var skip_btn := Button.new()
	skip_btn.text = "Skip Tutorial"
	skip_btn.custom_minimum_size = Vector2(140, 56)
	UITheme.style_button(skip_btn, false, 12)
	skip_btn.add_theme_font_size_override("font_size", 18)
	skip_btn.pressed.connect(_finish_tutorial)
	hbox.add_child(skip_btn)
	
	action_btn = Button.new()
	action_btn.custom_minimum_size = Vector2(190, 56)
	UITheme.style_button(action_btn, true, 12)
	action_btn.add_theme_font_size_override("font_size", 18)
	action_btn.pressed.connect(_advance_step)
	hbox.add_child(action_btn)
	
	add_child(banner_panel)

func start_tutorial() -> void:
	step = 0
	visible = true
	_show_step(step)

func _show_step(s: int) -> void:
	if s >= STEPS.size():
		_finish_tutorial()
		return
		
	var data: Dictionary = STEPS[s]
	title_label.text = data["title"]
	desc_label.text = data["desc"]
	action_btn.text = data["btn"]
	
	banner_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(banner_panel, "modulate:a", 1.0, 0.2)

func _advance_step() -> void:
	AudioManager.play_click()
	step += 1
	if step < STEPS.size():
		_show_step(step)
	else:
		_finish_tutorial()

func _finish_tutorial() -> void:
	SaveManager.prog["tutorial_completed"] = true
	SaveManager.request_save()
	var tween := create_tween()
	tween.tween_property(banner_panel, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func():
		visible = false
		tutorial_finished.emit()
	)
