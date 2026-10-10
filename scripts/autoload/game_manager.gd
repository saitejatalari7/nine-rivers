extends Node

const StageModifiers = preload("res://scripts/core/stage_modifiers.gd")

enum GameMode { CALM, RUN, DAILY }

signal score_updated(new_score: int, delta: int)
signal flow_updated(flow_level: int, suit_name: String, is_overdrive: bool)
signal time_updated(time_left: float, max_time: float)
## The Daily Puzzle has no countdown: it times the player, and the fastest
## finish ranks highest on the leaderboard.
signal elapsed_updated(elapsed: float)
signal props_updated(undos: int, hints: int, shuffles: int)
signal stage_cleared(stats: Dictionary)
signal game_over(reason: String)

var current_mode: GameMode = GameMode.CALM
var current_level: int = 1
var current_stage_no: int = 1
var current_layout_name: String = "quick"

var score: int = 0
var flow_level: int = 0
var flow_suit: String = ""
var best_flow: int = 0
var misplays: int = 0
var props_used: int = 0

# Props
var undos: int = 3
var hints: int = 3
var shuffles: int = 3

# Timed Mode / Roguelite parameters
## max_time is the denominator of the HUD's time bar. It is always set to the
## time the mode starts with, so the bar opens full and only ever drains; time
## won from matches refills it and is capped there.
const DEFAULT_MAX_TIME: float = 180.0

var time_left: float = 100.0
var max_time: float = DEFAULT_MAX_TIME
var score_mult: float = 1.0
var time_gain_rate: float = 1.5
var penalty_seconds: float = 3.0
var is_timer_active: bool = false
var elapsed: float = 0.0

# Daily Tide metadata
var daily_seed: int = 0

# Relic stage state
var is_first_match_of_stage: bool = true

func _process(delta: float) -> void:
	if is_timer_active and current_mode == GameMode.DAILY:
		elapsed += delta
		elapsed_updated.emit(elapsed)
		return
	if is_timer_active and current_mode == GameMode.RUN:
		var drain_rate: float = 1.5 if StageModifiers.is_rush_active() else 1.0
		time_left -= delta * drain_rate
		time_updated.emit(max(0.0, time_left), max_time)
		if time_left <= 0.0:
			time_left = 0.0
			is_timer_active = false
			game_over.emit("The river dried up. The clock ran out!")

func start_calm(level: int) -> void:
	current_mode = GameMode.CALM
	current_level = level
	current_stage_no = level
	score = 0
	score_mult = 1.0
	time_gain_rate = 1.5
	penalty_seconds = 3.0
	flow_level = 0
	flow_suit = ""
	best_flow = 0
	misplays = 0
	props_used = 0
	undos = 3
	hints = 3
	shuffles = 3
	is_timer_active = false

	props_updated.emit(undos, hints, shuffles)
	score_updated.emit(score, 0)
	flow_updated.emit(0, "", false)
	on_stage_started()

func start_timed_run() -> void:
	current_mode = GameMode.RUN
	current_level = 1
	current_stage_no = 1
	score = 0
	flow_level = 0
	flow_suit = ""
	best_flow = 0
	misplays = 0
	props_used = 0
	undos = 1
	hints = 2
	shuffles = 2
	time_left = 100.0
	max_time = time_left
	score_mult = 1.0
	time_gain_rate = 1.5
	penalty_seconds = 3.0
	is_timer_active = true

	props_updated.emit(undos, hints, shuffles)
	score_updated.emit(score, 0)
	flow_updated.emit(0, "", false)
	time_updated.emit(time_left, max_time)
	on_stage_started()

## Timed mode used to start at 100 s and carry only the leftovers into
## stages two and three, which are bigger and add Fog and Rush - by stage
## three almost nobody could finish. Every stage now gets its own clock from
## its size: about four seconds a pair, a little more per pair as the board
## grows (finding a match gets harder), twenty seconds to take the board in,
## and extra for the modifiers. Fog hides blocked faces (+15%); Rush drains
## 1.5x, so it gets +35% - still a squeeze, no longer a wall.
const STAGE_BASE_SECONDS: float = 20.0
const SECONDS_PER_PAIR: float = 4.0
const FOG_TIME_MULT: float = 1.15
const RUSH_TIME_MULT: float = 1.35
## Time left over carries into the next stage as a bonus, capped at half that
## stage's own allotment, so a quick player is rewarded without banking an
## unlimited cushion.
const CARRY_CAP: float = 0.5

static func stage_time_for(tiles: int, fog: bool, rush: bool) -> float:
	var pairs: float = float(tiles) * 0.5
	var t: float = STAGE_BASE_SECONDS + pairs * SECONDS_PER_PAIR * (1.0 + float(tiles) / 400.0)
	if fog:
		t *= FOG_TIME_MULT
	if rush:
		t *= RUSH_TIME_MULT
	return roundf(t)

func apply_stage_time(tiles: int, carry_over: bool) -> void:
	var allot: float = stage_time_for(tiles, StageModifiers.is_fog_active(), StageModifiers.is_rush_active())
	var carry: float = minf(maxf(0.0, time_left), allot * CARRY_CAP) if carry_over else 0.0
	time_left = allot + carry
	max_time = time_left
	time_updated.emit(time_left, max_time)


func start_daily_tide() -> void:
	current_mode = GameMode.DAILY
	# Seed based on current UTC year/month/day
	var dt := Time.get_date_dict_from_system(true)
	daily_seed = dt["year"] * 10000 + dt["month"] * 100 + dt["day"]

	current_level = 1
	current_stage_no = 1
	score = 0
	flow_level = 0
	flow_suit = ""
	best_flow = 0
	misplays = 0
	props_used = 0
	undos = 2
	hints = 2
	shuffles = 2
	elapsed = 0.0
	is_timer_active = true

	props_updated.emit(undos, hints, shuffles)
	score_updated.emit(score, 0)
	flow_updated.emit(0, "", false)
	elapsed_updated.emit(elapsed)
	on_stage_started()

## Called at the start of every stage, including the second and later stages of
## a Rapids run. _on_board_cleared() stops the clock to hold it still under the
## reward screen, so the next stage has to start it again or the countdown stays
## frozen for the rest of the run.
func on_stage_started() -> void:
	is_first_match_of_stage = true
	if current_mode != GameMode.CALM:
		is_timer_active = true
		_emit_clock()


## Flow at which Overdrive kicks in, and what a misplay costs. Both used to be
## nudged by a koi you had bought - a permanent, invisible few per cent that
## nobody could perceive. They are plain numbers now.
const OVERDRIVE_FLOW: int = 7
const MISPLAY_FLOW_DROP: int = 2

func is_overdrive_active() -> bool:
	return flow_level >= OVERDRIVE_FLOW

func snapshot_state() -> Dictionary:
	return {
		"score": score,
		"flow_level": flow_level,
		"flow_suit": flow_suit,
		"best_flow": best_flow,
		"time_left": time_left,
		"elapsed": elapsed,
		"misplays": misplays,
		"is_first_match_of_stage": is_first_match_of_stage
	}

func restore_state(snap: Dictionary) -> void:
	score = snap.get("score", score)
	flow_level = snap.get("flow_level", flow_level)
	flow_suit = snap.get("flow_suit", flow_suit)
	best_flow = snap.get("best_flow", best_flow)
	time_left = snap.get("time_left", time_left)
	elapsed = snap.get("elapsed", elapsed)
	misplays = snap.get("misplays", misplays)
	is_first_match_of_stage = snap.get("is_first_match_of_stage", is_first_match_of_stage)

	var is_overdrive: bool = is_overdrive_active()
	flow_updated.emit(flow_level, flow_suit, is_overdrive)
	score_updated.emit(score, 0)
	_emit_clock()


func _emit_clock() -> void:
	if current_mode == GameMode.DAILY:
		elapsed_updated.emit(elapsed)
	elif current_mode == GameMode.RUN:
		time_updated.emit(time_left, max_time)

func register_match(suit: String, is_triple: bool,
		is_glass: bool = false, at: Vector2 = Vector2.INF, z: int = 0) -> int:
	# 1. Flow calculation
	var is_wild_suit: bool = (suit == "flower" or suit == "season")
	if is_first_match_of_stage:
		is_first_match_of_stage = false
		flow_level = 1
		flow_suit = "" if is_wild_suit else suit
	else:
		var can_chain: bool = false
		if flow_suit.is_empty() or is_wild_suit:
			can_chain = true
		elif suit == flow_suit:
			can_chain = true

		if can_chain:
			flow_level = mini(9, flow_level + 1)
			if not is_wild_suit and flow_suit.is_empty():
				flow_suit = suit
		else:
			flow_level = 1
			flow_suit = "" if is_wild_suit else suit

	best_flow = maxi(best_flow, flow_level)
	var is_overdrive: bool = is_overdrive_active()
	flow_updated.emit(flow_level, flow_suit, is_overdrive)

	# 2. Score calculation
	var base: int = 250 if is_triple else 100
	var flow_mult: int = mini(6, maxi(1, flow_level))
	var rush_mult: float = 2.0 if StageModifiers.is_rush_active() else 1.0
	# base x Flow x Rush, and nothing else. score_mult stays at 1.0 now that the
	# relics are gone; it is kept as a field so a future bonus that the player
	# can actually see has somewhere to live.
	var pts: int = int(round(base * flow_mult * score_mult * rush_mult))
	if is_glass:
		pts += 500
	score += pts
	score_updated.emit(score, pts)

	# 3. Time return. Gated on the clock actually running: a match must not add
	# time to a countdown that is not counting down.
	if is_timer_active and current_mode == GameMode.RUN:
		var bonus: float = time_gain_rate * (1.6 if is_triple else 1.0)
		time_left = minf(max_time, time_left + bonus)
		time_updated.emit(time_left, max_time)

	AudioManager.play_tile_match(flow_level, is_triple, is_glass, at, z)
	if flow_level >= 5:
		AudioManager.play_combo_high()
	return pts

func register_misplay() -> void:
	misplays += 1
	flow_level = maxi(0, flow_level - MISPLAY_FLOW_DROP)
	if flow_level == 0:
		flow_suit = ""
	var is_overdrive: bool = is_overdrive_active()
	flow_updated.emit(flow_level, flow_suit, is_overdrive)

	if current_mode == GameMode.RUN:
		time_left = maxf(0.0, time_left - penalty_seconds)
		time_updated.emit(time_left, max_time)
	elif current_mode == GameMode.DAILY:
		elapsed += penalty_seconds
		elapsed_updated.emit(elapsed)

	AudioManager.play_misplay()

