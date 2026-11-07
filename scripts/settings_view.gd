class_name SettingsView
extends VBoxContainer

signal closed

var _group := 0
var _listening := ""
var _listen_btn: Button
var _rows := VBoxContainer.new()
var _tabs: Array[Button] = []
var _hint: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_constant_override("separation", 10)
	var title := UiKit.lbl(Lang.t("Settings"), 38, UiKit.GOLD, 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var tab_row := HBoxContainer.new()
	tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_row.add_theme_constant_override("separation", 10)
	for i in 5:
		var b := UiKit.button(Lang.t(["Player 1", "Player 2", "General", "Display", "Audio and Look"][i]), UiKit.RED, 20)
		b.pressed.connect(_pick.bind(i))
		tab_row.add_child(b)
		_tabs.append(b)
	add_child(tab_row)
	_hint = UiKit.lbl("Click a key, then press the new key.  Esc cancels.", 16, UiKit.CREAM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint)
	_rows.add_theme_constant_override("separation", 6)
	_rows.custom_minimum_size = Vector2(520, 0)
	_rows.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(_rows)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_theme_constant_override("separation", 12)
	var reset := UiKit.button(Lang.t("Reset to defaults"), Color(0.35, 0.25, 0.2), 20)
	reset.pressed.connect(func():
		Controls.reset()
		_build())
	foot.add_child(reset)
	var done := UiKit.button(Lang.t("Done"), UiKit.TEAL, 22)
	done.pressed.connect(func(): closed.emit())
	foot.add_child(done)
	add_child(foot)
	_pick(0)
	done.grab_focus()


func _pick(g: int) -> void:
	_group = g
	_cancel()
	for i in _tabs.size():
		_tabs[i].modulate = Color.WHITE if i == g else Color(0.7, 0.65, 0.6)
	_build()


func _build() -> void:
	for c in _rows.get_children():
		c.queue_free()
	_hint.visible = _group < 3
	if _group == 3:
		_build_display()
		return
	if _group == 4:
		_build_look()
		return
	for r in Controls.ROWS:
		if int(r[2]) != _group:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var l := UiKit.lbl(String(r[1]), 20, UiKit.CREAM)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)
		var b := UiKit.button(Controls.key_name(r[0]), Color(0.3, 0.14, 0.1), 20)
		b.custom_minimum_size = Vector2(150, 0)
		b.pressed.connect(_listen.bind(String(r[0]), b))
		row.add_child(b)
		_rows.add_child(row)


func _listen(action: String, b: Button) -> void:
	_cancel()
	_listening = action
	_listen_btn = b
	b.text = "press a key..."
	b.modulate = Color(1, 0.9, 0.4)


func _cancel() -> void:
	if _listening != "" and is_instance_valid(_listen_btn):
		_listen_btn.text = Controls.key_name(_listening)
		_listen_btn.modulate = Color.WHITE
	_listening = ""


func _input(e: InputEvent) -> void:
	if _listening == "" or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	get_viewport().set_input_as_handled()
	var k := (e as InputEventKey).physical_keycode
	if k == KEY_ESCAPE:
		_cancel()
		return
	Controls.set_key(_listening, k)
	Sfx.play("pick")
	_listening = ""
	_build()


func _row(label: String, ctl: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var l := UiKit.lbl(Lang.t(label), 20, UiKit.CREAM)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	row.add_child(ctl)
	_rows.add_child(row)


func _cycle(text: String, fn: Callable) -> Button:
	var b := UiKit.button(text, Color(0.3, 0.14, 0.1), 20)
	b.custom_minimum_size = Vector2(190, 0)
	b.pressed.connect(fn)
	return b


func _slider(v: float, lo: float, hi: float, fn: Callable) -> HSlider:
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = 0.05
	sl.value = v
	sl.custom_minimum_size = Vector2(190, 28)
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sl.drag_ended.connect(func(_c): fn.call(sl.value))
	return sl


func _build_display() -> void:
	var lang_b := _cycle("English" if Prefs.lang == "en" else "Bahasa Melayu", func():
		Prefs.lang = "ms" if Prefs.lang == "en" else "en"
		Prefs.save()
		closed.emit())
	_row("Language", lang_b)
	_row("UI size", _slider(Prefs.ui_scale, 0.85, 1.15, func(v):
		Prefs.ui_scale = v
		Prefs.apply_window()
		Prefs.save()))
	_row("Text size", _slider(Prefs.text_scale, 0.85, 1.3, func(v):
		Prefs.text_scale = v
		Prefs.save()))
	var cb := _cycle("On" if Prefs.colorblind else "Off", func(): pass)
	cb.pressed.connect(func():
		Prefs.colorblind = not Prefs.colorblind
		cb.text = "On" if Prefs.colorblind else "Off"
		Prefs.save())
	_row("Colour-blind mode", cb)
	var hb := _cycle("On" if Prefs.help_always else "Off", func(): pass)
	hb.pressed.connect(func():
		Prefs.help_always = not Prefs.help_always
		hb.text = "On" if Prefs.help_always else "Off"
		Prefs.save())
	_row("Always show help bar", hb)


func _build_look() -> void:
	var mb := _cycle("On" if Prefs.music_on else "Off", func(): pass)
	mb.pressed.connect(func():
		Prefs.music_on = not Prefs.music_on
		mb.text = "On" if Prefs.music_on else "Off"
		Prefs.apply_audio()
		Prefs.save())
	_row("Music", mb)
	var vs := HSlider.new()
	vs.min_value = 0.0
	vs.max_value = 1.0
	vs.step = 0.05
	vs.value = Prefs.music_vol
	vs.custom_minimum_size = Vector2(130, 28)
	vs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var vl := UiKit.lbl("%d%%" % roundi(Prefs.music_vol * 100.0), 20, UiKit.CREAM)
	vl.custom_minimum_size = Vector2(54, 0)
	vl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vs.value_changed.connect(func(v):
		Prefs.music_vol = v
		vl.text = "%d%%" % roundi(v * 100.0)
		Prefs.apply_audio())
	vs.drag_ended.connect(func(_c): Prefs.save())
	vs.focus_exited.connect(Prefs.save)
	var vbox := HBoxContainer.new()
	vbox.add_child(vs)
	vbox.add_child(vl)
	_row("Music volume", vbox)
	for p in 2:
		var ob := _cycle("", func(): pass)
		var hb := _cycle("", func(): pass)
		var refresh := func():
			ob.text = "Outfit %d" % ((Prefs.outfit if p == 0 else Prefs.outfit2) + 1)
			hb.text = Prefs.HATS[Prefs.hat if p == 0 else Prefs.hat2]
		refresh.call()
		ob.pressed.connect(func():
			if p == 0:
				Prefs.outfit = (Prefs.outfit + 1) % Prefs.OUTFITS.size()
			else:
				Prefs.outfit2 = (Prefs.outfit2 + 1) % Prefs.OUTFITS.size()
			Prefs.save()
			refresh.call())
		hb.pressed.connect(func():
			if p == 0:
				Prefs.hat = (Prefs.hat + 1) % Prefs.HATS.size()
			else:
				Prefs.hat2 = (Prefs.hat2 + 1) % Prefs.HATS.size()
			Prefs.save()
			refresh.call())
		_row("%s: %s" % [Lang.t("Chef style"), Lang.t("Player %d") % (p + 1)], ob)
		_row("%s: %s" % [Lang.t("Hat"), Lang.t("Player %d") % (p + 1)], hb)
