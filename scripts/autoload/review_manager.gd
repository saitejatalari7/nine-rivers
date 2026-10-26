extends Node

## Play's in-app review card (addons/NineRiversPlayCore), asked for when a
## player is pleased: just after a three-star clear, once they have played
## enough to have an opinion. At most three times, a month apart; Play keeps
## its own quota on top and may show nothing.

const PLUGIN := "NineRiversPlayCore"
const MIN_LEVEL := 10
const MAX_ASKS := 3
const ASK_AGAIN_AFTER := 30 * 86400
## Lets the clear screen land before Play's card rises over it.
const DELAY := 1.2

var _plugin: Object = null


func _ready() -> void:
	if OS.get_name() != "Android" or not Engine.has_singleton(PLUGIN):
		return
	_plugin = Engine.get_singleton(PLUGIN)
	_plugin.review_failed.connect(func(message: String): print("Nine Rivers: review: %s" % message))


func after_clear(level: int, stars: int) -> void:
	var now: int = int(Time.get_unix_time_from_system())
	if _plugin == null or not should_ask(level, stars, now):
		return
	SaveManager.prog["review_asked_count"] = int(SaveManager.prog.get("review_asked_count", 0)) + 1
	SaveManager.prog["review_asked_at"] = now
	SaveManager.request_save()
	await get_tree().create_timer(DELAY).timeout
	_plugin.requestReview()


func should_ask(level: int, stars: int, now: int) -> bool:
	if stars < 3 or level < MIN_LEVEL:
		return false
	var count: int = int(SaveManager.prog.get("review_asked_count", 0))
	var last: int = int(SaveManager.prog.get("review_asked_at", 0))
	return count < MAX_ASKS and (count == 0 or now - last >= ASK_AGAIN_AFTER)
