class_name FloatingChip
extends Node2D

@onready var label: Label = $Label

func setup(text: String, is_gold: bool = false) -> void:
	if not is_node_ready():
		await ready
	label.text = text
	if is_gold:
		label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
		label.add_theme_font_size_override("font_size", 30)
	else:
		label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.9))
		label.add_theme_font_size_override("font_size", 25)
		
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 45.0, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
