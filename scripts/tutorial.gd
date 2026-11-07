class_name Tutorial
extends Node

signal finished

var chef: Chef
var game: Game
var _steps: Array[Dictionary] = []
var _i := -1
var _moved := 0.0
var _last_pos := Vector3.ZERO
var _ran := 0.0
var _panel := PanelContainer.new()
var _count: Label
var _title: Label
var _body: Label
var _keys := HBoxContainer.new()
var _bar: ProgressBar
var _skip: Button
var _flash := 0.0
var _done_steps := 0


func setup(c: Chef, g: Game) -> void:
	chef = c
	game = g
	_last_pos = c.global_position
	_define()
	_build()
	game.served_ok.connect(func(): _served = true)
	_next()


var _served := false


func _st(kind: Station.Kind, crate := "") -> Station:
	for s in chef.stations:
		if s.kind == kind and (crate == "" or s.crate_id == crate):
			return s
	return null


func _held_is(id: String, state: String) -> bool:
	return chef.held is Ingredient and (chef.held as Ingredient).ingredient_id == id and (chef.held as Ingredient).state == state


func _in_station(kind: Station.Kind, id: String, state: String) -> bool:
	var s := _st(kind)
	return s != null and s.item is Ingredient and (s.item as Ingredient).ingredient_id == id and (s.item as Ingredient).state == state


func _define() -> void:
	var K := Station.Kind
	_steps = [
		{"t": "Walk around", "b": "Use these keys to move around the kitchen.", "keys": ["move_up", "move_left", "move_down", "move_right"],
			"ok": func(): return _moved > 5.0, "bar": func(): return _moved / 5.0},
		{"t": "Run", "b": "HOLD Shift while you move to run.", "keys": ["dash"],
			"ok": func(): return _ran > 1.0, "bar": func(): return _ran},
		{"t": "Dash", "b": "TAP Shift once to dash and hop. It recharges fast.", "keys": ["dash"],
			"ok": func(): return chef._dash > 0.0},
		{"t": "Grab batter", "b": "Walk to the green BATTER crate and take some.", "keys": ["interact"],
			"guide": func(): return [_st(K.CRATE, "batter")] if chef.held == null else [],
			"ok": func(): return _held_is("batter", "raw")},
		{"t": "Mix it", "b": "Put the batter in the MIXER, then HOLD the work key until the bar is full.", "keys": ["interact", "work"],
			"guide": func(): return [_st(K.MIXER)],
			"ok": func(): return _in_station(K.MIXER, "batter", "mixed") or _held_is("batter", "mixed")},
		{"t": "Take the batter", "b": "Pick the mixed batter up from the mixer.", "keys": ["interact"],
			"guide": func(): return [_st(K.MIXER)],
			"ok": func(): return _held_is("batter", "mixed")},
		{"t": "Set it down", "b": "Put the batter on any counter for now.", "keys": ["interact"],
			"guide": func(): return [_st(K.COUNTER)],
			"ok": func(): return chef.held == null},
		{"t": "Fry chicken", "b": "Take chicken from its crate and put it in the WOK. Take it out when it is golden, before it burns.", "keys": ["interact"],
			"guide": func(): return [_st(K.CRATE, "chicken")] if chef.held == null and not _in_station(K.FRY, "chicken", "cooked") else [_st(K.FRY)],
			"ok": func(): return _in_station(K.FRY, "chicken", "cooked") or _held_is("chicken", "cooked")},
		{"t": "Plate it", "b": "Take a clean plate. Then stand next to the food and press the pick key to add each item to the plate.", "keys": ["interact"],
			"guide": func(): return [_st(K.PLATES)] if chef.held == null else [],
			"ok": func(): return chef.held is Vessel and Recipes.dish_of((chef.held as Vessel).contents) == "roti_jala"},
		{"t": "Serve", "b": "Carry the finished Roti Jala to the SERVE hatch on the right wall. The order is on the ticket.", "keys": ["interact"],
			"guide": func(): return [_st(K.HATCH)],
			"enter": func(): game.add_order("roti_jala"),
			"ok": func(): return _served},
	]


func _build() -> void:
	_panel.theme = UiKit.theme()
	_panel.add_theme_stylebox_override("panel", UiKit.box(Color(0.09, 0.3, 0.28, 0.96), UiKit.GOLD, 3, 16, 10))
	_panel.position = Vector2(10, 6)
	_panel.custom_minimum_size = Vector2(700, 96)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	_count = UiKit.lbl("", 15, UiKit.GOLD, 4)
	head.add_child(_count)
	_title = UiKit.lbl("", 22, UiKit.GOLD, 6)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_skip = UiKit.button("Skip", Color(0.35, 0.25, 0.2), 14)
	_skip.pressed.connect(_finish)
	head.add_child(_skip)
	v.add_child(head)
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 14)
	_body = UiKit.lbl("", 17, UiKit.CREAM)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(420, 0)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(_body)
	_keys.add_theme_constant_override("separation", 5)
	_keys.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.add_child(_keys)
	v.add_child(mid)
	_bar = ProgressBar.new()
	_bar.max_value = _steps.size()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 8)
	_bar.add_theme_stylebox_override("background", UiKit.box(Color(0.05, 0.15, 0.14), Color(0, 0, 0, 0), 0, 4, 0, false))
	_bar.add_theme_stylebox_override("fill", UiKit.box(UiKit.GOLD, Color(0, 0, 0, 0), 0, 4, 0, false))
	v.add_child(_bar)
	_panel.add_child(v)
	game.ui.add_child(_panel)


func _next() -> void:
	_i += 1
	_clear_guides()
	if _i >= _steps.size():
		_complete()
		return
	var s: Dictionary = _steps[_i]
	_count.text = "STEP %d/%d" % [_i + 1, _steps.size()]
	_title.text = String(s["t"])
	_body.text = String(s["b"])
	_bar.value = _i
	for c in _keys.get_children():
		c.queue_free()
	for a in s["keys"]:
		var col := VBoxContainer.new()
		col.add_child(UiKit.action_key(String(a), 38))
		_keys.add_child(col)
	if s.has("enter"):
		(s["enter"] as Callable).call()
	_moved = 0.0
	_ran = 0.0
	_flash = 0.0
	Sfx.play("pick")


func _clear_guides() -> void:
	for st in chef.stations:
		st.guide = false


func _complete() -> void:
	_title.text = "You are ready!"
	_count.text = "DONE"
	_body.text = "That is the whole loop: grab, prep, plate, serve. Watch the Malaysia Meter and keep orders flowing."
	_bar.value = _steps.size()
	for c in _keys.get_children():
		c.queue_free()
	_skip.text = "Start Level 1"
	_skip.pressed.disconnect(_finish)
	_skip.pressed.connect(_finish)
	_skip.add_theme_font_size_override("font_size", 18)
	Sfx.play("serve")
	Recipes.tutorial_done = true
	Recipes.save_flags()


func _finish() -> void:
	Recipes.tutorial = false
	Recipes.level = 0
	game.get_tree().paused = false
	game.get_tree().reload_current_scene()


func _process(delta: float) -> void:
	if _i < 0 or _i >= _steps.size() or game.get_tree().paused:
		return
	var d := chef.global_position - _last_pos
	d.y = 0
	_moved += d.length()
	_last_pos = chef.global_position
	if Input.is_action_pressed("dash") and d.length() > 0.02:
		_ran += delta
	var s: Dictionary = _steps[_i]
	_clear_guides()
	if s.has("guide"):
		for st in (s["guide"] as Callable).call():
			if st:
				st.guide = true
	if s.has("bar"):
		_bar.value = _i + clampf((s["bar"] as Callable).call(), 0.0, 1.0)
	if (s["ok"] as Callable).call():
		_done_steps += 1
		_next()
