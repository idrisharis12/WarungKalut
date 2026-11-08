extends Control

const SKY := "res://Assets/kenney_skyboxes/Skyboxes/skybox-day.png"
const SHOP := "res://Assets/kenney_mini-shop_2.1/Models/GLB format/"

var _stage := Control.new()
var _hero: Control


func _ready() -> void:
	Recipes.load_progress()
	Controls.load_settings()
	Prefs.load_prefs()
	Gp.init()
	Prefs.apply_window()
	Recipes.tutorial = false
	theme = UiKit.theme()
	_backdrop()
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_stage)
	Sfx.music()
	_title_screen()


func _backdrop() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.45, 0.11, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var art := TextureRect.new()
	art.texture = load("res://Assets/dishes/backdrop.jpg")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(art)
	var pat := TextureRect.new()
	pat.texture = _batik()
	pat.stretch_mode = TextureRect.STRETCH_TILE
	pat.set_anchors_preset(Control.PRESET_FULL_RECT)
	pat.modulate = Color(1, 1, 1, 0.12)
	add_child(pat)
	var shade := ColorRect.new()
	shade.color = Color(0.1, 0.03, 0.03, 0.5)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)


func _batik() -> ImageTexture:
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	var base := Color(0.62, 0.2, 0.15)
	var gold := Color(0.95, 0.75, 0.3)
	var teal := Color(0.1, 0.45, 0.42)
	for y in 128:
		for x in 128:
			var d := absf(fmod(x, 64.0) - 32.0) + absf(fmod(y, 64.0) - 32.0)
			var c := base
			if d < 8.0:
				c = gold
			elif d < 16.0:
				c = teal
			elif absf(d - 32.0) < 3.0:
				c = gold.darkened(0.25)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _clear() -> void:
	for c in _stage.get_children():
		c.queue_free()


func _center(box: Control) -> void:
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH


func _title_screen() -> void:
	_clear()
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 8)
	_center(v)
	_stage.add_child(v)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	for k in ["dish:nasi_lemak", "dish:teh_tarik", "dish:karipap", "dish:roti_jala"]:
		row.add_child(UiKit.thumb(k, 96))
	v.add_child(row)
	var t := UiKit.lbl("WARUNG KALUT", 80, UiKit.GOLD, 16)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := UiKit.lbl(Lang.t("Cook in chaos. Learn Malaysian food."), 26, UiKit.CREAM, 8)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	v.add_child(sp)
	var start := UiKit.button(Lang.t("START"), UiKit.TEAL, 38)
	start.custom_minimum_size = Vector2(320, 0)
	start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start.pressed.connect(_levels)
	v.add_child(start)
	var co := UiKit.button("", UiKit.RED, 24)
	var set_label := func(): co.text = "Players: 2  (WASD + Arrows)" if Recipes.coop else Lang.t("Players: 1")
	set_label.call()
	co.custom_minimum_size = Vector2(320, 0)
	co.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	co.pressed.connect(func():
		Recipes.coop = not Recipes.coop
		set_label.call())
	v.add_child(co)
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 12)
	var tut := UiKit.button(Lang.t("Training"), UiKit.LEAF.darkened(0.35), 22)
	tut.custom_minimum_size = Vector2(154, 0)
	tut.pressed.connect(func():
		Recipes.tutorial = true
		Recipes.level = 0
		Fx.go("res://scenes/main.tscn"))
	bottom.add_child(tut)
	var st := UiKit.button(Lang.t("Settings"), Color(0.3, 0.2, 0.3), 22)
	st.custom_minimum_size = Vector2(154, 0)
	st.pressed.connect(_settings)
	bottom.add_child(st)
	v.add_child(bottom)
	if not Recipes.tutorial_done:
		var nudge := UiKit.lbl(Lang.t("New here? Try Training first!"), 18, Color(0.6, 1.0, 0.55), 6)
		nudge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nudge)
		var tw := nudge.create_tween().set_loops()
		tw.tween_property(nudge, "modulate:a", 0.45, 0.7)
		tw.tween_property(nudge, "modulate:a", 1.0, 0.7)
	var quit := UiKit.button(Lang.t("Quit"), Color(0.35, 0.25, 0.2), 24)
	quit.custom_minimum_size = Vector2(320, 0)
	quit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quit.pressed.connect(func(): get_tree().quit())
	v.add_child(quit)
	var credit := UiKit.lbl("Kenney (CC0)  -  game-icons.net (CC BY 3.0)", 14, Color(1, 1, 1, 0.6))
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(credit)
	start.grab_focus()


func _settings() -> void:
	_clear()
	var holder := PanelContainer.new()
	var solid := UiKit.DARK
	solid.a = 0.97
	holder.add_theme_stylebox_override("panel", UiKit.box(solid, UiKit.GOLD, 5, 22, 22))
	_center(holder)
	var sv := SettingsView.new()
	sv.closed.connect(_title_screen)
	holder.add_child(sv)
	_stage.add_child(holder)


func _levels() -> void:
	_clear()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	_center(v)
	_stage.add_child(v)
	var t := UiKit.lbl(Lang.t("Select Level"), 56, UiKit.GOLD, 14)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	v.add_child(row)
	var first: Button
	for i in Recipes.LEVELS.size():
		var card := _level_card(i)
		row.add_child(card[0])
		if first == null and not card[1].disabled:
			first = card[1]
	var back := UiKit.button(Lang.t("Back"), Color(0.35, 0.25, 0.2), 22)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_title_screen)
	v.add_child(back)
	if first:
		first.grab_focus()


func _level_card(i: int) -> Array:
	var lv: Dictionary = Recipes.LEVELS[i]
	var open := i < Recipes.unlocked
	var boss: bool = lv["boss"]
	var pc := PanelContainer.new()
	var border := Color(0.95, 0.25, 0.2) if boss else UiKit.GOLD
	pc.add_theme_stylebox_override("panel", UiKit.box(UiKit.CREAM if open else Color(0.55, 0.5, 0.45), border, 5 if boss else 4, 20, 14))
	pc.custom_minimum_size = Vector2(240, 0)
	pc.size_flags_vertical = Control.SIZE_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pc.add_child(v)
	var num := UiKit.lbl(Lang.t("BOSS") if boss else Lang.t("Level %d") % (i + 1), 20, Color(0.8, 0.1, 0.1) if boss else UiKit.RED)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(num)
	var nm := UiKit.lbl(String(lv["name"]), 26, UiKit.INK)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(nm)
	var sub := UiKit.lbl(String(lv["sub"]), 15, Color(0.4, 0.3, 0.25))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.custom_minimum_size = Vector2(0, 200)
	for d in lv["dishes"]:
		var th := UiKit.thumb("dish:" + String(d), 84)
		if not open:
			th.modulate = Color(0.2, 0.2, 0.2, 0.7)
		grid.add_child(th)
	v.add_child(grid)
	var sr := HBoxContainer.new()
	sr.alignment = BoxContainer.ALIGNMENT_CENTER
	for k in 3:
		sr.add_child(UiKit.icon("delapouite/star-medal.png", 30, UiKit.GOLD if k < int(Recipes.stars.get(i, 0)) else Color(0.55, 0.5, 0.45, 0.6)))
	v.add_child(sr)
	var b := UiKit.button(Lang.t("Play") if open else Lang.t("Locked"), UiKit.RED if boss else UiKit.TEAL, 24)
	b.disabled = not open
	if open:
		b.pressed.connect(func():
			Recipes.level = i
			Fx.go("res://scenes/main.tscn"))
	v.add_child(b)
	return [pc, b]
