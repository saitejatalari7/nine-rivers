extends Node

## Fast preview for the tile lighting constants. Renders one strip per theme
## instead of the full 288-tile sheet, and reads the light settings from the
## environment so a value can be tried without editing source.

const TileViewScene = preload("res://scenes/tile.tscn")
const RiverTile = preload("res://scripts/core/river_tile.gd")
const TileLighting = preload("res://scripts/ui/tile_lighting.gd")

const THEMES: Array[String] = [
	"classic_jade", "theme_imperial_gold", "theme_obsidian_ink", "theme_cherry_blossom",
]
## Test-only body swap: poked straight into TileView._body_tex_cache so an
## alternative body can be previewed without editing BODY_TEX_FILES.
const BODY_OVERRIDE := "TUNE_BODY"
const PROBES: Array[Dictionary] = [
	{"suit": "char", "rank": 1}, {"suit": "dot", "rank": 1}, {"suit": "dot", "rank": 5},
	{"suit": "bam", "rank": 1}, {"suit": "wind", "rank": 1}, {"suit": "dragon", "rank": 1},
]
const SCALE: int = 3
const PAD: int = 6


func _ready() -> void:
	await get_tree().process_frame
	_apply_body_override()
	var tw: int = int(TileView.TILE_W) * SCALE
	var th: int = int(TileView.TILE_H) * SCALE
	var sheet := Image.create(
		PAD + PROBES.size() * (tw + PAD),
		PAD + THEMES.size() * (th + PAD), false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.07, 0.08, 0.09, 1.0))
	for r in THEMES.size():
		for i in PROBES.size():
			var img: Image = await _render(THEMES[r], PROBES[i], tw, th)
			img.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(img, Rect2i(0, 0, tw, th),
				Vector2i(PAD + i * (tw + PAD), PAD + r * (th + PAD)))
	var out: String = OS.get_environment("TUNE_OUT")
	if out.is_empty():
		out = "res://tune.png"
	sheet.save_png(out)
	print("wrote %s  key=%.2f fill=%.2f h=%.2f spec=%.2f" % [
		out, TileLighting.key_energy(), TileLighting.fill_energy(),
		TileLighting.light_height(), TileLighting.specular()])
	get_tree().quit(0)


func _render(theme: String, probe: Dictionary, tw: int, th: int) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(tw, th)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	TileLighting.attach(vp)
	var holder := Control.new()
	holder.scale = Vector2(SCALE, SCALE)
	vp.add_child(holder)
	var view = TileViewScene.instantiate()
	holder.add_child(view)
	var t := RiverTile.new()
	t.suit = probe["suit"]
	t.rank = probe["rank"]
	view.theme_override = theme
	view.setup(t, true)
	if view.has_method("update_theme_style"):
		view.update_theme_style()
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	vp.queue_free()
	return img


func _apply_body_override() -> void:
	var f: String = OS.get_environment(BODY_OVERRIDE)
	if f.is_empty():
		return
	var path := "res://assets/tiles/" + f
	if not ResourceLoader.exists(path):
		push_error("TUNE_BODY not found: " + path)
		return
	var ct := CanvasTexture.new()
	ct.diffuse_texture = load(path)
	ct.normal_texture = TileView._get_normal_tex()
	var s: float = TileLighting.specular()
	ct.specular_color = Color(s, s * 0.98, s * 0.94)
	ct.specular_shininess = 0.35
	for theme in THEMES:
		TileView._body_tex_cache[theme] = ct
	print("body override: %s" % f)
