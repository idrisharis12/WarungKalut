class_name Game
extends CanvasLayer

signal stage_changed(index: int)
signal served_ok
signal police_called
signal police_left

const ITEM_THUMB := {
	"batter:mixed": "batter:mixed", "chicken:cooked": "chicken:cooked", "shallot:chopped": "shallot:chopped",
	"rice:cooked": "rice:cooked", "anchovy:cooked": "anchovy:cooked", "cucumber:chopped": "cucumber:chopped",
	"sambal:mixed": "sambal:mixed", "teh:tarik": "teh:tarik",
}

const TOP := 124.0
const BOT := 50.0

var point := 20.0
var combo := 0
var score := 0
var police_armed := false
var police_active := false
var over := false
var elapsed := 0.0
var hold_100 := 0.0
var stage := 0
var level: Dictionary
var orders: Array[Dictionary] = []
var _spawn_t := 3.0
var _next_id := 1
var _tip_t := 0.0
var _card_open := false
var _queue: Array[String] = []

var ui := Control.new()
var bar := ProgressBar.new()
var bar_label: Label
var combo_label: Label
var status_label: Label
var level_label: Label
var order_box := HBoxContainer.new()
var banner := Label.new()
var tip := Label.new()
var card := PanelContainer.new()
var card_body := VBoxContainer.new()
var book := PanelContainer.new()
var book_body := VBoxContainer.new()
var pause_panel := PanelContainer.new()
var pause_body := VBoxContainer.new()
var end_panel := PanelContainer.new()
var end_body := VBoxContainer.new()
var _sfx: Dictionary = {}
var _player := AudioStreamPlayer.new()
var _fill := StyleBoxFlat.new()
var help_row := HBoxContainer.new()
var settings_open := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	stage = Recipes.level
	level = Recipes.TUTORIAL if Recipes.tutorial else Recipes.LEVELS[stage]
	_build_ui()
	_make_sfx()
	add_child(_player)
	for d in level["dishes"]:
		if not Recipes.seen.has(d) and not Recipes.tutorial:
			Recipes.seen[d] = true
			_queue.append(d)
	_show_next_card()
	_refresh()


func _pill(bg := Color(0.14, 0.06, 0.05, 0.82)) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.box(bg, UiKit.GOLD, 2, 18, 10))
	return p


func _build_ui() -> void:
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = UiKit.theme()
	add_child(ui)

	for band in [[Control.PRESET_TOP_WIDE, TOP, true], [Control.PRESET_BOTTOM_WIDE, BOT, false]]:
		var r := ColorRect.new()
		r.color = Color(0.13, 0.06, 0.05)
		r.set_anchors_preset(band[0])
		if band[2]:
			r.offset_bottom = band[1]
		else:
			r.offset_top = -band[1]
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(r)
		var edge := ColorRect.new()
		edge.color = UiKit.GOLD
		edge.set_anchors_preset(band[0])
		if band[2]:
			edge.offset_top = band[1] - 3
			edge.offset_bottom = band[1]
		else:
			edge.offset_top = -band[1]
			edge.offset_bottom = -band[1] + 3
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.add_child(edge)

	order_box.position = Vector2(10, 6)
	order_box.add_theme_constant_override("separation", 6)
	order_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(order_box)

	var meter := _pill()
	meter.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	meter.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	meter.offset_left = -310
	meter.offset_right = -10
	meter.offset_top = 4
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 2)
	meter.add_child(mv)
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 8)
	title.add_child(UiKit.icon("andymeneely/police-badge.png", 28, UiKit.GOLD))
	bar_label = UiKit.lbl("", 18, UiKit.CREAM)
	bar_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(bar_label)
	combo_label = UiKit.lbl("", 22, UiKit.GOLD, 6)
	title.add_child(combo_label)
	mv.add_child(title)
	bar.custom_minimum_size = Vector2(0, 18)
	bar.max_value = 100
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", UiKit.box(Color(0.3, 0.12, 0.1), UiKit.INK, 2, 11, 0, false))
	_fill.set_corner_radius_all(11)
	bar.add_theme_stylebox_override("fill", _fill)
	var line := ColorRect.new()
	line.color = Color(0.35, 0.6, 1.0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.anchor_left = 0.5
	line.anchor_right = 0.5
	line.anchor_bottom = 1.0
	line.offset_left = -2
	line.offset_right = 2
	bar.add_child(line)
	mv.add_child(bar)
	status_label = UiKit.lbl("", 13, Color(0.95, 0.88, 0.75))
	mv.add_child(status_label)
	level_label = UiKit.lbl("", 16, UiKit.GOLD, 4)
	level_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	level_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	level_label.offset_left = -200
	level_label.offset_right = 200
	level_label.offset_top = 10
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 20)
	ui.add_child(level_label)
	ui.add_child(meter)

	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.offset_left = -400
	banner.offset_right = 400
	banner.offset_top = 150
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 38)
	banner.add_theme_color_override("font_outline_color", UiKit.INK)
	banner.add_theme_constant_override("outline_size", 12)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(banner)

	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -BOT
	bottom.offset_bottom = -6
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation", 6)
	var tp := _pill(Color(0.09, 0.3, 0.28, 0.88))
	tp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tip.add_theme_font_size_override("font_size", 14)
	tip.add_theme_color_override("font_color", UiKit.CREAM)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(620, 0)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tp.add_child(tip)
	bottom.add_child(tp)
	tp.hide()
	var kp := _pill()
	kp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	help_row.add_theme_constant_override("separation", 6)
	kp.add_child(help_row)
	_fill_help()
	bottom.add_child(kp)
	ui.add_child(bottom)

	if Recipes.tutorial:
		meter.hide()
		level_label.hide()
		order_box.position = Vector2(730, 8)
	_overlay(card, card_body, Vector2(820, 560))
	_overlay(book, book_body, Vector2(860, 590))
	_overlay(end_panel, end_body, Vector2(580, 470))
	_overlay(pause_panel, pause_body, Vector2(500, 520))


func _overlay(p: PanelContainer, body: VBoxContainer, size: Vector2) -> void:
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.offset_left = -size.x / 2.0
	p.offset_right = size.x / 2.0
	p.offset_top = -size.y / 2.0
	p.offset_bottom = size.y / 2.0
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	var solid := UiKit.DARK
	solid.a = 1.0
	p.add_theme_stylebox_override("panel", UiKit.box(solid, UiKit.GOLD, 5, 22, 18))
	body.add_theme_constant_override("separation", 10)
	p.add_child(body)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	p.hide()
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.02, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.hide()
	ui.add_child(dim)
	p.visibility_changed.connect(func():
		dim.visible = p.visible
		if p.visible:
			banner.text = "")
	ui.add_child(p)


func _process(delta: float) -> void:
	if over or get_tree().paused:
		return
	if Recipes.tutorial:
		_refresh()
		return
	elapsed += delta
	_spawn_t -= delta
	if _spawn_t <= 0.0 and orders.size() < int(level["max"]):
		_new_order(level["dishes"])
		_spawn_t = float(level["spawn"]) * lerpf(1.0, 0.7, clampf(elapsed / 240.0, 0.0, 1.0))
	for o in orders.duplicate():
		o["left"] = float(o["left"]) - delta
		if float(o["left"]) <= 0.0:
			orders.erase(o)
			_change(-6.0)
			combo = 0
			_beep("bad")
			_say("Too slow! Order expired  -6", Color(1, 0.45, 0.35))
	_tip_t -= delta
	if _tip_t <= 0.0:
		tip.text = "Did you know?  " + String(Recipes.TIPS.pick_random())
		_tip_t = 22.0
	tip.get_parent().visible = false
	if point >= 100.0:
		hold_100 += delta
		if hold_100 >= float(level["hold"]):
			_end(true)
	else:
		hold_100 = 0.0
	_refresh()


func add_order(d: String) -> void:
	_new_order([d])


func _new_order(dishes: Array) -> void:
	var d: String = dishes.pick_random()
	var info: Dictionary = Recipes.DISHES[d]
	orders.append({"dish": d, "left": float(info["time"]), "total": float(info["time"])})
	_beep("bell")


func fire_started() -> void:
	_change(-4.0)
	banner.text = "FIRE! Hold Q to put it out"
	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_callback(func(): if not over and banner.text.begins_with("FIRE"): banner.text = "")


func serve(contents: Array) -> void:
	if over:
		return
	var key := Recipes.key_of(contents)
	for o in orders:
		var info: Dictionary = Recipes.DISHES[o["dish"]]
		if Recipes.key_of(info["items"]) == key:
			var frac := float(o["left"]) / float(o["total"])
			combo += 1
			var gain := float(info["points"]) * (1.0 + 0.25 * mini(combo - 1, 4)) + 3.0 * frac
			orders.erase(o)
			score += int(gain) * 10
			_change(gain)
			_beep("ok")
			served_ok.emit()
			_say("%s!  +%d  Combo x%d" % [info["name"], int(gain), combo], Color(0.55, 1, 0.5))
			return
	combo = 0
	_change(-4.0)
	_beep("bad")
	_say("Wrong dish  -4", Color(1, 0.45, 0.35))


func _change(d: float) -> void:
	point = clampf(point + d, 0.0, 100.0)
	if Recipes.tutorial:
		return
	if point >= Recipes.POLICE_LINE:
		police_armed = true
		if police_active:
			police_active = false
			police_left.emit()
			_say("Police backed off. Stay above 50%!", Color(0.55, 1, 0.5))
	elif police_armed and not police_active and not over:
		police_active = true
		police_called.emit()
		_beep("bad")
		_say("Police are coming! Get above 50%!", Color(0.45, 0.65, 1.0))


func busted() -> void:
	if not over:
		_end(false)


func _end(won: bool) -> void:
	over = true
	banner.text = ""
	if won:
		Recipes.unlock(stage + 2)
		_beep("ok")
	else:
		_beep("bad")
	for c in end_body.get_children():
		c.queue_free()
	end_body.add_child(UiKit.icon("lorc/trophy.png" if won else "lorc/handcuffs.png", 90, UiKit.GOLD if won else Color(0.95, 0.35, 0.3)))
	var t := UiKit.lbl("YOU WIN!" if won else "BUSTED!", 44, UiKit.GOLD if won else Color(1.0, 0.45, 0.4), 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_body.add_child(t)
	if won:
		var stars := 1 + int(score >= 600 + 300 * stage) + int(score >= 1200 + 600 * stage)
		var sr := HBoxContainer.new()
		sr.alignment = BoxContainer.ALIGNMENT_CENTER
		for i in 3:
			sr.add_child(UiKit.icon("lorc/trophy.png", 44, UiKit.GOLD if i < stars else Color(0.3, 0.27, 0.25)))
		end_body.add_child(sr)
	var sl := UiKit.lbl("Score %d    Time %d:%02d" % [score, int(elapsed) / 60, int(elapsed) % 60], 24, UiKit.CREAM)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_body.add_child(sl)
	var sub := UiKit.lbl(("%s is famous!" % level["name"]) if won else "The police caught the chef", 20, UiKit.CREAM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_body.add_child(sub)
	var learn_id: String = (level["dishes"] as Array).pick_random()
	var lp := PanelContainer.new()
	lp.add_theme_stylebox_override("panel", UiKit.box(Color(0.09, 0.3, 0.28, 0.9), UiKit.GOLD, 2, 12, 8))
	var lh := HBoxContainer.new()
	lh.add_theme_constant_override("separation", 10)
	lh.add_child(UiKit.thumb("dish:" + learn_id, 64))
	var lt := UiKit.lbl("%s: %s" % [Recipes.DISHES[learn_id]["name"], Recipes.DISHES[learn_id]["teach"]], 14, UiKit.CREAM)
	lt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lt.custom_minimum_size = Vector2(380, 0)
	lt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lh.add_child(lt)
	lp.add_child(lh)
	end_body.add_child(lp)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var first: Button
	if won and stage + 1 < Recipes.LEVELS.size():
		var nb := UiKit.button("Next level", UiKit.TEAL, 24)
		nb.pressed.connect(func(): _go_level(stage + 1))
		row.add_child(nb)
		first = nb
	var rb := UiKit.button("Retry", UiKit.RED, 24)
	rb.pressed.connect(func(): _go_level(stage))
	row.add_child(rb)
	var mb := UiKit.button("Menu", Color(0.35, 0.25, 0.2), 24)
	mb.pressed.connect(_go_menu)
	row.add_child(mb)
	end_body.add_child(row)
	end_panel.show()
	(first if first else rb).grab_focus()


func _go_level(i: int) -> void:
	Recipes.level = i
	get_tree().paused = false
	get_tree().reload_current_scene()


func _go_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


func _say(t: String, c: Color) -> void:
	banner.text = t
	banner.add_theme_color_override("font_color", c)
	if not over:
		var tw := create_tween()
		tw.tween_interval(3.0)
		tw.tween_callback(func(): if not over: banner.text = "")


func _refresh() -> void:
	bar.value = point
	_fill.bg_color = Color(0.9, 0.25, 0.2) if point < Recipes.POLICE_LINE else UiKit.GOLD
	bar_label.text = "Malaysia Meter %d%%" % int(point)
	combo_label.text = ("x%d" % combo) if combo > 0 else ""
	level_label.text = "Training" if Recipes.tutorial else "%d. %s    Score %d    %d:%02d" % [stage + 1, level["name"], score, int(elapsed) / 60, int(elapsed) % 60]
	if point >= 100.0:
		status_label.text = "Hold 100%%: %d / %d s" % [int(hold_100), int(level["hold"])]
	elif police_active:
		status_label.text = "Police are coming! Get above 50%!"
	elif police_armed:
		status_label.text = "Police watching: stay above 50%!"
	else:
		status_label.text = "Reach 50%%, then 100%% for %d s" % int(level["hold"])
	var live := {}
	for o in orders:
		if not o.has("id"):
			o["id"] = _next_id
			_next_id += 1
		live[o["id"]] = true
		if not o.has("ui"):
			o["ui"] = _make_ticket(o)
		var u: Dictionary = o["ui"]
		var frac := float(o["left"]) / float(o["total"])
		(u["bar"] as ProgressBar).value = frac
		var col := Color(0.35, 0.75, 0.3) if frac > 0.5 else (Color(0.95, 0.75, 0.2) if frac > 0.25 else Color(0.9, 0.25, 0.2))
		(u["fill"] as StyleBoxFlat).bg_color = col
		(u["sb"] as StyleBoxFlat).border_color = col
	for c in order_box.get_children():
		if not live.has(c.get_meta("order_id")):
			c.queue_free()


func _make_ticket(o: Dictionary) -> Dictionary:
	var info: Dictionary = Recipes.DISHES[o["dish"]]
	var pc := PanelContainer.new()
	var sb := UiKit.box(UiKit.CREAM, Color(0.35, 0.75, 0.3), 3, 10, 4)
	pc.add_theme_stylebox_override("panel", sb)
	pc.set_meta("order_id", o["id"])
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	head.add_child(UiKit.thumb("dish:" + String(o["dish"]), 40))
	var nm := UiKit.lbl(String(info["name"]), 19, UiKit.RED)
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(nm)
	col.add_child(head)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	for k in info["items"]:
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", UiKit.box(Color(0.9, 0.78, 0.56), Color(0.7, 0.5, 0.25), 2, 8, 1, false))
		chip.add_child(UiKit.thumb(String(ITEM_THUMB.get(k, k)), 38))
		row.add_child(chip)
	col.add_child(row)
	var tb := ProgressBar.new()
	tb.max_value = 1.0
	tb.show_percentage = false
	tb.custom_minimum_size = Vector2(0, 7)
	tb.add_theme_stylebox_override("background", UiKit.box(Color(0.8, 0.72, 0.6), Color(0, 0, 0, 0), 0, 4, 0, false))
	var fill := StyleBoxFlat.new()
	fill.set_corner_radius_all(4)
	tb.add_theme_stylebox_override("fill", fill)
	col.add_child(tb)
	pc.add_child(col)
	order_box.add_child(pc)
	return {"bar": tb, "fill": fill, "sb": sb}


func _show_next_card() -> void:
	if _card_open or _queue.is_empty():
		return
	var d: String = _queue.pop_front()
	for c in card_body.get_children():
		c.queue_free()
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var pg := RecipeView.page(d, 68)
	pg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(pg)
	card_body.add_child(UiKit.lbl("New dish!", 22, UiKit.GOLD, 6))
	card_body.add_child(sc)
	var go := UiKit.button("Start  (E)", UiKit.TEAL, 22)
	go.pressed.connect(_close_card)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card_body.add_child(go)
	card.show()
	_card_open = true
	get_tree().paused = true
	go.grab_focus()


func _close_card() -> void:
	card.hide()
	_card_open = false
	get_tree().paused = false
	_show_next_card()


func _book(open_id := "") -> void:
	if book.visible:
		book.hide()
		get_tree().paused = _card_open
		return
	for c in book_body.get_children():
		c.queue_free()
	var title := UiKit.lbl("Recipe Book", 34, UiKit.GOLD, 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	book_body.add_child(title)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 8)
	var holder := ScrollContainer.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var show := func(id: String):
		for c in holder.get_children():
			c.queue_free()
		var pg := RecipeView.page(id, 72)
		pg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		holder.add_child(pg)
	var first := ""
	for id in Recipes.DISHES:
		if first == "":
			first = id
		var b := UiKit.button(String(Recipes.DISHES[id]["name"]), UiKit.RED, 18)
		b.pressed.connect(show.bind(id))
		tabs.add_child(b)
	book_body.add_child(tabs)
	book_body.add_child(holder)
	var hint := UiKit.lbl("Press B to close", 15, UiKit.CREAM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	book_body.add_child(hint)
	show.call(open_id if open_id != "" else first)
	book.show()
	get_tree().paused = true


func _fill_help() -> void:
	for c in help_row.get_children():
		c.queue_free()
	var hl := [[["move_up", "move_left", "move_down", "move_right"], "Move"], [["interact"], "Pick / put"], [["work"], "Chop / mix / wash"], [["dash"], "Hold run / Tap dash"], [["recipe_book"], "Recipes"]]
	for e in hl:
		for a in e[0]:
			help_row.add_child(UiKit.action_key(String(a), 26, true))
		var hl_l := UiKit.lbl(String(e[1]) + "   ", 15, UiKit.CREAM)
		hl_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		help_row.add_child(hl_l)
	help_row.add_child(UiKit.keycap("Esc", 26, true))
	help_row.add_child(UiKit.lbl("Pause", 15, UiKit.CREAM))
	if Recipes.coop:
		help_row.add_child(UiKit.lbl("   P2: " + " ".join([Controls.key_name("p2_move_up"), Controls.key_name("p2_move_left"), Controls.key_name("p2_move_down"), Controls.key_name("p2_move_right")]) + " | " + Controls.key_name("p2_interact") + " pick | " + Controls.key_name("p2_work") + " work", 15, Color(0.5, 0.85, 1.0)))


func _settings() -> void:
	settings_open = true
	pause_panel.hide()
	var sv := SettingsView.new()
	var holder := PanelContainer.new()
	holder.process_mode = Node.PROCESS_MODE_ALWAYS
	holder.theme = UiKit.theme()
	holder.set_anchors_preset(Control.PRESET_CENTER)
	holder.grow_horizontal = Control.GROW_DIRECTION_BOTH
	holder.grow_vertical = Control.GROW_DIRECTION_BOTH
	var solid := UiKit.DARK
	solid.a = 1.0
	holder.add_theme_stylebox_override("panel", UiKit.box(solid, UiKit.GOLD, 5, 22, 20))
	holder.add_child(sv)
	sv.closed.connect(func():
		holder.queue_free()
		settings_open = false
		get_tree().paused = false
		_fill_help()
		_pause())
	ui.add_child(holder)


func _pause() -> void:
	if pause_panel.visible:
		pause_panel.hide()
		get_tree().paused = _card_open
		return
	if _card_open or book.visible:
		return
	for c in pause_body.get_children():
		c.queue_free()
	var t := UiKit.lbl("Paused", 44, UiKit.GOLD, 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_body.add_child(t)
	var tp := UiKit.lbl("Did you know?  " + String(Recipes.TIPS.pick_random()), 16, UiKit.CREAM)
	tp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tp.custom_minimum_size = Vector2(440, 0)
	pause_body.add_child(tp)
	var first: Button
	for d in [["Resume", UiKit.TEAL, _pause], ["Recipe Book", UiKit.RED, func(): pause_panel.hide(); _book()], ["Settings", UiKit.RED, _settings], ["Restart", UiKit.RED, func(): _go_level(stage)], ["Quit to Menu", Color(0.35, 0.25, 0.2), _go_menu]]:
		var b := UiKit.button(d[0], d[1], 24)
		b.pressed.connect(d[2])
		pause_body.add_child(b)
		if first == null:
			first = b
	pause_panel.show()
	get_tree().paused = true
	first.grab_focus()


func _unhandled_input(e: InputEvent) -> void:
	if end_panel.visible or settings_open:
		return
	if pause_panel.visible and not e.is_action_pressed("menu"):
		return
	if e.is_action_pressed("recipe_book") and not _card_open:
		_book()
	elif e.is_action_pressed("interact") and _card_open:
		_close_card()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("restart"):
		_go_level(stage)
	elif e.is_action_pressed("menu"):
		_pause()


func _make_sfx() -> void:
	var defs := {"ok": [660.0, 990.0, 0.18], "bad": [220.0, 140.0, 0.3], "bell": [880.0, 880.0, 0.12]}
	for k in defs:
		var d: Array = defs[k]
		_sfx[k] = _tone(float(d[0]), float(d[1]), float(d[2]))


func _tone(f0: float, f1: float, dur: float) -> AudioStreamWAV:
	var n := int(22050 * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, t)
		var s := sin(TAU * f * float(i) / 22050.0) * (1.0 - t) * 0.4
		data.encode_s16(i * 2, int(s * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = 22050
	w.data = data
	return w


func _beep(k: String) -> void:
	if _sfx.has(k):
		_player.stream = _sfx[k]
		_player.play()
