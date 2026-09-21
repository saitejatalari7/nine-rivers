extends SceneTree

## One-off: re-encode the boot splash through Image.save_png.
##
## Boot-splash images bypass the import system and ship into the APK exactly as
## they sit on disk, so whatever the authoring tool wrote is what the player
## downloads. Re-encoding changes no pixels; it only lets Godot's deflate pick
## better filters than the original encoder did.
##
## Run: godot --headless --path . --script res://tools/reencode_splash.gd

const SRC := "res://assets/branding/splash.png"

func _init() -> void:
	var abs: String = ProjectSettings.globalize_path(SRC)
	var before: int = FileAccess.get_file_as_bytes(SRC).size()

	var img := Image.load_from_file(SRC)
	if img == null:
		push_error("could not read the splash")
		quit(1)
		return

	print("source : %d bytes  %dx%d  format=%d" % [before, img.get_width(), img.get_height(), img.get_format()])
	print("alpha  : detect=%d (0=none 1=bit 2=blend)" % img.detect_alpha())

	var digest_before: String = _pixel_digest(img)

	if img.save_png(abs) != OK:
		push_error("save_png failed")
		quit(1)
		return

	var after: int = FileAccess.get_file_as_bytes(SRC).size()
	var reread := Image.load_from_file(SRC)
	var digest_after: String = _pixel_digest(reread)

	print("result : %d bytes  (%.1f%% smaller)" % [after, 100.0 * float(before - after) / float(before)])
	print("pixels : %s" % ("IDENTICAL" if digest_before == digest_after else "CHANGED - DO NOT SHIP"))
	quit(0 if digest_before == digest_after else 1)

func _pixel_digest(img: Image) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(("%d|%d|%d|" % [img.get_width(), img.get_height(), img.get_format()]).to_utf8_buffer())
	ctx.update(img.get_data())
	return ctx.finish().hex_encode()
