extends Node

## The Poing AdMob plugin behind the small interface MonetizationManager uses:
## show_rewarded_video(), show_interstitial(), is_rewarded_ready() and the
## `rewarded` signal. Only created on Android; on desktop the plugin swaps in
## mock ads, which would turn every test run into an ad run.
##
## Order matters. Consent is gathered first (Google requires a consent message
## for EEA and UK players, and shows nothing elsewhere), then the SDK starts,
## then one of each ad is preloaded so a tap never waits on the network.

signal rewarded

const RETRY_SECONDS: float = 30.0
const DEVELOPER_TEST_DEVICES: Array[String] = ["9524D58E36EA045039FEFE6522D20123"]

var rewarded_unit: String = ""
var interstitial_unit: String = ""

## Held for the life of this node. The plugin's loaders keep themselves alive
## with reference() and drop it with a deferred unreference() once the ad
## arrives; with no other holder that takes the count to zero while the loader
## is still connected to the plugin's signals, and the next signal lands on a
## freed object ("pthread_mutex_lock called on a destroyed mutex" on device).
## Each load gets its own loader (the plugin keys the native ad by the
## loader's uid), and every one is kept. They are tiny; a session makes a
## handful.
var _loaders: Array[RefCounted] = []
var _rewarded_ad: RewardedAd = null
var _interstitial_ad: InterstitialAd = null
var _started: bool = false
## True only once the SDK reports initialisation complete. Loading an ad
## before that throws on Android's main thread, which kills touch input while
## the game keeps drawing - the first device build shipped exactly that.
var _ready_to_load: bool = false


func start(rewarded_id: String, interstitial_id: String) -> void:
	rewarded_unit = rewarded_id
	interstitial_unit = interstitial_id
	var params := ConsentRequestParameters.new()
	UserMessagingPlatform.consent_information.update(params, _on_consent_info, func(_e): _start_sdk())


func _on_consent_info() -> void:
	var info := UserMessagingPlatform.consent_information
	if info.get_consent_status() != ConsentInformation.ConsentStatus.REQUIRED \
			or not info.get_is_consent_form_available():
		_start_sdk()
		return
	UserMessagingPlatform.load_consent_form(
		func(form: ConsentForm): form.show(func(_e): _start_sdk()),
		func(_e): _start_sdk())


func _start_sdk() -> void:
	if _started:
		return
	_started = true
	# A calm game for all ages: keep mature ad content out of it.
	var config := RequestConfiguration.new()
	config.max_ad_content_rating = RequestConfiguration.MAX_AD_CONTENT_RATING_PG
	# The developer's own phone, so it never receives live ads: viewing or
	# tapping your own live ads gets AdMob accounts suspended. The console's
	# test-device list does the same but can take hours to apply.
	config.test_device_ids = DEVELOPER_TEST_DEVICES
	MobileAds.set_request_configuration(config)
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = func(_status):
		_ready_to_load = true
		_load_rewarded()
		_load_interstitial()
	MobileAds.initialize(listener)


func is_rewarded_ready() -> bool:
	return _rewarded_ad != null


func show_rewarded_video() -> void:
	if _rewarded_ad == null:
		_load_rewarded()
		return
	var ad := _rewarded_ad
	_rewarded_ad = null
	var listener := OnUserEarnedRewardListener.new()
	listener.on_user_earned_reward = func(_item): rewarded.emit()
	ad.full_screen_content_callback.on_ad_dismissed_full_screen_content = func():
		ad.destroy()
		_load_rewarded()
	ad.full_screen_content_callback.on_ad_failed_to_show_full_screen_content = func(_e):
		ad.destroy()
		_load_rewarded()
	ad.show(listener)


func show_interstitial() -> void:
	if _interstitial_ad == null:
		_load_interstitial()
		return
	var ad := _interstitial_ad
	_interstitial_ad = null
	ad.full_screen_content_callback.on_ad_dismissed_full_screen_content = func():
		ad.destroy()
		_load_interstitial()
	ad.full_screen_content_callback.on_ad_failed_to_show_full_screen_content = func(_e):
		ad.destroy()
		_load_interstitial()
	ad.show()


func _load_rewarded() -> void:
	if not _ready_to_load:
		return
	var cb := RewardedAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: RewardedAd):
		_rewarded_ad = ad
		print("Nine Rivers: rewarded ad ready")
	cb.on_ad_failed_to_load = func(e):
		print("Nine Rivers: rewarded ad failed: %s" % e.message)
		_retry(_load_rewarded)
	var loader := RewardedAdLoader.new()
	_loaders.append(loader)
	loader.load(rewarded_unit, AdRequest.new(), cb)


func _load_interstitial() -> void:
	if not _ready_to_load:
		return
	var cb := InterstitialAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: InterstitialAd):
		_interstitial_ad = ad
		print("Nine Rivers: interstitial ad ready")
	cb.on_ad_failed_to_load = func(e):
		print("Nine Rivers: interstitial ad failed: %s" % e.message)
		_retry(_load_interstitial)
	var loader := InterstitialAdLoader.new()
	_loaders.append(loader)
	loader.load(interstitial_unit, AdRequest.new(), cb)


## No fill is common, especially for a new app. Retrying on a timer rather
## than immediately keeps a dead network from spinning.
func _retry(loader: Callable) -> void:
	if is_inside_tree():
		get_tree().create_timer(RETRY_SECONDS).timeout.connect(loader)
