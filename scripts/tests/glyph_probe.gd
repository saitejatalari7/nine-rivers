extends Node

## Every symbol the interface prints inline must come from a BUNDLED font.
## Anything that falls through to the device is drawn differently per vendor,
## which is what removing the emoji was meant to stop.

const UITheme = preload("res://scripts/ui/ui_theme.gd")

## Collected from the source: the non-ASCII characters that appear inside
## printed strings, excluding CJK (which Noto Serif SC covers wholesale).
const REQUIRED: Array[String] = [
	"◈", "✕", "▰",
	"★", "☆", "·", "•", "×", "›", "—",
]
const NAMES: Array[String] = [
	"pearl diamond", "close cross", "flow segment",
	"star filled", "star hollow", "middot", "bullet", "times", "chevron", "em dash",
]

## Deliberately absent from our fonts - see tools/make_ui_glyphs.py.
const DELIBERATE_SYSTEM_FALLBACK: String = "₹"

func _ready() -> void:
	var faces := {
		"ui": UITheme.get_ui_font(),
		"cjk": UITheme.get_cjk_font(),
		"title": UITheme.get_title_font(),
	}
	var fails := 0
	for key in faces:
		var f: Font = faces[key]
		if f == null:
			print("  FAIL  face '%s' did not load" % key)
			fails += 1
			continue
		var missing: Array[String] = []
		for i in range(REQUIRED.size()):
			if not _covered(f, REQUIRED[i]):
				missing.append(NAMES[i])
		if missing.is_empty():
			print("  PASS  %-5s covers all %d symbols (incl. fallbacks)" % [key, REQUIRED.size()])
		else:
			print("  FAIL  %-5s cannot render: %s" % [key, ", ".join(missing)])
			fails += 1

	# 玉 appears inside Latin-face labels ("%d 玉"), so the UI face must reach
	# the CJK font too.
	if _covered(UITheme.get_ui_font(), "玉"):
		print("  PASS  ui    reaches CJK for inline 玉")
	else:
		print("  FAIL  ui    cannot render inline 玉")
		fails += 1

	if _covered(UITheme.get_ui_font(), DELIBERATE_SYSTEM_FALLBACK):
		print("  NOTE  a bundled font now covers U+20B9 - re-read the note in")
		print("        tools/make_ui_glyphs.py before relying on it")

	print("Failures: %d" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func _covered(f: Font, ch: String) -> bool:
	if f.has_char(ch.unicode_at(0)):
		return true
	for fb in f.fallbacks:
		if fb != null and _covered(fb, ch):
			return true
	return false
