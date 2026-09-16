extends Node

const StagePlan = preload("res://scripts/core/stage_plan.gd")
const BoardGenerator = preload("res://scripts/core/board_generator.gd")
const LayoutData = preload("res://scripts/core/layout_data.gd")

var fails: int = 0


func _ready() -> void:
	_check_total()
	_check_determinism()
	_check_curve()
	_check_shape_usage()
	_check_modifiers()
	_check_chapters()
	_check_seed_spread()
	_check_star_gates()
	_print_sample()
	print("")
	print("Failures: %d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func _fail(msg: String) -> void:
	fails += 1
	print("  FAIL  " + msg)


func _pass(msg: String) -> void:
	print("  PASS  " + msg)


## Every level must resolve to a real layout - no gaps, no fallbacks.
func _check_total() -> void:
	var bad := 0
	for lv in range(1, StagePlan.TOTAL_LEVELS + 1):
		var name: String = StagePlan.layout_for_level(lv)
		if not LayoutData.LAYOUTS.has(name):
			bad += 1
			if bad <= 3:
				_fail("level %d maps to unknown layout '%s'" % [lv, name])
		elif BoardGenerator.get_layout_positions(name).is_empty():
			bad += 1
			_fail("level %d maps to empty layout '%s'" % [lv, name])
	if bad == 0:
		_pass("all %d levels map to a real layout" % StagePlan.TOTAL_LEVELS)


func _check_determinism() -> void:
	var ok := true
	for lv in [1, 7, 50, 137, 499, 500, 750, 1000]:
		var a: Dictionary = StagePlan.describe(lv)
		var b: Dictionary = StagePlan.describe(lv)
		if a != b:
			_fail("level %d is not deterministic" % lv)
			ok = false
	if ok:
		_pass("repeated lookups agree")


## The ramp should trend upward without being a staircase: early levels easy,
## late levels hard, and neither extreme absent in the middle.
func _check_curve() -> void:
	# One bucket per chapter: 50 levels is a whole number of wave periods, so
	# the average is clean, and "difficulty rises chapter to chapter" is the
	# property that actually matters.
	var span: int = StagePlan.LEVELS_PER_CHAPTER
	var buckets: Array[float] = []
	for b in range(StagePlan.CHAPTERS):
		var sum := 0.0
		for i in range(span):
			sum += float(StagePlan.tier_for_level(b * span + i + 1))
		buckets.append(sum / float(span))

	for i in range(1, buckets.size()):
		if buckets[i] < buckets[i - 1] - 0.01:
			_fail("average tier drops in bucket %d (%.2f after %.2f)" % [
				i, buckets[i], buckets[i - 1]])
			return
	if buckets[0] > 2.2:
		_fail("first %d levels average tier %.2f - too hard to open with" % [span, buckets[0]])
		return
	if buckets[buckets.size() - 1] < 4.0:
		_fail("last %d levels average tier %.2f - never gets hard" % [span, buckets[buckets.size() - 1]])
		return
	_pass("tier ramps %.2f -> %.2f per chapter" % [buckets[0], buckets[buckets.size() - 1]])

	for lv in range(1, StagePlan.TEACH_LEVELS + 1):
		if StagePlan.tier_for_level(lv) != 1:
			_fail("teaching level %d is not tier 1" % lv)
			return
	_pass("first %d levels are tier 1" % StagePlan.TEACH_LEVELS)


## Every authored shape should actually appear, or it is dead content.
func _check_shape_usage() -> void:
	var used: Dictionary = {}
	for lv in range(1, StagePlan.TOTAL_LEVELS + 1):
		var n: String = StagePlan.layout_for_level(lv)
		used[n] = int(used.get(n, 0)) + 1
	var unused: Array[String] = []
	for name in LayoutData.LAYOUTS.keys():
		if not used.has(name):
			unused.append(name)
	if unused.is_empty():
		_pass("all %d shapes are used" % LayoutData.LAYOUTS.size())
	else:
		_fail("shapes never used: %s" % str(unused))

	var worst_run := 0
	var run := 0
	var prev := ""
	for lv in range(1, StagePlan.TOTAL_LEVELS + 1):
		var n: String = StagePlan.layout_for_level(lv)
		run = run + 1 if n == prev else 1
		prev = n
		worst_run = maxi(worst_run, run)
	if worst_run > 3:
		_fail("same shape repeats %d levels in a row" % worst_run)
	else:
		_pass("longest identical-shape run is %d" % worst_run)


func _check_modifiers() -> void:
	for lv in range(1, StagePlan.TEACH_LEVELS + 1):
		if StagePlan.modifier_for_level(lv) != 0:
			_fail("level %d has a modifier before the teaching window ends" % lv)
			return
	var counts := {0: 0, 1: 0, 2: 0, 3: 0}
	for lv in range(1, StagePlan.TOTAL_LEVELS + 1):
		var m: int = StagePlan.modifier_for_level(lv)
		if m < 0 or m > 3:
			_fail("level %d has modifier %d out of range" % [lv, m])
			return
		counts[m] += 1
	var floor_each: int = StagePlan.TOTAL_LEVELS / 10
	for m in [1, 2, 3]:
		if counts[m] < floor_each:
			_fail("modifier %d appears only %d times in %d" % [
				m, counts[m], StagePlan.TOTAL_LEVELS])
			return
	_pass("modifiers: none %d, fog %d, rush %d, frost %d" % [
		counts[0], counts[1], counts[2], counts[3]])

	for lv in range(StagePlan.MILESTONE_EVERY, StagePlan.TOTAL_LEVELS + 1, StagePlan.MILESTONE_EVERY):
		if StagePlan.modifier_for_level(lv) == 0:
			_fail("milestone level %d has no modifier" % lv)
			return
		if StagePlan.tier_for_level(lv) != StagePlan.TIERS:
			_fail("milestone level %d is not top tier" % lv)
			return
	_pass("every %dth level is a top-tier modified landmark" % StagePlan.MILESTONE_EVERY)


func _check_chapters() -> void:
	# Names carry headroom for expanding the campaign later.
	if StagePlan.CHAPTER_NAMES.size() < StagePlan.CHAPTERS:
		_fail("%d chapter names for %d chapters" % [
			StagePlan.CHAPTER_NAMES.size(), StagePlan.CHAPTERS])
		return
	var covered := 0
	for c in range(StagePlan.CHAPTERS):
		var r: Vector2i = StagePlan.chapter_range(c)
		covered += r.y - r.x + 1
		if StagePlan.chapter_of(r.x) != c or StagePlan.chapter_of(r.y) != c:
			_fail("chapter %d range %s does not round-trip" % [c, r])
			return
	if covered != StagePlan.TOTAL_LEVELS:
		_fail("chapter ranges cover %d levels, expected %d" % [covered, StagePlan.TOTAL_LEVELS])
		return
	_pass("%d chapters tile %d levels exactly" % [StagePlan.CHAPTERS, covered])


## Distinct seeds, or different levels would deal identical boards.
func _check_seed_spread() -> void:
	var seen := {}
	var dupes := 0
	for lv in range(1, StagePlan.TOTAL_LEVELS + 1):
		var s: int = StagePlan.seed_for_level(lv)
		if s <= 0:
			_fail("level %d seed %d is not positive" % [lv, s])
			return
		if seen.has(s):
			dupes += 1
		seen[s] = true
	if dupes > 0:
		_fail("%d duplicate seeds across %d levels" % [dupes, StagePlan.TOTAL_LEVELS])
	else:
		_pass("all %d level seeds are distinct" % StagePlan.TOTAL_LEVELS)


## The gate must be reachable: a player who clears a chapter at the average
## star rate has to be able to pass it, or progress dead-ends.
func _check_star_gates() -> void:
	if StagePlan.stars_required(0) != 0:
		_fail("chapter 0 is gated")
		return
	var prev := -1
	for c in range(StagePlan.CHAPTERS):
		var need: int = StagePlan.stars_required(c)
		var avail: int = StagePlan.stars_available_before(c)
		if need <= prev:
			_fail("chapter %d gate %d does not exceed the previous %d" % [c, need, prev])
			return
		if need > avail:
			_fail("chapter %d needs %d stars but only %d exist before it" % [c, need, avail])
			return
		prev = need
	_pass("gates rise and never exceed the stars available")

	# Two stars a level is the yardstick for an average player.
	for c in range(1, StagePlan.CHAPTERS):
		var earned_at_two: int = c * StagePlan.LEVELS_PER_CHAPTER * 2
		if StagePlan.stars_required(c) > earned_at_two:
			_fail("chapter %d needs %d, above the %d a two-star player has" % [
				c, StagePlan.stars_required(c), earned_at_two])
			return
	_pass("a two-star average clears every gate")

	if StagePlan.highest_playable(1000, 0) != StagePlan.chapter_range(1).x - 1:
		_fail("zero stars should stop entry at the end of chapter I")
		return
	if StagePlan.is_level_playable(101, 1000, 0):
		_fail("level 101 playable with no stars")
		return
	if not StagePlan.is_level_playable(101, 1000, StagePlan.total_stars()):
		_fail("level 101 locked with every star earned")
		return
	_pass("entry is refused below the gate and allowed above it")
	var gate_line := ""
	for c in range(1, StagePlan.CHAPTERS):
		gate_line += "%s:%d  " % [StagePlan.ROMAN[c], StagePlan.stars_required(c)]
	print("        gates  " + gate_line)


func _print_sample() -> void:
	print("")
	print("  level  ch  tier  layout        modifier  milestone")
	for lv in [1, 4, 5, 25, 50, 51, 137, 250, 500, 750, 975, 1000]:
		var d: Dictionary = StagePlan.describe(lv)
		print("  %5d  %2d  %4d  %-12s  %8d  %s" % [
			d["level"], d["chapter"], d["tier"], d["layout"], d["modifier"],
			"yes" if d["milestone"] else ""])
