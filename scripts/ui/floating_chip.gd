class_name FloatingChip
extends Node2D

@onready var label: Label = $Label

func setup(text: String, is_gold: bool = false) -> void:
	if not is_node_ready():
		await ready
	label.text = text
	# An outline, so the number reads over tile dust and bright faces alike.
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.10, 0.08, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	# A second line is a bonus (Combo, Koi): bigger, and it stays longer.
	var bonus: bool = text.contains("\n")
	var life: float = 1.1 if bonus else 0.65
	if is_gold:
		label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
		label.add_theme_font_size_override("font_size", 34 if bonus else 30)
	else:
		label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.9))
		label.add_theme_font_size_override("font_size", 25)

	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 45.0, life).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
