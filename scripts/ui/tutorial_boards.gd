class_name TutorialBoards
extends RefCounted

## The five boards the onboarding teaches on, written out tile by tile.
##
## They are hand-authored rather than dealt, because each one has to demonstrate
## exactly one rule and nothing else. A generated board cannot promise that: the
## first lesson says "two tiles with the same face" and a dealer will happily
## offer a flower beside a character, which is a lesson contradicting its own
## caption.
##
## Coordinates are the board's half-unit grid, the same one the layouts use:
## a tile at x sits beside one at x + 2, and a tile at z + 1 covers the one
## under it. A tile is free when nothing sits on top of it and one of its two
## sides is clear - which is the whole of board B.
##
## Every board is checked for solvability by tutorial_boards_test.

const A_MATCH: Array = [
	# Four tiles, two identical pairs, gaps between them so every tile is free.
	# Nothing here can go wrong: the only thing to learn is that two of the same
	# face clear together.
	{"x": 0, "y": 0, "z": 0, "suit": "dot", "rank": 5, "set_id": 1, "size": 2},
	{"x": 4, "y": 0, "z": 0, "suit": "dot", "rank": 5, "set_id": 1, "size": 2},
	{"x": 0, "y": 2, "z": 0, "suit": "bam", "rank": 3, "set_id": 2, "size": 2},
	{"x": 4, "y": 2, "z": 0, "suit": "bam", "rank": 3, "set_id": 2, "size": 2},
]

const B_BLOCKED: Array = [
	# Two rows of three. The middle of each row has a neighbour on both sides,
	# so it cannot be lifted until one of them goes - and the two middles are a
	# pair, so the board cannot be finished without learning that.
	{"x": 0, "y": 0, "z": 0, "suit": "dot", "rank": 1, "set_id": 1, "size": 2},
	{"x": 2, "y": 0, "z": 0, "suit": "char", "rank": 3, "set_id": 3, "size": 2},
	{"x": 4, "y": 0, "z": 0, "suit": "dot", "rank": 1, "set_id": 1, "size": 2},
	{"x": 0, "y": 2, "z": 0, "suit": "bam", "rank": 2, "set_id": 2, "size": 2},
	{"x": 2, "y": 2, "z": 0, "suit": "char", "rank": 3, "set_id": 3, "size": 2},
	{"x": 4, "y": 2, "z": 0, "suit": "bam", "rank": 2, "set_id": 2, "size": 2},
]

const W_WILD: Array = [
	# Two tiles with no partner and two wilds, the season hidden under the
	# flower. No pair exists without a wild, and the wilds cannot pair with each
	# other because only one is free at a time - so the only way through is to
	# spend each one on a tile unlike it. Distinct set_ids keep the strand ripple
	# from firing and turning a lone tile wild behind the player's back.
	{"x": 0, "y": 0, "z": 0, "suit": "char", "rank": 7, "set_id": 1, "size": 2},
	{"x": 4, "y": 0, "z": 0, "suit": "season", "rank": 1, "set_id": 2, "size": 2},
	{"x": 4, "y": 0, "z": 1, "suit": "flower", "rank": 1, "set_id": 3, "size": 2},
	{"x": 8, "y": 0, "z": 0, "suit": "bam", "rank": 9, "set_id": 4, "size": 2},
]

const T_TRIPLE: Array = [
	# Two sets of three, every tile free. A tile with the gold underline only
	# clears with two more of its face, so a pair of them does nothing - the
	# board is the whole of that rule.
	{"x": 0, "y": 0, "z": 0, "suit": "dot", "rank": 4, "set_id": 1, "size": 3},
	{"x": 4, "y": 0, "z": 0, "suit": "dot", "rank": 4, "set_id": 1, "size": 3},
	{"x": 8, "y": 0, "z": 0, "suit": "dot", "rank": 4, "set_id": 1, "size": 3},
	{"x": 0, "y": 2, "z": 0, "suit": "char", "rank": 2, "set_id": 2, "size": 3},
	{"x": 4, "y": 2, "z": 0, "suit": "char", "rank": 2, "set_id": 2, "size": 3},
	{"x": 8, "y": 2, "z": 0, "suit": "char", "rank": 2, "set_id": 2, "size": 3},
]

const C_LAYERS: Array = [
	# Ten tiles on two layers. The pair on top is a flower and a character:
	# a flower matches anything, which is the one rule that cannot be worked
	# out by looking. Clearing them uncovers the middles, which are themselves
	# blocked until the rows beside them are taken - so this board revisits B
	# rather than only demonstrating depth.
	{"x": 0, "y": 0, "z": 0, "suit": "dot", "rank": 2, "set_id": 1, "size": 2},
	{"x": 2, "y": 0, "z": 0, "suit": "char", "rank": 1, "set_id": 3, "size": 2},
	{"x": 4, "y": 0, "z": 0, "suit": "dot", "rank": 2, "set_id": 1, "size": 2},
	{"x": 0, "y": 2, "z": 0, "suit": "bam", "rank": 5, "set_id": 2, "size": 2},
	{"x": 2, "y": 2, "z": 0, "suit": "char", "rank": 1, "set_id": 3, "size": 2},
	{"x": 4, "y": 2, "z": 0, "suit": "bam", "rank": 5, "set_id": 2, "size": 2},
	{"x": 0, "y": 4, "z": 0, "suit": "wind", "rank": 1, "set_id": 4, "size": 2},
	{"x": 4, "y": 4, "z": 0, "suit": "wind", "rank": 1, "set_id": 4, "size": 2},
	{"x": 2, "y": 0, "z": 1, "suit": "flower", "rank": 1, "set_id": 5, "size": 2},
	{"x": 2, "y": 2, "z": 1, "suit": "char", "rank": 7, "set_id": 5, "size": 2},
]


static func all() -> Array:
	return [A_MATCH, B_BLOCKED, W_WILD, T_TRIPLE, C_LAYERS]
