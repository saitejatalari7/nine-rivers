extends Node

## Play's flexible in-app update (addons/NineRiversPlayCore).
##
## A few seconds after launch, and whenever the game comes back to the front,
## ask Play whether a newer version exists. If it does, Play shows its own
## update sheet - at most once a day for a given version, so "No thanks" is
## respected. The download runs in the background while the player keeps
## playing; once it is in, the main menu offers a restart.

signal update_ready

const PLUGIN := "NineRiversPlayCore"
const FIRST_CHECK_DELAY := 4.0
const ASK_AGAIN_AFTER := 86400

var ready_to_install: bool = false
## The restart card is offered once per session; "Later" means later.
var restart_offered: bool = false

var _plugin: Object = null


func _ready() -> void:
	if OS.get_name() != "Android" or not Engine.has_singleton(PLUGIN):
		return
	_plugin = Engine.get_singleton(PLUGIN)
	_plugin.update_available.connect(_on_update_available)
	_plugin.update_downloaded.connect(_on_update_downloaded)
	_plugin.update_failed.connect(_on_update_failed)
	get_tree().create_timer(FIRST_CHECK_DELAY).timeout.connect(check)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED:
		check()


func check() -> void:
	if _plugin != null and not ready_to_install:
		_plugin.checkForUpdate()


func restart_into_update() -> void:
	if _plugin == null:
		return
	SaveManager.save_game()
	_plugin.completeUpdate()


func _on_update_available(version_code: int) -> void:
	if not should_ask(version_code, int(Time.get_unix_time_from_system())):
		return
	SaveManager.prog["update_asked_code"] = version_code
	SaveManager.prog["update_asked_at"] = int(Time.get_unix_time_from_system())
	SaveManager.request_save()
	_plugin.startUpdate()


func should_ask(version_code: int, now: int) -> bool:
	var asked_code: int = int(SaveManager.prog.get("update_asked_code", 0))
	var asked_at: int = int(SaveManager.prog.get("update_asked_at", 0))
	return version_code != asked_code or now - asked_at >= ASK_AGAIN_AFTER


func _on_update_downloaded() -> void:
	if ready_to_install:
		return
	ready_to_install = true
	update_ready.emit()


func _on_update_failed(message: String) -> void:
	print("Nine Rivers: update check: %s" % message)
