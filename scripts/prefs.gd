class_name Prefs
extends RefCounted

const PATH := "user://settings.cfg"
const MODELS := "res://Assets/kenney_blocky-characters_20/Models/GLB format/"
const OUTFITS := [
	"res://Assets/kenney_mini-shop_2.1/Models/GLB format/character-employee.glb",
	MODELS + "character-b.glb", MODELS + "character-d.glb", MODELS + "character-h.glb",
	MODELS + "character-m.glb", MODELS + "character-p.glb",
]
const HATS := ["None", "Toque", "Songkok", "Cap"]

const ACHIEVEMENTS := {
	"first_serve": ["First order", "Serve your first dish."],
	"perfect": ["Perfect service", "Serve 5 dishes in a row with over 60% of the timer left."],
	"combo5": ["Hot streak", "Reach combo x5."],
	"no_fires": ["No fires", "Win a level without a single fire."],
	"trained": ["Graduate", "Finish the training."],
	"boss": ["Chaos survivor", "Win the boss level."],
	"critic": ["Critic's choice", "Serve the food critic in time."],
	"cat": ["Cat whisperer", "Shoo the cat off the counter."],
}

static var ui_scale := 1.0
static var text_scale := 1.0
static var colorblind := false
static var lang := "en"
static var outfit := 0
static var outfit2 := 1
static var hat := 1
static var hat2 := 0
static var help_always := false
static var music_on := true
static var music_vol := 0.7
static var favs: Array = []
static var learned := {}
static var ach := {}
static var _loaded := false


static func load_prefs() -> void:
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	ui_scale = clampf(float(cf.get_value("prefs", "ui_scale", 1.0)), 0.85, 1.15)
	text_scale = clampf(float(cf.get_value("prefs", "text_scale", 1.0)), 0.85, 1.3)
	colorblind = bool(cf.get_value("prefs", "colorblind", false))
	lang = String(cf.get_value("prefs", "lang", "en"))
	outfit = clampi(int(cf.get_value("prefs", "outfit", 0)), 0, OUTFITS.size() - 1)
	outfit2 = clampi(int(cf.get_value("prefs", "outfit2", 1)), 0, OUTFITS.size() - 1)
	hat = clampi(int(cf.get_value("prefs", "hat", 1)), 0, HATS.size() - 1)
	hat2 = clampi(int(cf.get_value("prefs", "hat2", 0)), 0, HATS.size() - 1)
	help_always = bool(cf.get_value("prefs", "help_always", false))
	music_on = bool(cf.get_value("prefs", "music_on", true))
	music_vol = clampf(float(cf.get_value("prefs", "music_vol", 0.7)), 0.0, 1.0)
	favs = Array(cf.get_value("prefs", "favs", []))
	learned = Dictionary(cf.get_value("prefs", "learned", {}))
	ach = Dictionary(cf.get_value("prefs", "ach", {}))


static func save() -> void:
	var cf := ConfigFile.new()
	cf.load(PATH)
	cf.set_value("prefs", "ui_scale", ui_scale)
	cf.set_value("prefs", "text_scale", text_scale)
	cf.set_value("prefs", "colorblind", colorblind)
	cf.set_value("prefs", "lang", lang)
	cf.set_value("prefs", "outfit", outfit)
	cf.set_value("prefs", "outfit2", outfit2)
	cf.set_value("prefs", "hat", hat)
	cf.set_value("prefs", "hat2", hat2)
	cf.set_value("prefs", "help_always", help_always)
	cf.set_value("prefs", "music_on", music_on)
	cf.set_value("prefs", "music_vol", music_vol)
	cf.set_value("prefs", "favs", favs)
	cf.set_value("prefs", "learned", learned)
	cf.set_value("prefs", "ach", ach)
	cf.save(PATH)


static func apply_audio() -> void:
	var i := AudioServer.get_bus_index("Music")
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, "Music")
	AudioServer.set_bus_mute(i, not music_on)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(music_vol, 0.0001)))


static func apply_window() -> void:
	(Engine.get_main_loop() as SceneTree).root.content_scale_factor = ui_scale


static func learn(dish: String) -> void:
	if not learned.has(dish):
		learned[dish] = true
		save()


static func toggle_fav(id: String) -> void:
	if favs.has(id):
		favs.erase(id)
	else:
		favs.append(id)
	save()


# Returns true the first time an achievement is earned.
static func award(id: String) -> bool:
	if ach.has(id) or not ACHIEVEMENTS.has(id):
		return false
	ach[id] = true
	save()
	return true
