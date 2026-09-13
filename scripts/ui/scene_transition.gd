class_name SceneTransition
extends CanvasLayer

## Nine Rivers (九河) — Cinematic Screen Transition Controller
## Provides silky ink/water dissolve and cross-fading between screens.

signal fade_out_completed()
signal fade_in_completed()

var overlay: ColorRect
var is_transitioning: bool = false

func _ready() -> void:
	layer = 100 # Topmost layer
	overlay = ColorRect.new()
	overlay.name = "TransitionOverlay"
	overlay.anchors_preset = Control.PRESET_FULL_RECT
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.color = Color(0.02, 0.07, 0.05, 0.0)
	overlay.visible = false
	add_child(overlay)

func fade_to(action: Callable, duration: float = 0.28) -> void:
	if is_transitioning:
		action.call()
		return
		
	is_transitioning = true
	overlay.visible = true
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var tween := create_tween()
	tween.tween_property(overlay, "color:a", 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func():
		fade_out_completed.emit()
		action.call()
	)
	tween.tween_interval(0.05)
	tween.tween_property(overlay, "color:a", 0.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func():
		overlay.visible = false
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		is_transitioning = false
		fade_in_completed.emit()
	)
