class_name RiverTile
extends RefCounted

var x: int = 0
var y: int = 0
var z: int = 0

var suit: String = "dot" # dot, bam, char, wind, dragon, flower, season
var rank: int = 1
var set_id: int = 0
var size: int = 2 # 2 for pair, 3 for triple
var is_open: bool = false # Stranded wild tile
var is_removed: bool = false
var is_glass: bool = false

func _init(px: int = 0, py: int = 0, pz: int = 0, psuit: String = "dot", prank: int = 1, pset: int = 0, psize: int = 2) -> void:
	x = px
	y = py
	z = pz
	suit = psuit
	rank = prank
	set_id = pset
	size = psize

func is_wild_suit() -> bool:
	return suit == "flower" or suit == "season"

func is_wild() -> bool:
	return is_wild_suit() or is_open

func get_match_key() -> String:
	if is_wild_suit():
		return suit
	return suit + str(rank)

func is_compatible_with(other: RiverTile) -> bool:
	if not other:
		return false
	if is_wild() or other.is_wild():
		return true
	return get_match_key() == other.get_match_key()

func duplicate_data() -> RiverTile:
	var c := RiverTile.new(x, y, z, suit, rank, set_id, size)
	c.is_open = is_open
	c.is_removed = is_removed
	c.is_glass = is_glass
	return c
