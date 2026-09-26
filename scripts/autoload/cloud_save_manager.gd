extends Node

## Nine Rivers — Cloud Save via Google Play Games Services (Saved Games)
##
## Keeps the player's profile on Google's servers, tied to their Google account,
## so progress survives a reinstall, a factory reset, or a new phone. Google Play
## already restores purchases; this covers everything Play cannot — level, stars,
## jade, koi, tile mastery, pearls, and anything bought with in-game currency.
##
## Design notes:
##   - Android only. On desktop and in the editor every method is a safe no-op,
##     so the game runs identically without the plugin.
##   - Sign-in is attempted silently. The player is only prompted if that fails,
##     and declining leaves the game fully playable on local saves alone.
##   - A cloud payload is treated as untrusted input, exactly like a local file:
##     it goes through SaveManager's validation before it is applied.
##   - When the phone and the cloud disagree, the copy showing MORE progress
##     wins. Never silently send a player backwards.

## Emitted when sign-in fails or is refused, so the UI can offer the choice once.
signal cloud_unavailable(reason: String)
## Emitted after a successful sync so the UI can refresh.
signal cloud_synced(applied_remote: bool)
## Emitted when the player's cloud-save preference changes.
signal cloud_choice_changed(enabled: bool)

const SNAPSHOT_NAME := "nine_rivers_profile"
const SNAPSHOT_DESC := "Nine Rivers progress"

## Seconds to wait after progress changes before uploading, so a burst of saves
## becomes one upload rather than several.
const PUSH_DEBOUNCE: float = 6.0

enum State { DISABLED, CONNECTING, READY, DECLINED, ERROR }

var state: State = State.DISABLED
var last_error: String = ""

var _sign_in: PlayGamesSignInClient
var _snapshots: PlayGamesSnapshotsClient
var _push_timer: float = -1.0
var _pending_push: bool = false
var _initial_sync_done: bool = false

# ---------------------------------------------------------------- lifecycle

func _ready() -> void:
	if not _is_supported():
		state = State.DISABLED
		set_process(false)
		return

	SaveManager.progress_committed.connect(_on_progress_committed)

	if not is_cloud_enabled():
		# The player previously chose local-only. Respect it until they change it.
		state = State.DECLINED
		set_process(false)
		return

	# Deferred: autoloads are still being parented during _ready, and the
	# sign-in and snapshot clients are added as children.
	_connect_to_play_games.call_deferred()

## True only where the Android plugin actually exists.
func _is_supported() -> bool:
	return OS.get_name() == "Android" and Engine.has_singleton("GodotPlayGameServices")

func _connect_to_play_games() -> void:
	state = State.CONNECTING

	if GodotPlayGameServices.initialize() != GodotPlayGameServices.PlayGamesPluginError.OK:
		_fail("Google Play Games is not available on this device.")
		return

	_sign_in = PlayGamesSignInClient.new()
	_sign_in.name = "PlayGamesSignIn"
	add_child(_sign_in)
	_sign_in.user_authenticated.connect(_on_user_authenticated)

	_snapshots = PlayGamesSnapshotsClient.new()
	_snapshots.name = "PlayGamesSnapshots"
	add_child(_snapshots)
	_snapshots.game_loaded.connect(_on_game_loaded)
	_snapshots.game_saved.connect(_on_game_saved)
	_snapshots.conflict_emitted.connect(_on_conflict)

	# Silent check first: if they are already signed in to Play Games — which is
	# the common case, since the account is on the phone — no prompt appears.
	_sign_in.is_authenticated()

func _on_user_authenticated(is_authenticated: bool) -> void:
	if is_authenticated:
		state = State.READY
		_pull()
		return

	# Not signed in. One interactive attempt, then leave them alone.
	if state == State.CONNECTING:
		state = State.ERROR
		_sign_in.sign_in()
		return

	_fail("Not signed in to Google Play Games.")

func _fail(reason: String) -> void:
	state = State.ERROR
	last_error = reason
	push_warning("Nine Rivers cloud save unavailable: %s" % reason)
	set_process(false)
	cloud_unavailable.emit(reason)

# ---------------------------------------------------------------- pull

func _pull() -> void:
	if state != State.READY:
		return
	# create_if_not_found: a first-time player gets an empty snapshot rather than
	# an error, and the first push then fills it.
	_snapshots.load_game(SNAPSHOT_NAME, true)

func _on_game_loaded(snapshot: PlayGamesSnapshot) -> void:
	_initial_sync_done = true

	var remote: Dictionary = _decode(snapshot)
	if remote.is_empty():
		# Nothing in the cloud yet, or it was unreadable. Seed it from this device.
		_push_now()
		cloud_synced.emit(false)
		return

	var applied := _apply_if_better(remote)
	if not applied:
		# The phone is ahead of the cloud, so bring the cloud up to date.
		_push_now()
	cloud_synced.emit(applied)

## Applies the remote profile only when it represents more progress than the
## local one. Returns true if the remote copy was adopted.
func _apply_if_better(remote: Dictionary) -> bool:
	var local_rank: Array = SaveManager.progress_rank(SaveManager.build_payload())
	var remote_rank: Array = SaveManager.progress_rank(remote)

	if _rank_greater(remote_rank, local_rank):
		SaveManager.import_payload(remote)
		print("Nine Rivers: adopted cloud profile (level %d over %d)." % [remote_rank[0], local_rank[0]])
		return true
	return false

static func _rank_greater(a: Array, b: Array) -> bool:
	for i in range(mini(a.size(), b.size())):
		if int(a[i]) != int(b[i]):
			return int(a[i]) > int(b[i])
	return false

# ---------------------------------------------------------------- push

func _on_progress_committed() -> void:
	if state != State.READY or not _initial_sync_done:
		return
	_pending_push = true
	_push_timer = PUSH_DEBOUNCE
	set_process(true)

func _process(delta: float) -> void:
	if _push_timer > 0.0:
		_push_timer -= delta
		if _push_timer <= 0.0:
			_push_timer = -1.0
			if _pending_push:
				_push_now()

func _push_now() -> void:
	if state != State.READY or _snapshots == null:
		return
	_pending_push = false

	var payload: Dictionary = SaveManager.build_payload()
	var bytes: PackedByteArray = JSON.stringify(payload).to_utf8_buffer()
	var level: int = int(SaveManager.prog.get("level", 1))

	# progress_value is what Google shows in its own saved-games UI and what we
	# use to break conflicts, so it must track real progress.
	_snapshots.save_game(
		SNAPSHOT_NAME,
		"%s — Stage %d" % [SNAPSHOT_DESC, level],
		bytes,
		0,
		level
	)

func _on_game_saved(is_saved: bool, _name: String, _desc: String) -> void:
	if not is_saved:
		push_warning("Nine Rivers: cloud save upload failed; local profile is unaffected.")

# ---------------------------------------------------------------- conflicts

## Two devices changed the profile independently. The plugin reports the clash
## but exposes no formal resolve call, so we decide the winner ourselves and
## write it back, which is what the next load will then see.
func _on_conflict(conflict: PlayGamesSnapshotConflict) -> void:
	var server: Dictionary = _decode(conflict.server_snapshot)
	var other: Dictionary = _decode(conflict.conflicting_snapshot)

	var winner: Dictionary = server
	if _rank_greater(SaveManager.progress_rank(other), SaveManager.progress_rank(server)):
		winner = other

	print("Nine Rivers: resolving cloud conflict in favour of the further-along profile.")
	if not winner.is_empty():
		_apply_if_better(winner)
	_push_now()

# ---------------------------------------------------------------- helpers

func _decode(snapshot: PlayGamesSnapshot) -> Dictionary:
	if snapshot == null or snapshot.content.is_empty():
		return {}
	var text := snapshot.content.get_string_from_utf8()
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		push_warning("Nine Rivers: cloud snapshot was unreadable; ignoring it.")
		return {}
	return json.data

# ---------------------------------------------------------------- player choice

## Whether the player wants cloud save. Defaults to on: the safe choice for
## someone who never opens Settings is the one that protects their progress.
func is_cloud_enabled() -> bool:
	# Off until the player asks for it. Nothing leaves the device by default:
	# a backup nobody requested is still data leaving the phone.
	return bool(SaveManager.settings.get("cloud_save", false))

## Records the player's choice and acts on it immediately.
func set_cloud_enabled(enabled: bool) -> void:
	SaveManager.settings["cloud_save"] = enabled
	SaveManager.settings["cloud_save_prompted"] = true
	SaveManager.save_game()
	cloud_choice_changed.emit(enabled)

	if enabled and _is_supported() and state in [State.DECLINED, State.ERROR]:
		set_process(true)
		_connect_to_play_games()
	elif not enabled:
		state = State.DECLINED
		set_process(false)

## True once the player has been shown the local-only warning, so it is asked
## once rather than on every launch.
func has_been_prompted() -> bool:
	return bool(SaveManager.settings.get("cloud_save_prompted", false))

func mark_prompted() -> void:
	SaveManager.settings["cloud_save_prompted"] = true
	SaveManager.request_save()

## Lets the Settings screen and the decline prompt offer a manual retry.
func sign_in_manually() -> void:
	if not _is_supported():
		cloud_unavailable.emit("Google Play Games is not available on this device.")
		return
	if state == State.READY:
		_pull()
		return
	set_cloud_enabled(true)

## Human-readable state for the Settings screen.
func status_text() -> String:
	match state:
		State.READY: return "On — progress saved to your Google account"
		State.CONNECTING: return "Connecting to Google Play Games…"
		State.DECLINED: return "Off — progress saved on this phone only"
		State.ERROR: return "Unavailable — %s" % last_error
		_: return "Not available on this device"
