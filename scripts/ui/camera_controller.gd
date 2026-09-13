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

var board_bounds := Rect2()

func _ready() -> void:
	zoom = Vector2(default_zoom, default_zoom)

func frame_board(bounds: Rect2, viewport_size: Vector2) -> void:
	board_bounds = bounds
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return
		
	# Top HUD is ~190px (including safe area notch), Bottom Props is ~230px
	var top_hud_h: float = 190.0
	var bot_props_h: float = 230.0
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

func handle_external_pan(_rel: Vector2) -> void:
	# Disabled: Board is solidly locked in place for mobile touch accuracy
	pass

func punch_camera(offset: Vector2) -> void:
	var orig_pos := position
	var tween := create_tween()
	tween.tween_property(self, "position", orig_pos + offset, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", orig_pos, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _unhandled_input(_event: InputEvent) -> void:
	# Disabled: Camera is locked to prevent accidental drifting or pinch-zooming on mobile touchscreens
	pass

func reset_to_fit() -> void:
	var center := board_bounds.position + board_bounds.size * 0.5
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position", center, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "zoom", Vector2(default_zoom, default_zoom), 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _clamp_position() -> void:
	if board_bounds.size == Vector2.ZERO:
		return
	var margin := Vector2(300, 400)
	var min_p := board_bounds.position - margin
	var max_p := board_bounds.end + margin
	position.x = clampf(position.x, min_p.x, max_p.x)
	position.y = clampf(position.y, min_p.y, max_p.y)
