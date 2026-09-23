extends Node

## Throwaway probe: which non-CJK marks do the bundled faces actually carry?
## Used to pick replacements for the rack's Chinese glyphs.

const UITheme = preload("res://scripts/ui/ui_theme.gd")

const CANDIDATES: Array[String] = [
	"▶", "▸", "➤", "⏱", "◷", "◔", "◑", "⬡", "⬢", "⚙", "❖", "◆", "◇",
	"▦", "▩", "■", "◉", "○", "◎", "✦", "✧", "✿", "❀", "☀", "☾", "♦",
	"▲", "△", "⊞", "⊕", "⌂", "☷", "≡", "❚", "▮", "▪", "⯀", "⟡", "◈",
]

func _ready() -> void:
	var faces := {
		"ui": UITheme.get_ui_font(),
		"cjk": UITheme.get_cjk_font(),
		"title": UITheme.get_title_font(),
	}
	for c in CANDIDATES:
		var line := "  %s  " % c
		for key in faces:
			var f: Font = faces[key]
			line += "%s=%s " % [key, "Y" if (f != null and f.has_char(c.unicode_at(0))) else "-"]
		print(line)
	get_tree().quit(0)
