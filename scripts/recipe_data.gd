class_name Recipes
extends RefCounted

const POLICE_LINE := 50.0
const SAVE_PATH := "user://save.cfg"

# Level 4 is the boss: every dish at once.
const LEVELS := [
	{"name": "Morning Stall", "sub": "Morning stall", "dishes": ["roti_jala", "teh_tarik"], "spawn": 22.0, "max": 3, "hold": 15.0, "boss": false},
	{"name": "Rainy Afternoon", "sub": "Rainy afternoon", "dishes": ["roti_jala", "teh_tarik", "karipap"], "spawn": 18.0, "max": 4, "hold": 20.0, "boss": false},
	{"name": "Night Market", "sub": "Night market", "dishes": ["nasi_lemak", "karipap", "teh_tarik"], "spawn": 15.0, "max": 4, "hold": 25.0, "boss": false},
	{"name": "Chaos Night", "sub": "Boss: every dish", "dishes": ["roti_jala", "karipap", "nasi_lemak", "teh_tarik"], "spawn": 11.0, "max": 5, "hold": 40.0, "boss": true},
]

static var level := 0
static var unlocked := 1
static var seen := {}
static var coop := false
static var tutorial := false
static var tutorial_done := false
static var stars := {}

const TUTORIAL := {"name": "Training", "sub": "Learn the basics", "dishes": ["roti_jala"], "spawn": 9999.0, "max": 1, "hold": 9999.0, "boss": false}

const ITEM_NAMES := {
	"batter:mixed": "Mixed batter",
	"chicken:cooked": "Fried chicken",
	"shallot:chopped": "Sliced shallot",
	"rice:cooked": "Rice",
	"anchovy:cooked": "Fried anchovy",
	"cucumber:chopped": "Sliced cucumber",
	"sambal:mixed": "Sambal",
	"teh:tarik": "Pulled tea",
}

# Picture steps: "in" -> station "at" -> "out". Keys are Thumbs keys.
const DISHES := {
	"roti_jala": {
		"name": "Roti Jala",
		"sub": "Lacy net crepe",
		"items": ["batter:mixed", "chicken:cooked"],
		"time": 80.0,
		"points": 8.0,
		"teach": "Roti jala means 'net bread'. Batter is poured through a perforated cup in circles to make a lacy crepe. It is usually eaten with chicken curry, and is a favourite at Ramadan bazaars.",
		"visual": [
			{"in": ["batter:raw"], "at": "kit:mixing-bowl", "at_name": "MIX", "out": "batter:mixed", "text": "Put the batter in the mixer and HOLD Q until it is smooth."},
			{"in": ["chicken:raw"], "at": "kit:wok", "at_name": "FRY", "out": "chicken:cooked", "text": "Fry until golden. Take it out before it burns!"},
			{"in": ["plate", "batter:mixed", "chicken:cooked"], "at": "", "out": "dish:roti_jala", "text": "Carry a clean plate and put both on it."},
			{"in": ["dish:roti_jala"], "at": "kit:serving-hatch", "at_name": "SERVE", "out": "icon:lorc/trophy.png", "text": "Serve it at the hatch before the order timer runs out."},
		],
	},
	"karipap": {
		"name": "Karipap",
		"sub": "Curry puff",
		"items": ["batter:mixed", "chicken:cooked", "shallot:chopped"],
		"time": 90.0,
		"points": 10.0,
		"teach": "Karipap is a deep-fried pastry filled with spiced chicken, potato and onion. The pleated edge is hand-crimped. It is a teatime snack, thought to come from Indian samosa and British pasty influence.",
		"visual": [
			{"in": ["batter:raw"], "at": "kit:mixing-bowl", "at_name": "MIX", "out": "batter:mixed", "text": "Mix the dough batter: HOLD Q."},
			{"in": ["chicken:raw"], "at": "kit:wok", "at_name": "FRY", "out": "chicken:cooked", "text": "Fry the chicken filling."},
			{"in": ["shallot:raw"], "at": "food:cutting-board", "at_name": "CHOP", "out": "shallot:chopped", "text": "Tap Q again and again to chop."},
			{"in": ["plate", "batter:mixed", "chicken:cooked", "shallot:chopped"], "at": "", "out": "dish:karipap", "text": "All three go on one plate."},
			{"in": ["dish:karipap"], "at": "kit:serving-hatch", "at_name": "SERVE", "out": "icon:lorc/trophy.png", "text": "Serve it at the hatch."},
		],
	},
	"nasi_lemak": {
		"name": "Nasi Lemak",
		"sub": "Coconut rice plate",
		"items": ["rice:cooked", "anchovy:cooked", "cucumber:chopped", "sambal:mixed"],
		"time": 110.0,
		"points": 14.0,
		"teach": "Nasi lemak is rice cooked in coconut milk and pandan, served with sambal, fried anchovies, peanuts, cucumber and egg. Many Malaysians call it the national dish. It is traditionally wrapped in banana leaf.",
		"visual": [
			{"in": ["rice:raw"], "at": "food:pot-stew", "at_name": "BOIL", "out": "rice:cooked", "text": "Boil the rice until it is cooked."},
			{"in": ["anchovy:raw"], "at": "kit:wok", "at_name": "FRY", "out": "anchovy:cooked", "text": "Fry the anchovies until crisp."},
			{"in": ["cucumber:raw"], "at": "food:cutting-board", "at_name": "CHOP", "out": "cucumber:chopped", "text": "Tap Q to slice the cucumber."},
			{"in": ["sambal:raw"], "at": "kit:mixing-bowl", "at_name": "MIX", "out": "sambal:mixed", "text": "HOLD Q to stir the sambal."},
			{"in": ["plate", "rice:cooked", "anchovy:cooked", "cucumber:chopped", "sambal:mixed"], "at": "", "out": "dish:nasi_lemak", "text": "All four go on one plate."},
			{"in": ["dish:nasi_lemak"], "at": "kit:serving-hatch", "at_name": "SERVE", "out": "icon:lorc/trophy.png", "text": "Serve it at the hatch."},
		],
	},
	"teh_tarik": {
		"name": "Teh Tarik",
		"sub": "Pulled milk tea",
		"items": ["teh:tarik"],
		"time": 60.0,
		"points": 6.0,
		"teach": "Teh tarik means 'pulled tea'. Sweet milk tea is poured back and forth between two vessels from a height. This cools it and makes a thick foam. It is the drink of every mamak stall.",
		"visual": [
			{"in": ["glass"], "at": "kit:kettle", "at_name": "PULL TEA", "out": "teh:tarik", "text": "Put an empty glass on PULL TEA and tap Q eight times."},
			{"in": ["teh:tarik"], "at": "kit:serving-hatch", "at_name": "SERVE", "out": "icon:lorc/trophy.png", "text": "Pick the glass up and serve it."},
		],
	},
}

const TIPS := [
	"Malaysia has many food traditions, mainly Malay, Chinese and Indian. Many dishes blend all three.",
	"Sambal is a chilli paste. Every family has its own recipe, and it can make or break a dish.",
	"Ikan bilis are dried anchovies. Fried until crisp, they are the crunch in nasi lemak.",
	"A mamak stall is an Indian-Muslim eatery. Many are open 24 hours, and teh tarik is their signature drink.",
	"Pandan leaves give rice a sweet, grassy aroma. They are used in both savoury and sweet dishes.",
	"Malaysians often eat with a spoon and fork, and sometimes with the right hand.",
	"Pasar malam means night market. Stalls sell snacks, drinks and street food after sunset.",
	"Coconut milk (santan) is the base of many curries and of nasi lemak rice.",
]


static func key_of(contents: Array) -> String:
	var c := contents.duplicate()
	c.sort()
	return ",".join(PackedStringArray(c))


static func dish_of(contents: Array) -> String:
	if contents.is_empty():
		return ""
	var k := key_of(contents)
	for d in DISHES:
		if key_of(DISHES[d]["items"]) == k:
			return d
	return ""


static func load_progress() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		unlocked = clampi(int(cf.get_value("progress", "unlocked", 1)), 1, LEVELS.size())
		tutorial_done = bool(cf.get_value("progress", "tutorial", false))
		for i in LEVELS.size():
			stars[i] = int(cf.get_value("stars", str(i), 0))


static func save_flags() -> void:
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	cf.set_value("progress", "unlocked", unlocked)
	cf.set_value("progress", "tutorial", tutorial_done)
	for i in stars:
		cf.set_value("stars", str(i), stars[i])
	cf.save(SAVE_PATH)


static func unlock(n: int) -> void:
	unlocked = clampi(maxi(unlocked, n), 1, LEVELS.size())
	save_flags()


static func record_stars(i: int, n: int) -> void:
	stars[i] = maxi(int(stars.get(i, 0)), n)
	save_flags()
