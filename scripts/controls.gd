class_name Controls
extends RefCounted

const PATH := "user://settings.cfg"

# [action, label, group]  group 0 = Player 1, 1 = Player 2, 2 = General
const ROWS := [
	["move_up", "Move up", 0], ["move_down", "Move down", 0], ["move_left", "Move left", 0], ["move_right", "Move right", 0],
	["interact", "Pick up / put down", 0], ["work", "Chop / mix / wash", 0], ["dash", "Run (hold) / Dash (tap)", 0],
	["p2_move_up", "Move up", 1], ["p2_move_down", "Move down", 1], ["p2_move_left", "Move left", 1], ["p2_move_right", "Move right", 1],
	["p2_interact", "Pick up / put down", 1], ["p2_work", "Chop / mix / wash", 1], ["p2_dash", "Run (hold) / Dash (tap)", 1],
	["recipe_book", "Recipe book", 2], ["restart", "Restart level", 2],
]

const DEFAULTS := {
	"move_up": KEY_W, "move_down": KEY_S, "move_left": KEY_A, "move_right": KEY_D,
	"interact": KEY_E, "work": KEY_Q, "dash": KEY_SHIFT,
	"p2_move_up": KEY_UP, "p2_move_down": KEY_DOWN, "p2_move_left": KEY_LEFT, "p2_move_right": KEY_RIGHT,
	"p2_interact": KEY_ENTER, "p2_work": KEY_SLASH, "p2_dash": KEY_PERIOD,
	"recipe_book": KEY_B, "restart": KEY_R,
}

const NAMES := {
	KEY_UP: "↑", KEY_DOWN: "↓", KEY_LEFT: "←", KEY_RIGHT: "→", KEY_SLASH: "/", KEY_PERIOD: ".",
	KEY_COMMA: ",", KEY_ENTER: "Enter", KEY_KP_ENTER: "Enter", KEY_SPACE: "Space", KEY_SHIFT: "Shift",
	KEY_CTRL: "Ctrl", KEY_ALT: "Alt", KEY_TAB: "Tab", KEY_ESCAPE: "Esc",
}

static var keys := {}
static var _loaded := false


static func load_settings() -> void:
	keys = DEFAULTS.duplicate()
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		for a in DEFAULTS:
			keys[a] = int(cf.get_value("keys", a, DEFAULTS[a]))
	_loaded = true


static func save() -> void:
	var cf := ConfigFile.new()
	cf.load(PATH)
	for a in keys:
		cf.set_value("keys", a, keys[a])
	cf.save(PATH)


static func reset() -> void:
	keys = DEFAULTS.duplicate()
	save()
	apply()


static func set_key(action: String, code: int) -> void:
	for a in keys:
		if a != action and keys[a] == code:
			keys[a] = keys[action]
	keys[action] = code
	save()
	apply()


static func key_name(action: String) -> String:
	if not _loaded:
		load_settings()
	var code: int = keys.get(action, 0)
	return NAMES.get(code, OS.get_keycode_string(code))


static func _add(action: String, code: int) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	InputMap.action_add_event(action, ev)


# P1 actions also answer to the P2 keys when playing alone.
static func apply() -> void:
	if not _loaded:
		load_settings()
	for a in keys:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		InputMap.action_erase_events(a)
		_add(a, keys[a])
		if not Recipes.coop and not a.begins_with("p2_") and keys.has("p2_" + a):
			_add(a, keys["p2_" + a])
	if not InputMap.has_action("menu"):
		InputMap.add_action("menu")
	InputMap.action_erase_events("menu")
	_add("menu", KEY_ESCAPE)
	if Recipes.coop:
		return
	if InputMap.has_action("interact"):
		_add("interact", KEY_SPACE)
		_add("work", KEY_CTRL)
