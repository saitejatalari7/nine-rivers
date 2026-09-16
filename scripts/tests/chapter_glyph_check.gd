extends Node

const StagePlan = preload("res://scripts/core/stage_plan.gd")
const UITheme = preload("res://scripts/ui/ui_theme.gd")

func _ready() -> void:
	var fails := 0
	for c in range(StagePlan.CHAPTERS):
		var text: String = StagePlan.chapter_subtitle(c) + StagePlan.chapter_title(c)
		for i in range(text.length()):
			var ch := text.unicode_at(i)
			if ch < 128:
				continue
			if not _covered(UITheme.get_ui_font(), ch):
				print("  FAIL  chapter %d uses U+%04X which no bundled font has" % [c, ch])
				fails += 1
	if fails == 0:
		print("  PASS  all %d chapter names render from bundled fonts" % StagePlan.CHAPTERS)
	print("Failures: %d" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func _covered(f: Font, ch: int) -> bool:
	if f == null:
		return false
	if f.has_char(ch):
		return true
	for fb in f.fallbacks:
		if fb != null and _covered(fb, ch):
			return true
	return false
