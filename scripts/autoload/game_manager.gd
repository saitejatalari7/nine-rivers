extends Node

const StageModifiers = preload("res://scripts/core/stage_modifiers.gd")

enum GameMode { CALM, RUN, DAILY }

signal score_updated(new_score: int, delta: int)
signal flow_updated(flow_level: int, suit_name: String, is_overdrive: bool)
signal time_updated(time_left: float, max_time: float)
signal props_updated(undos: int, hints: int, shuffles: int)
signal stage_cleared(stats: Dictionary)
signal game_over(reason: String)
signal relic_acquired(relic_data: Dictionary)

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
var time_left: float = 100.0
var max_time: float = 180.0
var score_mult: float = 1.0
var time_gain_rate: float = 1.5
var penalty_seconds: float = 3.0
var is_timer_active: bool = false
var active_relics: Array[String] = []

# Daily Tide metadata
var daily_seed: int = 0

# Relic stage state
var is_first_match_of_stage: bool = true
var porcelain_guard_active: bool = true

func _process(delta: float) -> void:
	if is_timer_active and current_mode != GameMode.CALM:
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
	active_relics.clear()
	
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
	score_mult = 1.0
	time_gain_rate = 1.5
	penalty_seconds = 3.0
	is_timer_active = true
	active_relics.clear()
	
	props_updated.emit(undos, hints, shuffles)
	score_updated.emit(score, 0)
	flow_updated.emit(0, "", false)
	time_updated.emit(time_left, max_time)
	on_stage_started()

## The daily was a fixed 40-tile board when 120s was chosen; it now deals
## 100-144, which quietly cut the time per match by more than half. Called once
## the layout is known, since the date seed has to pick that first.
func apply_daily_time(board_tiles: int) -> void:
	time_left = clampf(60.0 + float(board_tiles) * 1.5, 100.0, 260.0)
	max_time = maxf(180.0, time_left + 60.0)
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
	time_left = 120.0
	is_timer_active = true
	active_relics.clear()
	
	props_updated.emit(undos, hints, shuffles)
	score_updated.emit(score, 0)
	flow_updated.emit(0, "", false)
	time_updated.emit(time_left, max_time)
	on_stage_started()

func on_stage_started() -> void:
	is_first_match_of_stage = true
	porcelain_guard_active = true
	if has_relic("golden_net"):
		hints += 1
		shuffles += 1
		props_updated.emit(undos, hints, shuffles)

const SanctuaryManager = preload("res://scripts/core/sanctuary_manager.gd")

func is_overdrive_active() -> bool:
	var threshold: int = 6 if SanctuaryManager.is_koi_unlocked("dragon_koi") else 7
	return flow_level >= threshold

func snapshot_state() -> Dictionary:
	return {
		"score": score,
		"flow_level": flow_level,
		"flow_suit": flow_suit,
		"best_flow": best_flow,
		"time_left": time_left,
		"misplays": misplays,
		"porcelain_guard_active": porcelain_guard_active,
		"is_first_match_of_stage": is_first_match_of_stage
	}

func restore_state(snap: Dictionary) -> void:
	score = snap.get("score", score)
	flow_level = snap.get("flow_level", flow_level)
	flow_suit = snap.get("flow_suit", flow_suit)
	best_flow = snap.get("best_flow", best_flow)
	time_left = snap.get("time_left", time_left)
	misplays = snap.get("misplays", misplays)
	porcelain_guard_active = snap.get("porcelain_guard_active", porcelain_guard_active)
	is_first_match_of_stage = snap.get("is_first_match_of_stage", is_first_match_of_stage)
	
	var is_overdrive: bool = is_overdrive_active()
	flow_updated.emit(flow_level, flow_suit, is_overdrive)
	score_updated.emit(score, 0)
	if current_mode != GameMode.CALM:
		time_updated.emit(time_left, max_time)

func register_match(suit: String, is_triple: bool, mastery_level: int = 0,
		is_glass: bool = false, at: Vector2 = Vector2.INF, z: int = 0) -> int:
	# 1. Flow calculation
	var is_wild_suit: bool = (suit == "flower" or suit == "season")
	if is_first_match_of_stage:
		is_first_match_of_stage = false
		if has_relic("lotus_blessing"):
			flow_level = 3
			flow_suit = "" if is_wild_suit else suit
		else:
			flow_level = 2 if (is_wild_suit and has_relic("spring_breeze")) else 1
			flow_suit = "" if is_wild_suit else suit
	else:
		var can_chain: bool = false
		if flow_suit.is_empty() or is_wild_suit:
			can_chain = true
		elif suit == flow_suit:
			can_chain = true
		elif has_relic("river_dragon") and ((flow_suit == "bam" and suit == "char") or (flow_suit == "char" and suit == "bam")):
			can_chain = true
		
		if can_chain:
			var step: int = 2 if (is_wild_suit and has_relic("spring_breeze")) else 1
			flow_level = mini(9, flow_level + step)
			if not is_wild_suit and flow_suit.is_empty():
				flow_suit = suit
		else:
			flow_level = 2 if (is_wild_suit and has_relic("spring_breeze")) else 1
			flow_suit = "" if is_wild_suit else suit
	
	best_flow = maxi(best_flow, flow_level)
	var is_overdrive: bool = is_overdrive_active()
	flow_updated.emit(flow_level, flow_suit, is_overdrive)
	
	# 2. Score calculation
	var base: int = 250 if is_triple else 100
	if is_triple and has_relic("jade_kiln"):
		base *= 3
	var flow_mult: int = mini(6, maxi(1, flow_level))
	var rush_mult: float = 2.0 if StageModifiers.is_rush_active() else 1.0
	var ogon_mult: float = 1.10 if (current_mode == GameMode.CALM and SanctuaryManager.is_koi_unlocked("ogon")) else 1.0
	var mastery_mult: float = 1.0 + (float(mastery_level) * 0.05)
	var pts: int = int(round(base * flow_mult * score_mult * rush_mult * ogon_mult * mastery_mult))
	if is_glass:
		pts += 500
	score += pts
	score_updated.emit(score, pts)
	
	# 3. Time return
	if current_mode != GameMode.CALM:
		var bonus: float = time_gain_rate * (1.6 if is_triple else 1.0)
		if is_triple and has_relic("jade_kiln"):
			bonus += 5.0
		time_left = minf(max_time, time_left + bonus)
		time_updated.emit(time_left, max_time)
	
	AudioManager.play_tile_match(flow_level, is_triple, is_glass, at, z)
	if flow_level >= 5:
		AudioManager.play_combo_high()
	return pts

func register_misplay() -> void:
	misplays += 1
	if has_relic("porcelain_guard") and porcelain_guard_active:
		porcelain_guard_active = false
		AudioManager.play_misplay()
		return
		
	var misplay_drop: int = 1 if SanctuaryManager.is_koi_unlocked("showa") else 2
	flow_level = maxi(0, flow_level - misplay_drop)
	if flow_level == 0:
		flow_suit = ""
	var is_overdrive: bool = is_overdrive_active()
	flow_updated.emit(flow_level, flow_suit, is_overdrive)
	
	if current_mode != GameMode.CALM and not has_relic("steady_hand"):
		time_left = maxf(0.0, time_left - penalty_seconds)
		time_updated.emit(time_left, max_time)
	
	AudioManager.play_misplay()

func acquire_relic(relic: Dictionary) -> void:
	var rid: String = relic.get("id", "")
	active_relics.append(rid)
	match rid:
		"deep_breath":
			max_time = maxf(max_time, time_left + 60.0)
			time_left += 60.0
			time_updated.emit(time_left, max_time)
		"two_shuffles": shuffles += 2
		"three_hints": hints += 3
		"sharper_eye": score_mult += 0.30
		"long_draw": time_gain_rate += 1.0
		"steady_hand": penalty_seconds = 0.0
		"golden_net":
			hints += 1
			shuffles += 1
	
	props_updated.emit(undos, hints, shuffles)
	relic_acquired.emit(relic)

func has_relic(relic_id: String) -> bool:
	return active_relics.has(relic_id)
