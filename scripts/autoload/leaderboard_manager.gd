extends Node

## Nine Rivers — the Daily Puzzle leaderboard on Google Play Games.
##
## One board only: everyone plays the same deal each day, so it is the one
## ranking that measures skill rather than luck or time spent. Google keeps
## each player's best and provides the Today / This week / All time views.
##
## Independent of the Cloud Save choice: a player who keeps saves on the phone
## can still be ranked. Never prompts on launch; only the menu row asks to sign in.

const DAILY_PUZZLE_ID := "CgkInLy80bocEAIQAQ"

var _sign_in: PlayGamesSignInClient
var _boards: PlayGamesLeaderboardsClient
var _signed_in: bool = false
var _pending_score: int = 0
var _open_after_sign_in: bool = false


func _ready() -> void:
	if is_available():
		_connect.call_deferred()


func is_available() -> bool:
	return OS.get_name() == "Android" and Engine.has_singleton("GodotPlayGameServices")


func _connect() -> void:
	# initialize() reports an error when called a second time, and Cloud Save
	# may have called it first.
	if GodotPlayGameServices.android_plugin == null \
			and GodotPlayGameServices.initialize() != GodotPlayGameServices.PlayGamesPluginError.OK:
		return
	_sign_in = PlayGamesSignInClient.new()
	_sign_in.name = "LeaderboardSignIn"
	add_child(_sign_in)
	_sign_in.user_authenticated.connect(_on_user_authenticated)
	_boards = PlayGamesLeaderboardsClient.new()
	_boards.name = "Leaderboards"
	add_child(_boards)
	_sign_in.is_authenticated()


func _on_user_authenticated(is_authenticated: bool) -> void:
	_signed_in = is_authenticated
	if not is_authenticated:
		_open_after_sign_in = false
		return
	if _pending_score > 0:
		_boards.submit_score(DAILY_PUZZLE_ID, _pending_score)
		_pending_score = 0
	if _open_after_sign_in:
		_open_after_sign_in = false
		_show()


## Called on a cleared Daily Puzzle. Google ignores a score lower than the
## player's best, so every clear can be sent.
func submit_daily(score: int) -> void:
	if not is_available() or score <= 0:
		return
	if _signed_in and _boards != null:
		_boards.submit_score(DAILY_PUZZLE_ID, score)
	else:
		_pending_score = maxi(_pending_score, score)


func open_daily() -> void:
	if not is_available() or _boards == null:
		return
	if _signed_in:
		_show()
		return
	_open_after_sign_in = true
	_sign_in.sign_in()


func _show() -> void:
	_boards.show_leaderboard_for_time_span_and_collection(DAILY_PUZZLE_ID,
		PlayGamesLeaderboardVariant.TimeSpan.TIME_SPAN_DAILY,
		PlayGamesLeaderboardVariant.Collection.COLLECTION_PUBLIC)
