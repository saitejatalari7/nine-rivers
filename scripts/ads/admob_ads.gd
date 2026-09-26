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

var rewarded_unit: String = ""
var interstitial_unit: String = ""

var _rewarded_ad: RewardedAd = null
var _interstitial_ad: InterstitialAd = null
var _started: bool = false


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
	MobileAds.set_request_configuration(config)
	MobileAds.initialize()
	_load_rewarded()
	_load_interstitial()


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
	if not _started:
		return
	var cb := RewardedAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: RewardedAd): _rewarded_ad = ad
	cb.on_ad_failed_to_load = func(_e): _retry(_load_rewarded)
	RewardedAdLoader.new().load(rewarded_unit, AdRequest.new(), cb)


func _load_interstitial() -> void:
	if not _started:
		return
	var cb := InterstitialAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: InterstitialAd): _interstitial_ad = ad
	cb.on_ad_failed_to_load = func(_e): _retry(_load_interstitial)
	InterstitialAdLoader.new().load(interstitial_unit, AdRequest.new(), cb)


## No fill is common, especially for a new app. Retrying on a timer rather
## than immediately keeps a dead network from spinning.
func _retry(loader: Callable) -> void:
	get_tree().create_timer(RETRY_SECONDS).timeout.connect(loader)
