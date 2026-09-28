extends Control

## The one place the game offers a rewarded video: a round, cartoonish play
## button floating on the Shop screen. By the owner's rule it appears nowhere
## else - not on the board, not on clear screens - so an ad is only ever
## something a player walked into the shop and chose.

signal watch_pressed

const DIAMETER: float = 150.0
const REWARD_TEXT := "+20 ◈"

var _t: float = 0.0
var _pressed: bool = false
var _caption: Label


func _ready() -> void:
	custom_minimum_size = Vector2(DIAMETER + 40.0, DIAMETER + 70.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	_caption = Label.new()
	_caption.text = "Watch ad to\nearn pearls"
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.style_label(_caption, "ui", UITheme.FS_CAPTION, UITheme.IVORY_BASE, UITheme.W_SEMIBOLD)
	_caption.position = Vector2(0, DIAMETER + 8.0)
	_caption.size = Vector2(custom_minimum_size.x, 56)
	add_child(_caption)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_pressed = true
		elif _pressed:
			_pressed = false
			if Rect2(Vector2.ZERO, size).has_point(mb.position):
				AudioManager.play_ui_tap()
				watch_pressed.emit()
		accept_event()


## Drawn rather than textured: a fat outline, a two-tone fill and a bouncy
## wobble are what make it read as cartoonish at this size, and none of it
## needs an asset.
func _draw() -> void:
	var bob: float = sin(_t * 2.4) * 5.0
	var squash: float = 0.97 if _pressed else 1.0
	var c := Vector2(size.x * 0.5, DIAMETER * 0.5 + 4.0 + bob)
	var r: float = DIAMETER * 0.5 * squash

	# Soft shadow on the water, staying put while the button bobs.
	draw_circle(Vector2(c.x, DIAMETER + 2.0), r * 0.55, Color(0, 0, 0, 0.25))
	# Chunky outline, gold body with a darker lower half, glossy highlight.
	draw_circle(c, r, Color("#3a2410"))
	draw_circle(c, r - 7.0, Color("#e8a93a"))
	draw_circle(c + Vector2(0, 10), r - 16.0, Color("#d38a1e"))
	draw_circle(c - Vector2(0, 6), r - 18.0, Color("#f6c453"))
	draw_circle(c + Vector2(-r * 0.32, -r * 0.38), r * 0.16, Color(1, 1, 1, 0.55))
	# Play triangle, rounded by an outline pass.
	var tri := PackedVector2Array([
		c + Vector2(-r * 0.22, -r * 0.34),
		c + Vector2(-r * 0.22, r * 0.34),
		c + Vector2(r * 0.38, 0),
	])
	draw_colored_polygon(tri, Color("#fffaf0"))
	draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color("#3a2410"), 6.0, true)
	# Reward tag, tilted like a sticker.
	var tag_c := c + Vector2(r * 0.62, -r * 0.72)
	draw_set_transform(tag_c, deg_to_rad(-12.0), Vector2.ONE)
	var tag := Rect2(Vector2(-52, -22), Vector2(104, 44))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#c0392b")
	sb.border_color = Color("#3a2410")
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(18)
	draw_style_box(sb, tag)
	var font: Font = UITheme.get_ui_variation(UITheme.W_BOLD)
	draw_string(font, Vector2(-44, 10), REWARD_TEXT, HORIZONTAL_ALIGNMENT_CENTER, 88, 28, Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
