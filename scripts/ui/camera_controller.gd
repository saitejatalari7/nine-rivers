class_name CameraController
extends Camera2D

var min_zoom: float = 0.5
var max_zoom: float = 2.0
var default_zoom: float = 1.0

var is_panning: bool = false
var pan_start_pos: Vector2 = Vector2.ZERO
var touch_points: Dictionary = {}
var initial_pinch_dist: float = 0.0
var initial_pinch_zoom: Vector2 = Vector2.ONE

var last_tap_time: float = 0.0

const UITheme = preload("res://scripts/ui/ui_theme.gd")

var board_bounds := Rect2()

func _ready() -> void:
	zoom = Vector2(default_zoom, default_zoom)

func frame_board(bounds: Rect2, viewport_size: Vector2) -> void:
	board_bounds = bounds
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return
		
	# Derived from the HUD, not guessed: TopBar now ends at 208 and PropsBar
	# starts 219 from the bottom, and both move again by the safe-area insets.
	# The old fixed 190/230 predate that and put the board under both bars.
	const TOP_BAR_END: float = 208.0
	const PROPS_BAR_H: float = 195.0
	var insets: Vector2 = UITheme.get_safe_insets(get_viewport())
	var top_hud_h: float = insets.x + TOP_BAR_END
	var bot_props_h: float = insets.y + PROPS_BAR_H
	var padding := Vector2(70.0, top_hud_h + bot_props_h + 40.0)
	var avail := viewport_size - padding
	var fit_x: float = avail.x / bounds.size.x
	var fit_y: float = avail.y / bounds.size.y
	# Fit board comfortably within the viewport while filling the screen
	var fit_scale: float = clampf(minf(fit_x, fit_y) * 0.95, 0.70, 3.5)
	
	default_zoom = fit_scale
	min_zoom = fit_scale * 0.75
	max_zoom = fit_scale * 2.8
	
	# Center the board in the actual playable area between the Top HUD and Bottom Props deck
	var center := bounds.position + bounds.size * 0.5
	var vertical_ui_bias: float = (top_hud_h - bot_props_h) * 0.5 / fit_scale
	center.y += vertical_ui_bias
	
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position", center, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "zoom", Vector2(fit_scale, fit_scale), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func handle_external_pan(rel: Vector2) -> void:
	if is_equal_approx(zoom.x, default_zoom):
		return
	position -= rel / zoom.x
	_clamp_position()

func punch_camera(offset: Vector2) -> void:
	var orig_pos := position
	var tween := create_tween()
	tween.tween_property(self, "position", orig_pos + offset, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", orig_pos, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## Zoom and pan are the recourse for a board whose tiles are small: pictorial
## layouts need width, and width costs tile size. Panning only engages once
## zoomed in, so a board that fits cannot be dragged off-screen by accident.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			touch_points[t.index] = t.position
		else:
			touch_points.erase(t.index)
			initial_pinch_dist = 0.0
		is_panning = touch_points.size() == 1
		return

	if event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		touch_points[d.index] = d.position
		if touch_points.size() >= 2:
			var pts: Array = touch_points.values()
			var dist: float = (pts[0] as Vector2).distance_to(pts[1] as Vector2)
			if initial_pinch_dist <= 0.0:
				initial_pinch_dist = dist
				initial_pinch_zoom = zoom
			elif dist > 0.0:
				var z: float = clampf(
					initial_pinch_zoom.x * (dist / initial_pinch_dist),
					min_zoom, max_zoom)
				zoom = Vector2(z, z)
				_clamp_position()
		elif is_panning:
			handle_external_pan(d.relative)
		return

	if event is InputEventMagnifyGesture:
		var m := event as InputEventMagnifyGesture
		var z: float = clampf(zoom.x * m.factor, min_zoom, max_zoom)
		zoom = Vector2(z, z)
		_clamp_position()

func reset_to_fit() -> void:
	var center := board_bounds.position + board_bounds.size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position", center, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "zoom", Vector2(default_zoom, default_zoom), 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _clamp_position() -> void:
	if board_bounds.size == Vector2.ZERO:
		return
	# Tight when zoomed in, loose at the fitted zoom, so the board cannot be
	# dragged out of view.
	var margin := Vector2(300, 400) / maxf(0.25, zoom.x / maxf(0.01, default_zoom))
	var min_p := board_bounds.position - margin
	var max_p := board_bounds.end + margin
	position.x = clampf(position.x, min_p.x, max_p.x)
	position.y = clampf(position.y, min_p.y, max_p.y)
