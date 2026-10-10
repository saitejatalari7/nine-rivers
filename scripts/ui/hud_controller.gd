class_name HudController
extends CanvasLayer

## Nine Rivers — Product-Ready Luxury HUD Controller
## Obsidian-jade lacquer top bar, dragon river flow meter, and tactile talisman props bar.

signal menu_clicked()
signal undo_clicked()
signal hint_clicked()
signal shuffle_clicked()
signal pearls_clicked()

const UITheme = preload("res://scripts/ui/ui_theme.gd")


var btn_pearls: Button

@onready var readout_panel: PanelContainer = $TopBar/Readout
@onready var lbl_level: Label = $TopBar/Readout/StatsBox/LevelBox/ValLevel
@onready var lbl_score: Label = $TopBar/Readout/StatsBox/ScoreBox/ValScore

## The readout and the props bar were both taken to three quarters of their old
## size. They are reference, not action - the board is what the player is
## looking at - and at full size they framed it rather than sat beside it.
const HUD_SCALE: float = 0.75
const HUD_FS: int = int(UITheme.FS_BODY * HUD_SCALE)
## Top bar height: pause, pearls and the stage/score readout share it.
const TOP_H: float = 104.0
## The props bar sits just above the gesture handle. The theme's 48dp bottom
## floor is for menus; here it left the bar floating with 220px of dead
## screen below it.
const PROPS_H: float = 84.0
const PROPS_GAP: float = 20.0
const PROPS_BOTTOM_FLOOR: float = 48.0
## Space kept clear between the HUD and the nearest tile.
const BAND_GAP: float = 12.0

@onready var timer_container: Control = $TimerWrap
@onready var time_bar: ProgressBar = $TimerWrap/Bar
@onready var lbl_clock: Label = $TimerWrap/ClockText

@onready var flow_banner: PanelContainer = $FlowBanner
@onready var lbl_flow: Label = $FlowBanner/FlowLabel

@onready var btn_undo: Button = $PropsBar/BtnUndo
@onready var btn_hint: Button = $PropsBar/BtnHint
@onready var btn_shuffle: Button = $PropsBar/BtnShuffle

@onready var toast_panel: PanelContainer = $Toast
@onready var lbl_toast: Label = $Toast/ToastLabel

var display_score: int = 0
var target_score: int = 0
var _last_warn_second: int = -1

func _ready() -> void:
	_init_dynamic_hud_elements()
	_apply_luxury_theme()

	$TopBar/BtnMenu.pressed.connect(func(): menu_clicked.emit())
	btn_undo.pressed.connect(func(): undo_clicked.emit())
	btn_hint.pressed.connect(func(): hint_clicked.emit())
	btn_shuffle.pressed.connect(func(): shuffle_clicked.emit())

	GameManager.score_updated.connect(_on_score_updated)
	GameManager.flow_updated.connect(_on_flow_updated)
	GameManager.time_updated.connect(_on_time_updated)
	GameManager.elapsed_updated.connect(_on_elapsed_updated)
	GameManager.props_updated.connect(_on_props_updated)

	flow_banner.modulate.a = 0.0
	toast_panel.modulate.a = 0.0

	# Android delivers window insets after the first frame, so a call during
	# _ready() reports the full screen and reserves nothing. Apply now for the
	# floor, again next frame for the real values, and on every resize
	# thereafter (rotation, split screen, keyboard).
	_apply_safe_area()
	get_tree().get_root().size_changed.connect(_apply_safe_area)
	await get_tree().process_frame
	_apply_safe_area()

func _init_dynamic_hud_elements() -> void:
	# 1. Relics Bar for Timed Run Mode

	# 3. Spirit Pearls Counter Pill in TopBar
	btn_pearls = Button.new()
	btn_pearls.name = "BtnPearls"
	btn_pearls.custom_minimum_size = Vector2(147, TOP_H)
	btn_pearls.text = "◈ %d" % MonetizationManager.get_pearls()
	UITheme.style_button(btn_pearls, true, 16)
	btn_pearls.add_theme_font_size_override("font_size", HUD_FS)
	btn_pearls.pressed.connect(func(): pearls_clicked.emit())
	SaveManager.pearls_changed.connect(_on_pearls_changed)
	$TopBar.add_child(btn_pearls)
	$TopBar.move_child(btn_pearls, 1) # Positioned between Menu and Readout

	MonetizationManager.pearls_updated.connect(func(bal):
		if is_instance_valid(btn_pearls):
			btn_pearls.text = "◈ %d" % bal
	)

func _apply_luxury_theme() -> void:
	# 1. Top Readout Lacquer Panel
	var sb_readout := UITheme.create_panel_box(Color("#071914"), UITheme.GOLD_MUTED, 1, 18, 0.45)
	sb_readout.content_margin_left = 20
	sb_readout.content_margin_right = 20
	readout_panel.add_theme_stylebox_override("panel", sb_readout)

	# 2. Menu Talisman Button
	UITheme.style_circular_button($TopBar/BtnMenu, UITheme.GOLD_CORE)
	# Two bars as nodes, not a glyph: this button is the pause control, and every
	# pause codepoint is either missing or coloured emoji on some Android fonts.
	for bar in $TopBar/BtnMenu/Glyph.get_children():
		(bar as ColorRect).color = UITheme.GOLD_CORE

	# 3. Action Props Buttons (Undo, Hint, Shuffle)
	UITheme.style_button(btn_undo, false, 18)
	UITheme.style_button(btn_hint, false, 18)
	UITheme.style_button(btn_shuffle, false, 18)
	btn_undo.add_theme_font_size_override("font_size", HUD_FS)
	btn_hint.add_theme_font_size_override("font_size", HUD_FS)
	btn_shuffle.add_theme_font_size_override("font_size", HUD_FS)

	# 4. Timer Bar Styling
	var sb_timer_bg := StyleBoxFlat.new()
	sb_timer_bg.bg_color = Color("#061611")
	sb_timer_bg.border_color = Color(0.2, 0.32, 0.28, 0.6)
	sb_timer_bg.set_border_width_all(1)
	sb_timer_bg.set_corner_radius_all(6)
	sb_timer_bg.anti_aliasing = true
	time_bar.add_theme_stylebox_override("background", sb_timer_bg)

	var sb_timer_fill := StyleBoxFlat.new()
	sb_timer_fill.bg_color = UITheme.GOLD_CORE
	sb_timer_fill.set_corner_radius_all(6)
	sb_timer_fill.anti_aliasing = true
	time_bar.add_theme_stylebox_override("fill", sb_timer_fill)

	# 5. Flow Banner Styling
	var sb_flow := UITheme.create_panel_box(Color("#1a1506"), UITheme.GOLD_CORE, 2, 18, 0.5)
	flow_banner.add_theme_stylebox_override("panel", sb_flow)

	# 6. Toast Styling
	var sb_toast := UITheme.create_panel_box(Color("#081d17"), UITheme.GOLD_CORE, 2, 16, 0.5)
	toast_panel.add_theme_stylebox_override("panel", sb_toast)

	# 7. Bundled Font Typography
	UITheme.style_label(lbl_level, "ui", 40, UITheme.GOLD_BRIGHT, UITheme.W_SEMIBOLD)
	UITheme.style_label(lbl_score, "ui", 40, UITheme.IVORY_BASE, UITheme.W_SEMIBOLD)
	UITheme.style_label(lbl_clock, "ui", UITheme.FS_BODY, UITheme.IVORY_BASE)
	UITheme.style_label(lbl_flow, "ui", UITheme.FS_BODY, UITheme.GOLD_BRIGHT)
	UITheme.style_label(lbl_toast, "ui", UITheme.FS_BODY, UITheme.IVORY_BASE)

	for stat_lbl in [
		$TopBar/Readout/StatsBox/LevelBox/Lbl,
		$TopBar/Readout/StatsBox/ScoreBox/Lbl
	]:
		if is_instance_valid(stat_lbl):
			UITheme.style_label(stat_lbl, "ui", 26, Color(0.65, 0.80, 0.73, 1),
				UITheme.W_MEDIUM, 2)


## Previously applied insets, so re-applying is idempotent. The old version
## did `position.y += inset` once in _ready(); running it a second time would
## have pushed the bar twice as far down.
var _applied_insets: Vector2 = Vector2.ZERO

func _apply_safe_area() -> void:
	var bottom: float = UITheme.get_safe_insets(get_viewport(), PROPS_BOTTOM_FLOOR).y
	$PropsBar.offset_bottom = -(bottom + PROPS_GAP)
	$PropsBar.offset_top = $PropsBar.offset_bottom - PROPS_H
	var insets: Vector2 = UITheme.get_safe_insets(get_viewport())
	if insets.is_equal_approx(_applied_insets):
		return
	var delta := insets - _applied_insets
	_applied_insets = insets
	$TopBar.position.y += delta.x
	for n in ["TimerWrap", "FlowBanner"]:
		var c := get_node_or_null(n)
		if c is Control:
			(c as Control).position.y += delta.x

## The strip of screen the board may use: from below the top bar (and the
## timer, when a mode shows one) to above the props bar. Measured from the
## laid-out controls, so it stays right whatever the insets or the HUD do.
func play_band() -> Vector2:
	var top: float = $TopBar.get_global_rect().end.y
	if timer_container.visible:
		top = maxf(top, timer_container.get_global_rect().end.y)
	var bottom: float = $PropsBar.get_global_rect().position.y
	return Vector2(top + BAND_GAP, bottom - BAND_GAP)

func _process(delta: float) -> void:
	if display_score != target_score:
		var step: int = int(ceil(abs(target_score - display_score) * 12.0 * delta))
		if display_score < target_score:
			display_score = mini(target_score, display_score + step)
		else:
			display_score = maxi(target_score, display_score - step)
		lbl_score.text = str(display_score)

func setup_hud(mode: GameManager.GameMode, level_no: int) -> void:
	match mode:
		GameManager.GameMode.CALM:
			lbl_level.text = "L" + str(level_no)
			timer_container.visible = false
		GameManager.GameMode.RUN:
			lbl_level.text = "%d/3" % level_no
			timer_container.visible = true
		GameManager.GameMode.DAILY:
			lbl_level.text = "DAILY"
			timer_container.visible = true
	# A stopwatch has nothing to fill, so the daily shows the clock alone.
	time_bar.visible = mode != GameManager.GameMode.DAILY
	lbl_clock.remove_theme_color_override("font_color")

func _on_score_updated(new_score: int, _delta: int) -> void:
	target_score = new_score

## How long the flow banner stays up before fading on its own.
const FLOW_BANNER_HOLD: float = 1.6
var _flow_fade: Tween = null

func _on_flow_updated(flow: int, suit_name: String, is_overdrive: bool) -> void:
	if flow < 2:
		if is_instance_valid(_flow_fade):
			_flow_fade.kill()
		var t := create_tween()
		t.tween_property(flow_banner, "modulate:a", 0.0, 0.15)
		return

	var suit_display := ""
	match suit_name:
		"dot": suit_display = "Circles"
		"bam": suit_display = "Bamboo"
		"char": suit_display = "Characters"
		"wind": suit_display = "Winds"
		"dragon": suit_display = "Dragons"
		_: suit_display = "Wilds"

	if is_overdrive:
		lbl_flow.text = "FLOW OVERDRIVE ×%d · %s" % [flow, suit_display]
		lbl_flow.add_theme_color_override("font_color", UITheme.GOLD_BRIGHT)
	else:
		lbl_flow.text = "Flow ×%d · %s" % [flow, suit_display]
		lbl_flow.add_theme_color_override("font_color", UITheme.GOLD_CORE)

	# Fades itself out rather than sitting over the board for as long as the
	# flow lasts. It is mouse_filter IGNORE now so it no longer eats taps, but
	# a panel parked on the top rows is still in the way of reading them.
	if is_instance_valid(_flow_fade):
		_flow_fade.kill()
	var tween := create_tween()
	tween.tween_property(flow_banner, "modulate:a", 1.0, 0.15)
	_flow_fade = create_tween()
	_flow_fade.tween_interval(FLOW_BANNER_HOLD)
	_flow_fade.tween_property(flow_banner, "modulate:a", 0.0, 0.45)
	# Pulse banner scale on flow advance
	flow_banner.pivot_offset = flow_banner.size * 0.5
	var pop_tween := create_tween()
	pop_tween.tween_property(flow_banner, "scale", Vector2(1.08, 1.08), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(flow_banner, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

func _on_time_updated(time_left: float, max_time: float) -> void:
	time_bar.max_value = max_time
	time_bar.value = time_left
	var mins := int(time_left / 60.0)
	var secs := int(fmod(time_left, 60.0))
	lbl_clock.text = "%d:%02d" % [mins, secs]
	if time_left < 20.0:
		lbl_clock.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	else:
		lbl_clock.remove_theme_color_override("font_color")

	if time_left <= 15.0 and time_left > 0.0:
		var current_sec := int(ceil(time_left))
		if current_sec != _last_warn_second:
			_last_warn_second = current_sec
			AudioManager.play_tick_warn()
	elif time_left > 15.0:
		_last_warn_second = -1

func _on_elapsed_updated(elapsed: float) -> void:
	lbl_clock.text = format_clock(elapsed)

static func format_clock(seconds: float) -> String:
	var s: int = int(seconds)
	return "%d:%02d" % [s / 60, s % 60]

func _on_props_updated(u: int, h: int, s: int) -> void:
	btn_undo.text = "Undo  %d" % u if u > 0 else "Undo  +"
	btn_undo.modulate.a = 0.65 if u <= 0 else 1.0
	btn_hint.text = "Hint  %d" % h if h > 0 else "Hint  +"
	btn_hint.modulate.a = 0.65 if h <= 0 else 1.0
	btn_shuffle.text = "Shuffle  %d" % s if s > 0 else "Shuffle  +"
	btn_shuffle.modulate.a = 0.65 if s <= 0 else 1.0

func show_toast(msg: String) -> void:
	lbl_toast.text = msg
	var t := create_tween()
	t.tween_property(toast_panel, "modulate:a", 1.0, 0.12)
	t.tween_interval(1.8)
	t.tween_property(toast_panel, "modulate:a", 0.0, 0.25)


func _on_pearls_changed(total: int) -> void:
	if is_instance_valid(btn_pearls):
		btn_pearls.text = "◈ %d" % total
