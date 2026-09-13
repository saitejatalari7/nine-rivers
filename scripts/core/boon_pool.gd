class_name BoonPool
extends RefCounted

const ALL_BOONS: Array[Dictionary] = [
	{
		"id": "river_dragon",
		"name": "River Dragon",
		"desc": "Bamboo and Character suits chain together without breaking Flow.",
		"icon": "🐉",
		"once": true
	},
	{
		"id": "phoenix_feather",
		"name": "Phoenix Feather",
		"desc": "Completing a Triple reveals the faces of all covered tiles for 4s.",
		"icon": "🪶",
		"once": true
	},
	{
		"id": "jade_kiln",
		"name": "Jade Kiln",
		"desc": "Banded triples award 3× score and grant +5 seconds of time.",
		"icon": "🏺",
		"once": false
	},
	{
		"id": "deep_breath",
		"name": "Deep Breath",
		"desc": "+60 seconds added to the clock immediately.",
		"icon": "⏱️",
		"once": false
	},
	{
		"id": "steady_hand",
		"name": "Steady Hand",
		"desc": "Misplays no longer deduct time from the countdown clock.",
		"icon": "✋",
		"once": true
	},
	{
		"id": "sharper_eye",
		"name": "Sharper Eye",
		"desc": "Permanent +30% score multiplier from here on.",
		"icon": "👁️",
		"once": false
	},
	{
		"id": "long_draw",
		"name": "Long Draw",
		"desc": "Every set cleared returns +1.0 second more time.",
		"icon": "🌊",
		"once": false
	},
	{
		"id": "two_shuffles",
		"name": "Two Shuffles",
		"desc": "+2 shuffles for when the board locks up.",
		"icon": "🔀",
		"once": false
	},
	{
		"id": "three_hints",
		"name": "Three Hints",
		"desc": "+3 hints to highlight legal sets on the board.",
		"icon": "💡",
		"once": false
	},
	{
		"id": "tide_caller",
		"name": "Tide Caller",
		"desc": "Reaching Flow ×7 unleashes a wave that clears 1 free set automatically.",
		"icon": "🌊",
		"once": true
	},
	{
		"id": "lotus_blessing",
		"name": "Lotus Blessing",
		"desc": "The first match of each stage immediately awards Flow ×3.",
		"icon": "🪷",
		"once": true
	},
	{
		"id": "jade_whisper",
		"name": "Jade Whisper",
		"desc": "Clearing Wild tiles awards double River Jade for the Koi Sanctuary.",
		"icon": "💎",
		"once": true
	},
	{
		"id": "dragon_bell",
		"name": "Dragon Bell",
		"desc": "Every 4th match rings a bell that highlights a legal set.",
		"icon": "🔔",
		"once": true
	},
	{
		"id": "spring_breeze",
		"name": "Spring Breeze",
		"desc": "Flower and Season matches immediately advance Flow by +2.",
		"icon": "🌸",
		"once": true
	},
	{
		"id": "porcelain_guard",
		"name": "Porcelain Guard",
		"desc": "The first misplay on each stage does not break your Flow.",
		"icon": "🛡️",
		"once": true
	},
	{
		"id": "golden_net",
		"name": "Golden Net",
		"desc": "Start each stage with +1 free Hint and +1 free Shuffle.",
		"icon": "🕸️",
		"once": true
	},
	{
		"id": "tide_surge",
		"name": "Tide Surge",
		"desc": "Shuffling under 20s clock does not consume a shuffle charge.",
		"icon": "🌀",
		"once": true
	}
]

static func get_draft_choices(count: int = 3, existing_ids: Array[String] = []) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for b in ALL_BOONS:
		if b.get("once", false) and existing_ids.has(b["id"]):
			continue
		pool.append(b)
	pool.shuffle()
	return pool.slice(0, mini(count, pool.size()))
