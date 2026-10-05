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
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
""",
			"""
........
.XXXXXXX
.XXXXXXX
.XXXXXXX
.XXXXXXX
.XXXXXXX
.XXXXXXX
""",
			"""
........
........
..XXXXX.
..XXXXX.
..XXXXX.
..XXXXX.
""",
			"""
........
........
........
...XXX..
...XXX..
""",
			"""
........
........
........
...XX...
...XX...
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
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
""",
			"""
........
XXXXXXXX
XXXXXXXX
""",
			"""
........
..XXXX..
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
XXX...XX
XXX...XX
XXXXXXXX
XXXXXXXX
XXX...XX
XXX...XX
""",
			"""
........
XXX...XX
XXXXXXXX
XXXXXXXX
XXX...XX
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
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
""",
			"""
........
XXXXXXXX
XXXXXXXX
XXXXXXXX
""",
			"""
........
........
..XXXX..
""",
		],
	},
	"waterfall": {
		"display": "Jade Cascade",
		"layers": [
			"""
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
""",
			"""
.XXXXXX.
.XXXXXX.
.XXXXXX.
.XXXXXX.
""",
			"""
..XXXX..
..XXXX..
..XXXX..
""",
			"""
...XX...
...XX...
""",
		],
	},
	"dragon_gate": {
		"display": "Dragon Gate",
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
........
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
""",
			"""
........
........
..XXXX..
..XXXX..
""",
		],
	},
	"citadel": {
		"display": "Citadel",
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
........
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
""",
			"""
........
........
..XXXX..
..XXXX..
""",
			"""
........
........
...XX...
""",
		],
	},
	"turtle": {
		"display": "Nine Rivers",
		"layers": [
			"""
XXXXXXXX
.XXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
.XXXXXXX
XXXXXXXX
""",
			"""
........
.XXXXXX.
.XXXXXX.
.XXXXXX.
.XXXXXX.
.XXXXXX.
.XXXXXX.
""",
			"""
........
........
..XXXX..
..XXXX..
..XXXX..
..XXXX..
""",
			"""
........
........
........
...XX...
...X....
""",
			"""
........
""",
		],
		"extras": [[7, 7, 4]],
	},
	"coin": {
		"display": "Cash Coin",
		"layers": [
			"""
..XXXXX.
.XXXXXXX
XXX...XX
XXX...XX
XXX...XX
.XXXXXXX
..XXXX..
""",
		],
	},
	"fan": {
		"display": "Folding Fan",
		"layers": [
			"""
XXXXXXXX
XXXXXXXX
XXXXXXXX
.XXXXXXX
..XXXXX.
...XX...
""",
		],
	},
	"lantern": {
		"display": "Paper Lantern",
		"layers": [
			"""
...X...
.XXXXX.
XXXXXXX
XXXXXXX
XXXXXXX
.XXXXX.
...X...
..XXX..
""",
			"""
.......
.......
..XXX..
..XXX..
""",
		],
	},
	"bamboo": {
		"display": "Bamboo Stalk",
		"layers": [
			"""
...XXX..
...XXX..
XX.XXX.X
.XXXXXXX
...XXX..
...XXX..
XX.XXX.X
.XXXXXXX
...XXX..
...XXX..
""",
		],
	},
	"crescent": {
		"display": "Crescent Moon",
		"layers": [
			"""
...XXX..
..XXXX..
.XXXX...
XXXX....
XXXX....
XXXX....
.XXXX...
..XXXX..
...XXX..
""",
		],
	},
	"plum": {
		"display": "Plum Blossom",
		"layers": [
			"""
.XX...XX
XXXX.XXX
XXXXXXXX
XXXX.XXX
.XX...XX
""",
			"""
........
........
........
""",
		],
	},
	"ingot": {
		"display": "Gold Ingot",
		"layers": [
			"""
X......X
XXXXXXXX
XXXXXXXX
.XXXXXX.
""",
			"""
........
..XXXX..
..XXXX..
""",
		],
	},
	"brush": {
		"display": "Ink Brush",
		"layers": [
			"""
..XX..
..XX..
..XX..
..XX..
.XXXX.
XXXXXX
XXXXXX
.XXXX.
..XX..
..XX..
""",
		],
	},
	"cup": {
		"display": "Tea Bowl",
		"layers": [
			"""
XXXXXXXX
XXXXXXXX
.XXXXXXX
..XXXXX.
...XXX..
..XXXXX.
""",
		],
	},
	"kite": {
		"display": "Paper Kite",
		"layers": [
			"""
....X...
...XXX..
..XXXXX.
.XXXXXXX
..XXXXX.
...XXX..
....X...
...XX...
....XX..
...X....
""",
		],
	},
	"bell": {
		"display": "Temple Bell",
		"layers": [
			"""
....X...
...XXX..
..XXXXX.
.XXXXXXX
.XXXXXXX
XXXXXXXX
XXXXXXXX
...XXX..
""",
		],
	},
	"gourd": {
		"display": "Calabash",
		"layers": [
			"""
..XXX..
.XXXXX.
.XXXXX.
..XXX..
.XXXXX.
XXXXXXX
XXXXXXX
.XXXXX.
""",
		],
	},
	"sampan": {
		"display": "Sampan",
		"layers": [
			"""
....XX..
...XXX..
..XXXX..
.XXXXX..
...XX...
XXXXXXXX
.XXXXXX.
""",
		],
	},
	"moon_gate": {
		"display": "Moon Gate",
		"layers": [
			"""
..XXXXX.
.XX...XX
XX.....X
XX.....X
XX.....X
XX.....X
XXXXXXX.
""",
		],
	},
	"peaks": {
		"display": "Three Peaks",
		"layers": [
			"""
...X....
..XXX..X
.XXXXXXX
XXXXXXXX
XXXXXXXX
""",
		],
	},
	"cloud": {
		"display": "Drifting Cloud",
		"layers": [
			"""
XX..XX..
XXXXXX..
XXXXXXXX
XXXXXXXX
.XX...XX
.......X
""",
			"""
........
.XXX....
.XX.....
""",
		],
	},
	"pavilion": {
		"display": "Water Pavilion",
		"layers": [
			"""
...XXX..
.XXXXXXX
XXXXXXXX
..X...X.
..X...X.
.XXXXXX.
""",
		],
	},
	"stone_arch": {
		"display": "Stone Arch",
		"layers": [
			"""
..XXXXX.
XXXXXXXX
XXXXXXXX
XX.....X
X.......
X.......
""",
			"""
........
...XX...
""",
		],
	},
	"umbrella": {
		"display": "Oiled Umbrella",
		"layers": [
			"""
...XXX..
.XXXXXXX
XXXXXXXX
XXXXXXXX
.X.XXX.X
....X...
....X...
....X...
...XX...
""",
		],
	},
	"butterfly": {
		"display": "Jade Butterfly",
		"layers": [
			"""
XX..X..X
XXXXXXXX
XXXXXXXX
XXXXXXXX
.XXXXXXX
XXX.X.XX
XXX.X.XX
.XX.X.XX
""",
			"""
........
....X...
....X...
........
........
""",
		],
	},
	"crane": {
		"display": "White Crane",
		"layers": [
			"""
......XX
.....XX.
....XX..
...XX...
XXXXX...
XXXXXX..
XXXXXX..
XXXXX...
.XX.X...
.X..X...
""",
			"""
........
........
........
........
........
XXXXX...
XXXX....
""",
		],
	},
	"tortoise": {
		"display": "Stone Tortoise",
		"layers": [
			"""
...XXX..
X.XXXXX.
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
X.XXXXX.
...XXX..
""",
		],
	},
	"junk": {
		"display": "River Junk",
		"layers": [
			"""
...X....
...XX...
..XXXX..
.XXXXXX.
XXXXXXXX
...XX...
XXXXXXXX
XXXXXXXX
XXXXXXX.
""",
		],
	},
	"koi": {
		"display": "Koi Carp",
		"layers": [
			"""
X.....XX
XX.XXXXX
XXXXXXXX
XXXXXXXX
XX.XXXXX
X.....XX
""",
			"""
........
........
....XXXX
....XXXX
""",
		],
	},
	"lotus_bloom": {
		"display": "Lotus Bloom",
		"layers": [
			"""
.X.....X
XX..X..X
XXX.X.XX
.XXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
..XXXXX.
...XX...
""",
		],
	},
	"pine": {
		"display": "Ancient Pine",
		"layers": [
			"""
....X...
...XXX..
..XXXXX.
.XXXXXXX
...XXX..
..XXXXX.
.XXXXXXX
XXXXXXXX
...XX...
...XX...
""",
			"""
........
........
...XXX..
...XXX..
........
...XXX..
...XXX..
...X....
""",
		],
	},
	"ox": {
		"display": "Water Ox",
		"layers": [
			"""
.......X
.......X
XXXXXXXX
XXXXXXXX
XXXXXXXX
X.....XX
X.....XX
X.....XX
""",
			"""
........
........
.XXXXXXX
.XXXXXX.
""",
		],
	},
	"rabbit": {
		"display": "Moon Rabbit",
		"layers": [
			"""
..X.X...
..X.X...
..XXX...
.XXXXX..
XXXXXXX.
XXXXXXXX
XXXXXXXX
XX..XXX.
""",
			"""
........
........
........
........
........
.XXXXXX.
.XXXXXX.
""",
		],
	},
	"bat": {
		"display": "Fortune Bat",
		"layers": [
			"""
X.......
XXX.X.XX
XXXXXXXX
XXXXXXXX
.XX.X.XX
..X...X.
""",
			"""
........
........
..XXXXX.
..XXX...
""",
		],
	},
	"peony": {
		"display": "Peony",
		"layers": [
			"""
..XX.XX.
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
..XXXXX.
...XX...
..XXXXX.
""",
		],
	},
	"lanterns": {
		"display": "Twin Lanterns",
		"layers": [
			"""
....X...
XXXXXXXX
XX.....X
XXX...XX
XXX...XX
XXX...XX
XXX...XX
XX.....X
XX.....X
""",
			"""
........
........
........
XX.....X
XX.....X
XX.....X
XX.....X
""",
		],
	},
	"waterwheel": {
		"display": "Water Wheel",
		"layers": [
			"""
..XXXXX.
XX.....X
X...X...
..XXXXX.
..XXXXX.
..XXXXX.
X...X...
XX.....X
..XXXXX.
""",
			"""
........
........
........
...XXX..
...XXX..
...X....
""",
		],
	},
	"vase": {
		"display": "Porcelain Vase",
		"layers": [
			"""
...XXX..
..XXXXX.
.XXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
.XXXXXXX
..XXXXX.
...XXX..
..XXXX..
""",
		],
	},
	"willow": {
		"display": "Weeping Willow",
		"layers": [
			"""
..XXXXX.
.XXXXXXX
XXXXXXXX
.X.X.X.X
.X.X.X.X
.X.X.X.X
....X...
....X...
..XXXXX.
""",
			"""
........
..XXXXX.
..XXXX..
""",
		],
	},
	"teahouse": {
		"display": "Tea House",
		"layers": [
			"""
....X...
...XXX..
.XXXXXXX
XXXXXXXX
XXXXXXXX
X.XXXXX.
XXXXXXXX
XXX...XX
XXXXXXXX
""",
		],
	},
	"heron": {
		"display": "Grey Heron",
		"layers": [
			"""
XX......
.XX.....
..X.....
..X.....
..X.....
.XXXXXX.
XXXXXXXX
.XXXXXX.
...X.X..
...X.X..
""",
			"""
........
........
........
........
........
..XXXX..
..XXXX..
..XXX...
""",
		],
	},
	"dragon": {
		"display": "River Dragon",
		"layers": [
			"""
.....XXX
.....XX.
XXXXXXXX
XXXXXX..
XX......
XXXXXX..
.XXXXXXX
......XX
.....XXX
....XXXX
""",
			"""
......XX
........
.XXXX...
.XXXX...
........
..XXX...
........
""",
		],
	},
	"phoenix": {
		"display": "Vermilion Phoenix",
		"layers": [
			"""
...XXX..
....X...
.XXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
.XXXXXXX
..X.X.X.
.X..X..X
X...X...
""",
			"""
........
........
...XXX..
...XXX..
...XXX..
...XXX..
...XX...
""",
		],
	},
	"temple": {
		"display": "Mountain Temple",
		"layers": [
			"""
...XXX..
.XXXXXXX
XXXXXXXX
..XXXXX.
XXXXXXXX
XXXXXXXX
XXXXXXXX
X.XXXXX.
XXXXXXXX
XXX...XX
""",
		],
	},
	"tiger": {
		"display": "Mountain Tiger",
		"layers": [
			"""
.......X
......XX
X.....XX
XXXXXXXX
XXXXXXXX
XXXXXXXX
X.XX.XX.
X.XX.XX.
X.XX.XX.
""",
			"""
........
........
........
XXXXXXXX
XXXXXXX.
""",
		],
	},
	"horse": {
		"display": "War Horse",
		"layers": [
			"""
........
.......X
.......X
......XX
XXXXXXXX
XXXXXXXX
XXXXXXXX
X....XX.
X....XX.
X....XX.
""",
			"""
........
........
........
........
XXXXXXXX
XXXXXXXX
XXXXXXX.
""",
		],
	},
	"rooster": {
		"display": "Golden Rooster",
		"layers": [
			"""
.....XX.
....XXXX
.....XXX
X....XXX
XX..XXXX
XXXXXXXX
XXXXXXXX
XXXXXXX.
.XXXXX..
..XX.X..
""",
			"""
........
........
........
........
........
..XXXX..
..XXXX..
..XXXX..
..XXXX..
""",
		],
	},
	"crab": {
		"display": "River Crab",
		"layers": [
			"""
X.......
XX.....X
XX.....X
.XXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
.X.....X
.X.....X
""",
			"""
........
........
........
..XXXXX.
..XXXXX.
..XXXXX.
..XXX...
""",
		],
	},
	"chrysanthemum": {
		"display": "Chrysanthemum",
		"layers": [
			"""
.X.X.X.X
XXXXXXXX
.XXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
.XXXXXXX
XXXXXXXX
.X.X.X.X
""",
			"""
........
........
........
..XXXXX.
..XXXXX.
..XXXX..
""",
		],
	},
	"drum_tower": {
		"display": "Drum Tower",
		"layers": [
			"""
XXXXXXXX
XXXXXXXX
.XXXXXXX
.X.XXX.X
.XXXXXXX
XXXXXXXX
XXXXXXXX
XXX...XX
XXX...XX
XXXXXXX.
""",
		],
	},
	"great_wall": {
		"display": "The Long Wall",
		"layers": [
			"""
XX.....X
XX.....X
XXX...XX
.X.X.X.X
XXXXXXXX
XXXXXXXX
XXXXXXXX
XX.XXX.X
""",
			"""
........
........
........
........
.XXXXXX.
.XXXXXX.
.XXXXX..
""",
		],
	},
	"watchtower": {
		"display": "Watchtower",
		"layers": [
			"""
.XXXXXXX
XXXXXXXX
..XX.XX.
..XXXXX.
.XXXXXXX
XXXXXXXX
..XX.XX.
..XXXXX.
.XXXXXXX
XXXXXXXX
""",
			"""
........
........
........
...XXX..
...XXX..
........
........
...XXX..
...XX...
""",
		],
	},
	"eagle": {
		"display": "Sea Eagle",
		"layers": [
			"""
X.......
XX..X..X
XXX.X.XX
XXXXXXXX
XXXXXXXX
XXXXXXXX
.XXXXXXX
..XXXXX.
...XXX..
..XX.XX.
""",
			"""
........
........
........
...XXX..
...XXX..
...XXX..
...XXX..
...XXX..
...X....
""",
		],
	},
	"elephant": {
		"display": "Great Elephant",
		"layers": [
			"""
...XXXXX
.XXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
X.XX.XX.
X.XX.XX.
""",
			"""
........
........
XXXXXXX.
XXXXXXX.
XXXXXX..
""",
		],
	},
	"peacock": {
		"display": "Peacock",
		"layers": [
			"""
.X.X.X.X
XXXXXXXX
XXXXXXXX
XXX.X.XX
.XX.X.XX
...XXX..
....X...
....X...
..XXXXX.
..XXXXX.
""",
			"""
........
.XXXXXXX
.XXXXXXX
..XXXXX.
........
........
........
........
...XXX..
...XX...
""",
		],
	},
	"moon_bridge": {
		"display": "Moon Bridge",
		"layers": [
			"""
.XXXXXXX
XXXXXXXX
X.......
........
X.......
XXXXXXXX
.XXXXXXX
""",
			"""
..XXXXX.
..XXXXX.
........
........
........
..XXXXX.
..XXXXX.
""",
			"""
...XXX..
...XXX..
........
........
........
...XXX..
...X....
""",
		],
	},
	"pipa": {
		"display": "Pipa Lute",
		"layers": [
			"""
...XX...
...XX...
...XX...
...XX...
..XXXX..
.XXXXXX.
XXXXXXXX
XXXXXXXX
XXXXXXXX
.XXXXXX.
""",
			"""
........
........
........
........
........
........
.XXXXXX.
.XXXXXX.
.XXXXXX.
""",
			"""
........
........
........
........
........
........
..XXXX..
..XXXX..
..XXXX..
""",
		],
	},
	"ding": {
		"display": "Bronze Ding",
		"layers": [
			"""
...XXX..
X.XXXXX.
XXXXXXXX
XXXXXXXX
XXXXXXXX
.XXXXXXX
..XXXXX.
.XX...XX
.XX...XX
""",
			"""
........
........
........
..XXXXX.
..XXXXX.
..XXX...
""",
		],
	},
	"guardian_lion": {
		"display": "Guardian Lion",
		"layers": [
			"""
.XXXXXXX
XXXXXXXX
XX.XXX.X
XXXXXXXX
XXXXXXXX
.XXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
X.XXXXX.
""",
			"""
........
........
........
........
........
........
........
..XXXXX.
..XXX...
........
""",
		],
	},
	"great_dragon": {
		"display": "Great Dragon",
		"layers": [
			"""
....XXXX
....XX.X
..XXXXXX
XXXXXXXX
XXX.....
XXXXXXXX
.XXXXXXX
.....XXX
...XXXXX
XXXXXXXX
""",
			"""
........
........
..XXXX..
..XXXX..
........
..XXXX..
..XXXX..
........
....XX..
.XXX....
""",
		],
	},
	"phoenix_rise": {
		"display": "Phoenix Rising",
		"layers": [
			"""
X.......
XX..X..X
XXXXXXXX
XXXXXXXX
XXXXXXXX
.XXXXXXX
..XXXXX.
.X.XXX.X
X..XXX..
...XXX..
""",
			"""
........
........
..XXXXX.
..XXXXX.
..XXXXX.
..XXXXX.
""",
			"""
........
........
...XXX..
........
""",
		],
	},
	"grand_temple": {
		"display": "Grand Temple",
		"layers": [
			"""
...XXX..
.XXXXXXX
XXXXXXXX
..XXXXX.
XXXXXXXX
XXXXXXXX
.XXXXXXX
XXXXXXXX
XXXXXXXX
X.XXXXX.
""",
			"""
........
........
........
........
........
........
........
.XXXXXXX
.XXXXX..
""",
		],
	},
	"treasure_ship": {
		"display": "Treasure Ship",
		"layers": [
			"""
X...X...
XX..XX..
XX.XXX.X
XXXXXXXX
....X...
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
.XXXXXXX
""",
			"""
........
........
........
........
........
.XXXXXXX
.XXXXXXX
.XXXXXX.
""",
		],
	},
	"pagoda_nine": {
		"display": "Nine-Storey Pagoda",
		"layers": [
			"""
..XXXXX.
.XXXXXXX
..XXXXX.
XXXXXXXX
.XXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
""",
			"""
........
........
........
........
...XXX..
........
...XXX..
........
...XX...
........
""",
		],
	},
	"zodiac_wheel": {
		"display": "Zodiac Wheel",
		"layers": [
			"""
XX.XXX.X
........
........
..XXXXX.
..XXXXX.
..XXXXX.
..XXXXX.
..XXXXX.
........
........
""",
			"""
.X..X..X
........
........
........
...XXX..
...XXX..
...XX...
........
........
........
""",
		],
	},
	"coiled_snake": {
		"display": "Coiled Serpent",
		"layers": [
			"""
XXXXXXXX
X.......
X.XXXXX.
X.X...X.
X.X.X.X.
X.X.XXX.
X.X.....
X.XXXXXX
X.......
XXXXXXXX
""",
			"""
........
X.......
X.......
X.......
X.......
X.......
X.......
X.......
X.......
..XXXXX.
""",
		],
	},
	"bell_tower": {
		"display": "Bell Tower",
		"layers": [
			"""
XXXXXXXX
XXXXXXXX
X.......
X.XXXXX.
X.XXXXX.
X.XXXXX.
X..XXX..
XXXXXXXX
XXXXXXXX
XXX...XX
""",
			"""
........
........
........
...XXX..
...XXX..
...XXX..
...X....
""",
		],
	},
	"grand_butterfly": {
		"display": "Grand Butterfly",
		"layers": [
			"""
XXX...XX
XXXXXXXX
XXXXXXXX
XXXXXXXX
.XXXXXXX
XXXXXXXX
XXXXXXXX
XXX.X.XX
XXX.X.XX
.XX.X.XX
""",
			"""
........
XXX.X.XX
XXX.X.XX
....X...
....X...
....X...
........
""",
		],
	},
	"cloud_palace": {
		"display": "Cloud Palace",
		"layers": [
			"""
XXXXXXXX
X.XXXXX.
XXXXXXXX
XX.XXX.X
XXXXXXXX
XXXXXXXX
........
.XX...XX
XXXXXXXX
XXXXXXXX
""",
			"""
........
........
........
........
........
........
........
........
..XXXXX.
..XXX...
""",
		],
	},
	"stag": {
		"display": "Sika Stag",
		"layers": [
			"""
XX.....X
.XX...XX
..XXXXX.
..XXXXX.
..XXXXX.
.XXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
""",
			"""
........
........
........
........
........
........
.XXXXXXX
.XXXXXXX
.XXXXXXX
.XXXXXX.
""",
		],
	},
	"lotus_throne": {
		"display": "Lotus Throne",
		"layers": [
			"""
..XXXXX.
.XXXXXXX
..XXXXX.
.XXXXXXX
XXXXXXXX
XXXXXXXX
.XXXXXXX
XXXXXXXX
.XXXXXXX
..XXXXX.
""",
			"""
........
........
........
........
..XXXXX.
..XXXXX.
..XXXXX.
..XXXX..
""",
		],
	},
	"monkey": {
		"display": "Monkey King",
		"layers": [
			"""
.X.XXX.X
.XXXXXXX
..X.X.X.
..XXXXX.
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
.XXXXXXX
.XX...XX
""",
			"""
........
........
........
........
..XXXXX.
..XXXXX.
..XXXXX.
..XXXX..
""",
		],
	},
	"peach": {
		"display": "Longevity Peach",
		"layers": [
			"""
...X.XXX
.XXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
.XXXXXXX
..XXXXX.
""",
			"""
........
........
........
..XXXXX.
..XXXXX.
..XXXXX.
..XXXX..
""",
		],
	},
	"carp_leap": {
		"display": "Leaping Carp",
		"layers": [
			"""
..XXXXX.
..XXXXX.
.XXXXXXX
XXXXXXXX
.XXXXXXX
.XXXXXXX
XXXXXXXX
.XXXXXXX
.XXX.XXX
..XX.XX.
""",
			"""
........
........
........
..XXXXX.
..XXXXX.
..XXXXX.
..XXXXX.
..XXXX..
""",
		],
	},
	"crane_flight": {
		"display": "Crane in Flight",
		"layers": [
			"""
...XXX..
X.XXXXX.
XXXXXXXX
XXXXXXXX
XXXXXXXX
.XXXXXXX
..XXXXX.
..XXXXX.
...X.X..
...X.X..
""",
			"""
........
........
..XXXXX.
..XXXXX.
..XXXXX.
..XXXXX.
""",
			"""
........
........
...XXX..
...XXX..
...XXX..
...X....
""",
		],
	},
	"ram": {
		"display": "Mountain Ram",
		"layers": [
			"""
..X...X.
..XXXXX.
XXXXXXXX
..XXXXX.
.XXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
X.XX.XX.
""",
			"""
........
........
........
........
........
........
.XXXXXXX
.XXXXX..
""",
		],
	},
	"grand_pagoda": {
		"display": "Grand Pagoda",
		"layers": [
			"""
..XXXXX.
.XXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
""",
			"""
........
........
........
........
..XXXXX.
..XXXXX.
..XXXXX.
..XXXXX.
..XXXXX.
..XXXXX.
""",
			"""
........
........
........
........
........
........
........
........
....X...
....X...
""",
		],
	},
	"imperial_palace": {
		"display": "Imperial Palace",
		"layers": [
			"""
...XXX..
.XXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
X.XXXXX.
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXX...XX
""",
			"""
........
........
..XXXXX.
..XXXXX.
..XXXXX.
........
.XXXXXXX
.XXXXXXX
.XXXXXXX
........
""",
			"""
........
........
........
........
........
........
........
...XXX..
...XX...
""",
		],
	},
	"celestial_phoenix": {
		"display": "Celestial Phoenix",
		"layers": [
			"""
..XXXXX.
...XXX..
X.XXXXX.
XXXXXXXX
XXXXXXXX
XXXXXXXX
.XXXXXXX
.X.XXX.X
X..XXX..
...XXX..
""",
			"""
........
........
........
.XXXXXXX
.XXXXXXX
.XXXXXXX
.XXXXXXX
...XXX..
...XXX..
...XXX..
""",
			"""
........
........
........
..XXXXX.
..XXXXX.
..XXXXX.
..XXXXX.
....X...
....X...
........
""",
			"""
........
........
........
........
........
........
""",
		],
	},
	"mount_kunlun": {
		"display": "Mount Kunlun",
		"layers": [
			"""
.X..X..X
.X.XXX.X
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXX.X.XX
XX.XXX.X
XXXXXXXX
X.XXXXX.
XXXXXXXX
""",
			"""
........
........
..XXXXX.
..XXXXX.
..XXXXX.
........
........
.XXXXXXX
........
.XXXXXXX
""",
			"""
........
........
........
...XXX..
...XX...
........
........
........
........
........
""",
		],
	},
	"dragon_boat": {
		"display": "Dragon Boat",
		"layers": [
			"""
...XXX..
..XXXXX.
..X.X.X.
..XXXXX.
.XXXXXXX
XXXXXXXX
XXXXXXXX
X.XXXXX.
XXXXXXXX
X.XXXXX.
""",
			"""
........
........
........
........
..XXXXX.
..XXXXX.
..XXXXX.
..XXXXX.
..XXXXX.
..XXXXX.
""",
			"""
........
........
........
........
...XXX..
...XXX..
...XXX..
...XXX..
...XXX..
...XXX..
""",
			"""
........
........
........
........
........
........
....X...
........
........
........
""",
		],
	},
	"heavenly_crane": {
		"display": "Heavenly Crane",
		"layers": [
			"""
...XXX..
...XXX..
X.XXXXX.
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
.XXXXXXX
..XXXXX.
...X.X..
""",
			"""
........
........
........
.XXXXXXX
.XXXXXXX
.XXXXXXX
.XXXXXXX
.XXXXXXX
...XXX..
""",
			"""
........
........
........
..XXXXX.
..XXXXX.
..XXXXX.
..XXXXX.
..XXXXX.
....X...
""",
			"""
........
........
........
........
........
........
""",
		],
	},
	"great_tiger": {
		"display": "Great Tiger",
		"layers": [
			"""
......XX
X.....XX
XX....XX
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
X.XX.XX.
X.XX.XX.
""",
			"""
........
........
........
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
""",
			"""
........
........
........
........
..XXXXX.
..XXXX..
""",
		],
	},
	"jade_throne": {
		"display": "Jade Throne",
		"layers": [
			"""
XXXXXXXX
.XXXXXXX
X...X...
X.XXXXX.
X.XXXXX.
XXXXXXXX
XXXXXXXX
XXXXXXXX
X.XXXXX.
X.XXXXX.
""",
			"""
........
........
........
........
........
........
..XXXXX.
..XXXXX.
..XXXXX.
..XXXXX.
""",
			"""
........
........
........
........
........
........
...XXX..
...XXX..
...XXX..
...XX...
""",
		],
	},
	"thousand_lotus": {
		"display": "Thousand Lotus",
		"layers": [
			"""
XX..X..X
XXX.X.XX
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
.XXXXXXX
..XXXXX.
.XXXXXXX
XXXXXXXX
""",
			"""
........
........
.XXXXXXX
.XXXXXXX
.XXXXXXX
.XXXXXXX
.XXXXXXX
""",
			"""
........
........
...XXX..
...XXX..
...XXX..
...XXX..
...XX...
""",
		],
	},
	"great_koi": {
		"display": "Great Koi",
		"layers": [
			"""
..XX...X
X.XXXXXX
XX.XXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
XX.XXXXX
X.XXXXXX
..XX...X
""",
			"""
........
........
...XXXXX
...XXXXX
...XXXXX
...XXXXX
...XXXXX
...XXXXX
""",
			"""
........
........
........
....XXXX
....XXXX
....XXXX
....XXXX
""",
		],
	},
	"lantern_festival": {
		"display": "Lantern Festival",
		"layers": [
			"""
X...X...
XX.XXX.X
XX.XXX.X
XX.XXX.X
XX.XXX.X
X...X...
XXXXXXXX
X...X...
XX.XXX.X
XX.XXX.X
""",
			"""
........
........
XX.XXX.X
XX.XXX.X
........
........
........
........
........
XX.XXX.X
""",
			"""
........
........
X...X...
X...X...
........
........
........
........
........
X...X...
""",
			"""
........
........
........
........
""",
		],
	},
	"cloud_gate": {
		"display": "Cloud Gate",
		"layers": [
			"""
XXXXXXXX
XXXXXXXX
XXXXXXXX
X.......
X.XXXXX.
X.XXXXX.
X.XXXXX.
X.......
XXXXXXXX
XXXXXXXX
""",
			"""
........
.XXXXXXX
.XXXXXXX
........
........
........
........
........
.XXXXXXX
.XXXXXXX
""",
			"""
........
...XXX..
...XXX..
........
........
........
........
........
...XXX..
...XXX..
""",
			"""
........
........
........
........
........
........
........
........
........
........
""",
		],
	},
	"great_crab": {
		"display": "Great Crab",
		"layers": [
			"""
XXX...XX
XXX.X.XX
.XXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
.XX...XX
.XX...XX
.X.....X
""",
			"""
........
........
........
.XXXXXXX
.XXXXXXX
.XXXXXXX
.XXXXXXX
""",
			"""
........
........
........
..XXXXX.
..XXXXX.
..XXXXX.
..XXXXX.
""",
		],
	},
	"sea_dragon": {
		"display": "Sea Dragon",
		"layers": [
			"""
...XXXXX
...XX.XX
.XXXXXXX
XXXXXXX.
XXX.....
XXXXXXX.
..XXXXXX
......XX
...XXXXX
XXXXXXXX
""",
			"""
....XXXX
........
..XXXX..
.XXXX...
........
.XXXX...
...XXXX.
........
....XXXX
.XXXX...
""",
			"""
........
........
...XX...
..XX....
........
..XX....
....XX..
........
........
..XX....
""",
		],
	},
	"great_fan": {
		"display": "Great Fan",
		"layers": [
			"""
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
.XXXXXXX
.XXXXXXX
..XXXXX.
..XXXXX.
...XXX..
...XXX..
""",
			"""
.XXXXXXX
.XXXXXXX
.XXXXXXX
.XXXXXXX
""",
			"""
...XXX..
...XXX..
...XXX..
...X....
""",
		],
	},
	"celestial_horse": {
		"display": "Celestial Horse",
		"layers": [
			"""
.......X
.......X
.....XXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
X...XX..
X...XX..
X...XX..
""",
			"""
........
........
........
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
""",
			"""
........
........
........
.XXXXXX.
.XXXXXX.
.XXXXXX.
""",
			"""
........
........
........
..XXXX..
..XXXX..
..XX....
""",
		],
	},
	"lotus_pond": {
		"display": "Lotus Pond",
		"layers": [
			"""
XXXXXXXX
XXXXXXXX
.XXX..XX
....X...
.X..X..X
XXX.X.XX
XXXXXXXX
XXXXXXXX
.XXXXXXX
XXXXXXXX
""",
			"""
........
........
........
........
........
........
..XXXXX.
..XXXXX.
..XXXXX.
..XXXXX.
""",
			"""
........
........
........
........
........
........
...XXX..
...XXX..
...XXX..
...XXX..
""",
		],
	},
	"great_bell": {
		"display": "Great Bell",
		"layers": [
			"""
...XXX..
..XXXXX.
.XXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
XXXXXXXX
""",
			"""
........
........
........
..XXXXX.
..XXXXX.
..XXXXX.
..XXXXX.
..XXXXX.
..XXXXX.
..XXXXX.
""",
			"""
........
........
........
........
........
...XXX..
...XXX..
...XXX..
...XXX..
...XX...
""",
		],
	},
}
