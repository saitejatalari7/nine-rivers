class_name HudController
extends CanvasLayer

## Nine Rivers (九河) — Product-Ready Luxury HUD Controller
## Obsidian-jade lacquer top bar, dragon river flow meter, and tactile talisman props bar.

signal menu_clicked()
signal undo_clicked()
signal hint_clicked()
signal shuffle_clicked()
signal pearls_clicked()

const UITheme = preload("res://scripts/ui/ui_theme.gd")


var calm_goals_label: Label
var btn_pearls: Button

@onready var readout_panel: PanelContainer = $TopBar/Readout
@onready var lbl_level: Label = $TopBar/Readout/StatsBox/LevelBox/ValLevel
@onready var lbl_score: Label = $TopBar/Readout/StatsBox/ScoreBox/ValScore
@onready var lbl_tiles: Label = $TopBar/Readout/StatsBox/TilesBox/ValTiles
@onready var lbl_sets: Label = $TopBar/Readout/StatsBox/SetsBox/ValSets

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
	
	# 2. Calm Mode 3-Star Live Objectives Header
	calm_goals_label = Label.new()
	calm_goals_label.name = "CalmGoals"
	calm_goals_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	calm_goals_label.anchors_preset = Control.PRESET_TOP_WIDE
	calm_goals_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Below TopBar, which now ends at 208; at 176 it sat on top of the readout.
	calm_goals_label.position = Vector2(28, 224)
	calm_goals_label.size = Vector2(get_viewport().get_visible_rect().size.x - 56, 38)
	calm_goals_label.add_theme_font_size_override("font_size", UITheme.FS_CAPTION)
	calm_goals_label.add_theme_color_override("font_color", Color(0.78, 0.90, 0.84, 0.95))
	add_child(calm_goals_label)
	
	# 3. Spirit Pearls Counter Pill in TopBar
	btn_pearls = Button.new()
	btn_pearls.name = "BtnPearls"
	btn_pearls.custom_minimum_size = Vector2(196, UITheme.TOUCH_MIN)
	btn_pearls.text = "◈ %d" % MonetizationManager.get_pearls()
	UITheme.style_button(btn_pearls, true, 16)
	btn_pearls.add_theme_font_size_override("font_size", UITheme.FS_BODY)
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
	readout_panel.add_theme_stylebox_override("panel", sb_readout)
	
	# 2. Menu Talisman Button
	UITheme.style_circular_button($TopBar/BtnMenu, UITheme.GOLD_CORE)
	$TopBar/BtnMenu.add_theme_font_size_override("font_size", 56)
	
	# 3. Action Props Buttons (Undo, Hint, Shuffle)
	UITheme.style_button(btn_undo, false, 18)
	UITheme.style_button(btn_hint, false, 18)
	UITheme.style_button(btn_shuffle, false, 18)
	btn_undo.add_theme_font_size_override("font_size", UITheme.FS_BODY)
	btn_hint.add_theme_font_size_override("font_size", UITheme.FS_BODY)
	btn_shuffle.add_theme_font_size_override("font_size", UITheme.FS_BODY)
	
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
	UITheme.style_label(lbl_level, "ui", 48, UITheme.GOLD_BRIGHT, UITheme.W_SEMIBOLD)
	UITheme.style_label(lbl_score, "ui", 48, UITheme.IVORY_BASE, UITheme.W_SEMIBOLD)
	UITheme.style_label(lbl_tiles, "ui", 48, UITheme.IVORY_BASE, UITheme.W_SEMIBOLD)
	UITheme.style_label(lbl_sets, "ui", 48, UITheme.IVORY_BASE, UITheme.W_SEMIBOLD)
	UITheme.style_label(lbl_clock, "ui", UITheme.FS_BODY, UITheme.IVORY_BASE)
	UITheme.style_label(lbl_flow, "ui", UITheme.FS_BODY, UITheme.GOLD_BRIGHT)
	UITheme.style_label(lbl_toast, "ui", UITheme.FS_BODY, UITheme.IVORY_BASE)
	
	for stat_lbl in [
		$TopBar/Readout/StatsBox/LevelBox/Lbl,
		$TopBar/Readout/StatsBox/ScoreBox/Lbl,
		$TopBar/Readout/StatsBox/TilesBox/Lbl,
		$TopBar/Readout/StatsBox/SetsBox/Lbl
	]:
		if is_instance_valid(stat_lbl):
			UITheme.style_label(stat_lbl, "ui", UITheme.FS_CAPTION, Color(0.65, 0.80, 0.73, 1),
				UITheme.W_MEDIUM, 2)
	
	if is_instance_valid(calm_goals_label):
		UITheme.style_label(calm_goals_label, "ui", UITheme.FS_CAPTION, Color(0.78, 0.90, 0.84, 0.95))

## Previously applied insets, so re-applying is idempotent. The old version
## did `position.y += inset` once in _ready(); running it a second time would
## have pushed the bar twice as far down.
var _applied_insets: Vector2 = Vector2.ZERO

func _apply_safe_area() -> void:
	var insets: Vector2 = UITheme.get_safe_insets(get_viewport())
	if insets.is_equal_approx(_applied_insets):
		return
	var delta := insets - _applied_insets
	_applied_insets = insets
	$TopBar.position.y += delta.x
	$PropsBar.position.y -= delta.y
	if is_instance_valid(calm_goals_label):
		calm_goals_label.position.y += delta.x
	for n in ["TimerWrap", "FlowBanner"]:
		var c := get_node_or_null(n)
		if c is Control:
			(c as Control).position.y += delta.x

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
			if is_instance_valid(calm_goals_label):
				calm_goals_label.visible = true
				update_calm_goals()
		GameManager.GameMode.RUN:
			lbl_level.text = "R" + str(level_no)
			timer_container.visible = true
			if is_instance_valid(calm_goals_label): calm_goals_label.visible = false
		GameManager.GameMode.DAILY:
			lbl_level.text = "DAILY"
			timer_container.visible = true
			if is_instance_valid(calm_goals_label): calm_goals_label.visible = false

func update_calm_goals() -> void:
	if not is_instance_valid(calm_goals_label) or not calm_goals_label.visible:
		return
	var s1 := "★ Clear Board"
	var s2 := "★ ≤2 Misplays" if GameManager.misplays <= 2 else "☆ >2 Misplays"
	var s3 := "★ No Props" if GameManager.props_used == 0 else "☆ Props Used"
	calm_goals_label.text = "%s   ·   %s   ·   %s" % [s1, s2, s3]

func update_board_stats(remaining_tiles: int, legal_moves: int) -> void:
	lbl_tiles.text = str(remaining_tiles)
	lbl_sets.text = str(legal_moves)
	if legal_moves == 0 and remaining_tiles > 0:
		lbl_sets.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	elif legal_moves <= 2 and remaining_tiles > 0:
		lbl_sets.add_theme_color_override("font_color", Color(1.0, 0.78, 0.35))
	else:
		lbl_sets.remove_theme_color_override("font_color")
	update_calm_goals()

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

func _on_props_updated(u: int, h: int, s: int) -> void:
	btn_undo.text = "Undo\n(%d)" % u if u > 0 else "Undo\n(+)"
	btn_undo.modulate.a = 0.65 if u <= 0 else 1.0
	btn_hint.text = "Hint\n(%d)" % h if h > 0 else "Hint\n(+)"
	btn_hint.modulate.a = 0.65 if h <= 0 else 1.0
	btn_shuffle.text = "Shuffle\n(%d)" % s if s > 0 else "Shuffle\n(+)"
	btn_shuffle.modulate.a = 0.65 if s <= 0 else 1.0
	update_calm_goals()

func show_toast(msg: String) -> void:
	lbl_toast.text = msg
	var t := create_tween()
	t.tween_property(toast_panel, "modulate:a", 1.0, 0.12)
	t.tween_interval(1.8)
	t.tween_property(toast_panel, "modulate:a", 0.0, 0.25)


func _on_pearls_changed(total: int) -> void:
	if is_instance_valid(btn_pearls):
		btn_pearls.text = "◈ %d" % total
