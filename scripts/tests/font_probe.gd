extends Node

const UITheme = preload("res://scripts/ui/ui_theme.gd")

func _ready() -> void:
	var sample := "Continue Journey"
	var size := 48
	var widths := {}
	for w in [100, 400, 500, 600, 700, 900]:
		var f: Font = UITheme.get_ui_variation(w)
		if f == null:
			print("  FAIL  no font for weight %d" % w)
			get_tree().quit(1)
			return
		widths[w] = f.get_string_size(sample, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		print("  wght %3d -> width %.2f" % [w, widths[w]])
	var base: Font = UITheme.get_ui_font()
	print("  raw Outfit.ttf default -> width %.2f" % base.get_string_size(sample, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)

	var fails := 0
	if is_equal_approx(widths[100], widths[700]):
		print("  FAIL  weight axis has no effect - variations are not applying")
		fails += 1
	else:
		print("  PASS  weight axis changes metrics (%.1f -> %.1f)" % [widths[100], widths[700]])
	if widths[700] <= widths[100]:
		print("  FAIL  bold is not wider than thin")
		fails += 1
	else:
		print("  PASS  bold renders heavier than thin")

	var tracked: Font = UITheme.get_ui_variation(500, 2)
	var plain: Font = UITheme.get_ui_variation(500, 0)
	var tw := tracked.get_string_size(sample, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pw := plain.get_string_size(sample, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if tw > pw:
		print("  PASS  tracking widens the string (%.1f -> %.1f)" % [pw, tw])
	else:
		print("  FAIL  tracking had no effect")
		fails += 1

	print("Failures: %d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
