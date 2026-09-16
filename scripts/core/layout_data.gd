class_name LayoutData
extends RefCounted

## Board shapes as ASCII art, one string per stacked layer.
##
## '.' is empty, anything else is a tile. Row r, column c maps to the board's
## half-unit grid as x = c * 2, y = r * 2. "extras" places tiles on half-unit
## offsets that a character grid cannot express (the turtle's flanking tiles).
##
## Tile size on screen is bound by COLUMN COUNT, not tile count - see
## scripts/tests/board_metrics.gd. Roughly: 6 columns gives 51dp, 8 gives 39dp,
## 15 gives 21dp. Portrait layouts should stay at or under 9 columns and buy
## their capacity with rows and layers instead.

const LAYOUTS: Dictionary = {
	"pagoda": {
		"display": "River Pagoda",
		"layers": [
			"""
XXXXXXXXX
XXXXXXXXX
XXXXXXXXX
XXXXXXXXX
XXXXXXXXX
XXXXXXXXX
XXXXXXXXX
XXXXXXXXX
""",
			"""
.........
.XXXXXXX.
.XXXXXXX.
.XXXXXXX.
.XXXXXXX.
.XXXXXXX.
.XXXXXXX.
""",
			"""
.........
.........
..XXXXX..
..XXXXX..
..XXXXX..
..XXXXX..
""",
			"""
.........
.........
.........
...XXX...
...XXX...
""",
			"""
.........
.........
.........
...XX....
...XX....
""",
		],
	},
	"quick": {
		"display": "Courtyard",
		"layers": [
			"""
XXXXXX
XXXXXX
XXXXXX
XXXXXX
""",
			"""
.....
.XXXX
.XXXX
""",
			"""
....
..XX
..XX
""",
		],
	},
	"gate": {
		"display": "Gate House",
		"layers": [
			"""
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
""",
			"""
......
..XXXX
..XXXX
""",
		],
	},
	"steps": {
		"display": "River Steps",
		"layers": [
			"""
XXXXXXXXXX
XXXXXXXXXX
XXXXXXXXXX
XXXXXXXXXX
""",
			"""
.........
.XXXXXXXX
.XXXXXXXX
""",
			"""
.......
...XXXX
""",
		],
	},
	"garden": {
		"display": "Garden Walk",
		"layers": [
			"""
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
""",
			"""
.......
.XXXXXX
.XXXXXX
.XXXXXX
""",
			"""
.....
...XX
...XX
...XX
""",
		],
	},
	"lotus": {
		"display": "Lotus Pagoda",
		"layers": [
			"""
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
""",
			"""
......
..XXXX
..XXXX
..XXXX
..XXXX
""",
			"""
.....
.....
...XX
...XX
""",
		],
	},
	"bridges": {
		"display": "Twin Bridges",
		"layers": [
			"""
XXX...XXX
XXX...XXX
XXXXXXXXX
XXXXXXXXX
XXX...XXX
XXX...XXX
""",
			"""
.........
XXX...XXX
XXXXXXXXX
XXXXXXXXX
XXX...XXX
""",
			"""
........
........
.X.....X
.X.....X
""",
		],
	},
	"keep": {
		"display": "Stone Keep",
		"layers": [
			"""
XXXXXXXXXXXX
XXXXXXXXXXXX
XXXXXXXXXXXX
XXXXXXXXXXXX
XXXXXXXXXXXX
""",
			"""
..........
..XXXXXXXX
..XXXXXXXX
..XXXXXXXX
""",
			"""
........
........
....XXXX
""",
		],
	},
	"waterfall": {
		"display": "Jade Cascade",
		"layers": [
			"""
XXXXXXXXXX
XXXXXXXXXX
XXXXXXXXXX
XXXXXXXXXX
XXXXXXXXXX
""",
			"""
..XXXXXX
..XXXXXX
..XXXXXX
..XXXXXX
""",
			"""
...XXXX
...XXXX
...XXXX
""",
			"""
....XX
....XX
""",
		],
	},
	"dragon_gate": {
		"display": "Dragon Gate",
		"layers": [
			"""
XXXXXXXXXX
XXXXXXXXXX
XXXXXXXXXX
XXXXXXXXXX
XXXXXXXXXX
XXXXXXXXXX
""",
			"""
.........
.XXXXXXXX
.XXXXXXXX
.XXXXXXXX
.XXXXXXXX
""",
			"""
.......
.......
...XXXX
...XXXX
""",
		],
	},
	"citadel": {
		"display": "Citadel",
		"layers": [
			"""
XXXXXXXXXXXX
XXXXXXXXXXXX
XXXXXXXXXXXX
XXXXXXXXXXXX
XXXXXXXXXXXX
XXXXXXXXXXXX
""",
			"""
..........
..XXXXXXXX
..XXXXXXXX
..XXXXXXXX
..XXXXXXXX
""",
			"""
........
........
....XXXX
....XXXX
""",
			"""
.......
.......
.....XX
""",
		],
	},
	"turtle": {
		"display": "Nine Rivers",
		"layers": [
			"""
.XXXXXXXXXXXX
...XXXXXXXX..
..XXXXXXXXXX.
.XXXXXXXXXXXX
.XXXXXXXXXXXX
..XXXXXXXXXX.
...XXXXXXXX..
.XXXXXXXXXXXX
""",
			"""
.........
...XXXXXX
...XXXXXX
...XXXXXX
...XXXXXX
...XXXXXX
...XXXXXX
""",
			"""
........
........
....XXXX
....XXXX
....XXXX
....XXXX
""",
			"""
.......
.......
.......
.....XX
.....XX
""",
			"""
.
""",
		],
		"extras": [[0, 7, 0], [26, 7, 0], [28, 7, 0], [11, 7, 4]],
	},
}
