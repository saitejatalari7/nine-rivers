class_name StagePlan
extends RefCounted

## Maps a Calm level number to the board it plays: shape, modifier and seed.
##
## Replaces main.gd's `layout_idx = (level - 1) / 2`, which ran out of shapes at
## level 21 and gave every level from there to 50 the same turtle.
##
## Two properties this has to hold:
##   - Deterministic. Level 342 is the same board for everyone, so difficulty is
##     an authored property rather than a dice roll, and a stuck player gets the
##     same puzzle back rather than a re-roll.
##   - Total. Every level in 1..TOTAL_LEVELS resolves to a real layout, however
##     many shapes exist. Adding shapes to LayoutData changes the mix without
##     touching this file.

const BoardGenerator = preload("res://scripts/core/board_generator.gd")
const LayoutData = preload("res://scripts/core/layout_data.gd")
const DeepLayouts = preload("res://scripts/core/layout_data_deep.gd")

const TOTAL_LEVELS: int = 1000
## Levels 1-500 shipped first and must deal exactly what they always dealt:
## their plan is computed as if the campaign still ended here. 501 onward is
## the deep half - narrow towers five to seven layers high.
const CLASSIC_LEVELS: int = 500
const CLASSIC_CHAPTERS: int = CLASSIC_LEVELS / 50
## The deep half is its own campaign, Deep Rivers, played alongside the
## classic one and opened by clearing this classic stage.
const DEEP_UNLOCK_STAGE: int = 25
const LEVELS_PER_CHAPTER: int = 50
const CHAPTERS: int = TOTAL_LEVELS / LEVELS_PER_CHAPTER

const TIERS: int = 5
## Levels before modifiers start, so the rules are learned unmodified.
const TEACH_LEVELS: int = 4
## Every Nth level is a landmark: hardest shape available, always modified.
const MILESTONE_EVERY: int = 25

const CHAPTER_NAMES: Array[Dictionary] = [
	{"name": "The Spring Brooks"},
	{"name": "The Bamboo Valley"},
	{"name": "The Golden Rapids"},
	{"name": "The Jade Gorges"},
	{"name": "The Dragon Sea"},
	{"name": "The Misty Fords"},
	{"name": "The Lantern Shallows"},
	{"name": "The Heron Marshes"},
	{"name": "The Cinnabar Cliffs"},
	{"name": "The Moonlit Weir"},
	{"name": "The Pine Narrows"},
	{"name": "The Thunder Reach"},
	{"name": "The Lotus Basin"},
	{"name": "The Ink Estuary"},
	{"name": "The Frost Channel"},
	{"name": "The Imperial Canal"},
	{"name": "The Phoenix Delta"},
	{"name": "The Obsidian Trench"},
	{"name": "The Celestial Bend"},
	{"name": "The Nine Rivers Mouth"},
]

const ROMAN: Array[String] = [
	"I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X",
	"XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX",
]

## Shapes grouped by tier, built once from whatever LayoutData holds.
static var _by_tier: Dictionary = {}


static func total_stars() -> int:
	return TOTAL_LEVELS * 3


static func chapter_of(level: int) -> int:
	return clampi((level - 1) / LEVELS_PER_CHAPTER, 0, CHAPTERS - 1)


static func chapter_range(chapter: int) -> Vector2i:
	var start: int = chapter * LEVELS_PER_CHAPTER + 1
	return Vector2i(start, mini(start + LEVELS_PER_CHAPTER - 1, TOTAL_LEVELS))


static func chapter_title(chapter: int) -> String:
	var c: int = clampi(chapter, 0, CHAPTERS - 1)
	if c >= CLASSIC_CHAPTERS:
		return "Deep %s: %s" % [ROMAN[c - CLASSIC_CHAPTERS], CHAPTER_NAMES[c]["name"]]
	return "Chapter %s: %s" % [ROMAN[c], CHAPTER_NAMES[c]["name"]]


static func chapter_subtitle(chapter: int) -> String:
	var c: int = clampi(chapter, 0, CHAPTERS - 1)
	var r: Vector2i = chapter_range(c)
	if c >= CLASSIC_CHAPTERS:
		return "Stages D%d - D%d" % [r.x - CLASSIC_LEVELS, r.y - CLASSIC_LEVELS]
	return "Stages %d - %d" % [r.x, r.y]


static func is_deep(level: int) -> bool:
	return level > CLASSIC_LEVELS


static func track_first(deep: bool) -> int:
	return CLASSIC_LEVELS + 1 if deep else 1


static func track_last(deep: bool) -> int:
	return TOTAL_LEVELS if deep else CLASSIC_LEVELS


## "Stage 12" or "Deep Stage 12": a deep stage is numbered within its own
## campaign, not as stage 512.
static func stage_name(level: int) -> String:
	if is_deep(level):
		return "Deep Stage %d" % (level - CLASSIC_LEVELS)
	return "Stage %d" % level


static func track_stars(stars: Dictionary, deep: bool) -> int:
	var total: int = 0
	for k in stars.keys():
		var lvl: int = int(k)
		if lvl >= track_first(deep) and lvl <= track_last(deep):
			total += int(stars[k])
	return total


## How many tiles are free at deal time, as a share of the board. Tile count
## says how LONG a board takes; this says how CONSTRAINED it is, and two boards
## of the same size can differ sharply. Measured by topology_probe.gd - the
## existing shapes sit between 0.21 and 0.39.
static var _free_ratio_cache: Dictionary = {}

static func free_ratio(name: String) -> float:
	if _free_ratio_cache.has(name):
		return _free_ratio_cache[name]
	var pos := BoardGenerator.get_layout_positions(name)
	if pos.is_empty():
		return 1.0
	var free: int = 0
	for p in pos:
		if BoardGenerator.is_slot_free(p, pos):
			free += 1
	var r: float = float(free) / float(pos.size())
	_free_ratio_cache[name] = r
	return r


## Tile count sets the base; the free ratio nudges it. A board that opens with
## almost nothing available plays a tier harder than its size suggests, and one
## that opens wide plays a tier easier.
static func tier_of_layout(name: String) -> int:
	var n: int = BoardGenerator.get_layout_positions(name).size()
	var base: int = 1
	if n > 120:
		base = 5
	elif n > 96:
		base = 4
	elif n > 72:
		base = 3
	elif n > 48:
		base = 2
	var b: Vector2 = _ratio_bounds()
	var r: float = free_ratio(name)
	if r < b.x:
		base += 1
	elif r > b.y:
		base -= 1
	return clampi(base, 1, TIERS)


## Thresholds are the 20th and 80th percentile of the actual layout set, not
## fixed numbers: the first version used constants calibrated on twelve shapes
## and, once the set grew to a hundred, demoted almost everything because the
## median had moved. Percentiles shift a fifth of the set each way whatever the
## distribution does.
static var _bounds_cache: Vector2 = Vector2(-1.0, -1.0)

static func _ratio_bounds() -> Vector2:
	if _bounds_cache.x >= 0.0:
		return _bounds_cache
	var ratios: Array[float] = []
	for name in LayoutData.LAYOUTS.keys():
		ratios.append(free_ratio(name))
	if ratios.size() < 5:
		_bounds_cache = Vector2(0.0, 1.0)
		return _bounds_cache
	ratios.sort()
	_bounds_cache = Vector2(
		ratios[int(ratios.size() * 0.2)],
		ratios[int(ratios.size() * 0.8)])
	return _bounds_cache


static func _build_tiers() -> void:
	if not _by_tier.is_empty():
		return
	for t in range(1, TIERS + 1):
		_by_tier[t] = [] as Array[String]
	var names: Array = LayoutData.LAYOUTS.keys()
	names.sort()
	for name in names:
		_by_tier[tier_of_layout(name)].append(name)
	# A tier with no shapes borrows from the nearest tier below, so the plan is
	# total even when whole tiers are unauthored.
	for t in range(1, TIERS + 1):
		if _by_tier[t].is_empty():
			for d in range(1, TIERS):
				var lo: int = t - d
				var hi: int = t + d
				if lo >= 1 and not _by_tier[lo].is_empty():
					_by_tier[t] = _by_tier[lo]
					break
				if hi <= TIERS and not _by_tier[hi].is_empty():
					_by_tier[t] = _by_tier[hi]
					break


static func layouts_in_tier(tier: int) -> Array:
	_build_tiers()
	return _by_tier.get(clampi(tier, 1, TIERS), [])


## Ramps 1 -> 5 across the campaign with a short repeating wave over the top, so
## a run of levels has shape instead of climbing a step at a time. Milestones
## pin to the top tier.
static func tier_for_level(level: int) -> int:
	var lv: int = clampi(level, 1, TOTAL_LEVELS)
	if lv <= TEACH_LEVELS:
		return 1
	if lv % MILESTONE_EVERY == 0 or lv > CLASSIC_LEVELS:
		return TIERS
	var ramp: float = 1.0 + 4.0 * float(lv - 1) / float(CLASSIC_LEVELS - 1)
	# Length 10 so a 100-level window samples it evenly; a 7-long wave left a
	# sampling wobble in the per-100 averages that looked like a curve defect.
	const WAVE: Array[int] = [0, 1, -1, 1, 0, -1, 2, 0, -1, 1]
	return clampi(int(round(ramp)) + WAVE[(lv - 1) % WAVE.size()], 1, TIERS)


## Round-robin within the tier: the nth level of a given tier takes the nth
## shape in that tier's pool. A stride-based index left 28 of 101 shapes
## unreachable, which is authored content nobody ever sees.
## Timed Mode deals a fresh shape for each stage, small then medium then
## large. It used to play the same three shapes - quick, gate, steps - in
## every game. The bands bracket those three, and the clock is already sized to
## each board, so the race stays as fair as it was.
const TIMED_BANDS: Array[Vector2i] = [Vector2i(24, 44), Vector2i(40, 58), Vector2i(52, 76)]
static var _size_cache: Dictionary = {}

static func layout_size(name: String) -> int:
	if not _size_cache.has(name):
		_size_cache[name] = BoardGenerator.get_layout_positions(name).size()
	return _size_cache[name]


static func timed_layout(stage_no: int, rng: RandomNumberGenerator, avoid: Array = []) -> String:
	var band: Vector2i = TIMED_BANDS[clampi(stage_no - 1, 0, TIMED_BANDS.size() - 1)]
	var pool: Array = []
	for name in LayoutData.LAYOUTS.keys():
		var n: int = layout_size(name)
		if n >= band.x and n <= band.y and not avoid.has(name):
			pool.append(name)
	if pool.is_empty():
		return BoardGenerator.LADDER[clampi(stage_no - 1, 0, BoardGenerator.LADDER.size() - 1)]
	pool.sort()
	return pool[rng.randi() % pool.size()]


## Koi Rescue: every fifth level from 10. Level 5 already carries the
## premium-tile offer, and the first boards are too small for a dig.
static func is_koi_level(level: int) -> bool:
	return level >= 10 and level % 5 == 0 and level <= TOTAL_LEVELS


static func layout_for_level(level: int) -> String:
	if level > CLASSIC_LEVELS:
		return deep_layout_for_level(level)
	var tier: int = tier_for_level(level)
	var pool: Array = layouts_in_tier(tier)
	if pool.is_empty():
		return "turtle"
	var nth: int = 0
	for lv in range(1, clampi(level, 1, TOTAL_LEVELS)):
		if tier_for_level(lv) == tier:
			nth += 1
	return pool[nth % pool.size()]


## How deep a level past 500 goes: 5 layers at 501 rising to 7 by 1000, on a
## short wave so it is not a staircase. Landmarks are always the deepest.
static func depth_for_level(level: int) -> int:
	var lv: int = clampi(level, CLASSIC_LEVELS + 1, TOTAL_LEVELS)
	if lv % MILESTONE_EVERY == 0:
		return 7
	var ramp: float = 5.0 + 2.0 * float(lv - CLASSIC_LEVELS - 1) / float(TOTAL_LEVELS - CLASSIC_LEVELS - 1)
	const WAVE: Array[int] = [0, 1, 0, -1, 0, 1, -1, 0, 1, 0]
	return clampi(int(round(ramp)) + WAVE[(lv - 1) % WAVE.size()], 5, 7)


static var _deep_pools: Dictionary = {}

## Each shape's variants (as drawn, then its flips) spread evenly through the
## depth's pool, and the shapes staggered against each other, so a shape comes
## round again as late as possible and in a new orientation when it does.
static func deep_pool(depth: int) -> Array:
	if _deep_pools.is_empty():
		for d in [5, 6, 7]:
			var groups: Array = []
			for name in DeepLayouts.LAYOUTS.keys():
				if int(DeepLayouts.LAYOUTS[name]["depth"]) != d:
					continue
				var vs: Array = []
				for v in DeepLayouts.VARIANTS:
					if String(v).get_slice("@", 0) == name:
						vs.append(v)
				# Two at most: four orientations of one shape in a pool of twenty
				# brought it back every few levels.
				groups.append(vs.slice(0, 2))
			var keyed: Array = []
			for j in groups.size():
				var vs: Array = groups[j]
				for i in vs.size():
					keyed.append([(float(i) + (float(j) + 0.5) / float(groups.size())) / float(vs.size()), vs[i]])
			keyed.sort_custom(func(x, y): return x[0] < y[0])
			_deep_pools[d] = keyed.map(func(e): return e[1])
	return _deep_pools.get(depth, [])


static func deep_layout_for_level(level: int) -> String:
	var lv: int = clampi(level, CLASSIC_LEVELS + 1, TOTAL_LEVELS)
	var depth: int = depth_for_level(lv)
	var pool: Array = deep_pool(depth)
	if pool.is_empty():
		return "twin_pagodas"
	var nth: int = 0
	for prior in range(CLASSIC_LEVELS + 1, lv):
		if depth_for_level(prior) == depth:
			nth += 1
	return pool[nth % pool.size()]


## 0 NONE, 1 FOG, 2 RUSH - matching StageModifiers.Modifier.
##
## Frost was 3 until it was cut. Both arms below count modulo the number of
## outcomes, so they became %3 and %2 with it gone; left at %3 and %4 they
## would have asked for a modifier that no longer exists.
static func modifier_for_level(level: int) -> int:
	if level <= TEACH_LEVELS:
		return 0
	var chapter: int = chapter_of(level)
	if level % MILESTONE_EVERY == 0:
		return 1 + ((level / MILESTONE_EVERY + chapter) % 2)
	return (level + chapter) % 3


static func is_milestone(level: int) -> bool:
	return level > TEACH_LEVELS and level % MILESTONE_EVERY == 0


## Star gates. Clearing levels is not enough to move on: a chapter asks for a
## share of the stars available before it, so stars are a currency for progress
## rather than only a score. GATE_FRACTION 0.6 means a player averaging two
## stars a level is comfortably ahead, while one-starring everything is not.
const GATE_FRACTION: float = 0.6


## Each campaign gates on its own stars: Deep Rivers' first chapter is open as
## soon as the campaign is, whatever the classic stars.
static func stars_required(chapter: int) -> int:
	var c: int = clampi(chapter, 0, CHAPTERS - 1)
	if c >= CLASSIC_CHAPTERS:
		c -= CLASSIC_CHAPTERS
	if c <= 0:
		return 0
	return int(floor(float(c * LEVELS_PER_CHAPTER * 3) * GATE_FRACTION))


static func stars_available_before(chapter: int) -> int:
	return clampi(chapter, 0, CHAPTERS - 1) * LEVELS_PER_CHAPTER * 3


static func is_chapter_unlocked(chapter: int, stars: int) -> bool:
	return stars >= stars_required(chapter)


## The furthest level a player may enter: capped by how far they have cleared,
## and by the first chapter whose star gate they have not met.
static func highest_playable(cleared_pointer: int, stars: int) -> int:
	var limit: int = clampi(cleared_pointer, 1, TOTAL_LEVELS)
	for c in range(1, CHAPTERS):
		if not is_chapter_unlocked(c, stars):
			var first: int = chapter_range(c).x
			return mini(limit, first - 1)
	return limit


static func is_level_playable(level: int, cleared_pointer: int, stars: int) -> bool:
	if level < 1 or level > TOTAL_LEVELS:
		return false
	if level > cleared_pointer:
		return false
	return is_chapter_unlocked(chapter_of(level), stars)


## Fixed per level so a stage is the same puzzle for every player and on every
## attempt. Nothing here depends on wall-clock time or play order.
static func seed_for_level(level: int) -> int:
	var h: int = level * 2654435761
	h = (h ^ (h >> 13)) * 1274126177
	return absi(h ^ (h >> 16)) + 1


static func describe(level: int) -> Dictionary:
	return {
		"level": level,
		"chapter": chapter_of(level),
		"tier": tier_for_level(level),
		"layout": layout_for_level(level),
		"modifier": modifier_for_level(level),
		"milestone": is_milestone(level),
		"seed": seed_for_level(level),
	}
