extends Node2D

const UITheme = preload("res://scripts/ui/ui_theme.gd")

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#0b1f18")
	bg.size = Vector2(1080, 900)
	add_child(bg)

	var rows := [
		["Pearl diamond", "◈  250 ◈  1,500 ◈"],
		["Menu bars / close", "☰    ✕"],
		["Flow segment (share text)", "▰▰▰▰"],
		["Stars, from Noto", "★★☆   0/30 ★"],
		["Inline, mixed faces", "250 ◈ · 1000 玉 · 0 日"],
		["Rupee: system fallback", "₹199 / $2.99"],
	]
	var y := 40.0
	for r in rows:
		var cap := Label.new()
		cap.position = Vector2(40, y)
		UITheme.style_label(cap, "ui", 26, Color("#7d8f88"), UITheme.W_MEDIUM, 2)
		cap.text = String(r[0]).to_upper()
		add_child(cap)

		var big := Label.new()
		big.position = Vector2(40, y + 30)
		UITheme.style_label(big, "ui", 64, Color("#f5e6c8"), UITheme.W_SEMIBOLD)
		big.text = String(r[1])
		add_child(big)
		y += 120.0

	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "res://assets/branding/screens/real_game/glyph_sheet.png"
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("  " + path)
	get_tree().quit(0)
