class_name RecipeView
extends RefCounted


static func _arrow() -> Control:
	var a := UiKit.lbl("▶", 34, UiKit.RED)
	a.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return a


static func _tile(key: String, px: int, caption := "") -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiKit.box(Color(0.9, 0.78, 0.56, 0.9), Color(0.7, 0.5, 0.25), 2, 12, 2, false))
	if key == "kit:serving-hatch" or key.begins_with("icon:"):
		var ok := key.begins_with("icon:")
		var big := UiKit.lbl("OK!" if ok else "SERVE", int(px * (0.4 if ok else 0.28)), UiKit.LEAF if ok else UiKit.RED)
		big.custom_minimum_size = Vector2(px, px)
		big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pc.add_child(big)
	else:
		pc.add_child(UiKit.thumb(key, px))
	v.add_child(pc)
	if caption != "" and key != "kit:serving-hatch":
		var l := UiKit.lbl(caption, 13, UiKit.INK)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	return v


static func _plus() -> Control:
	var l := UiKit.lbl("+", 26, UiKit.RED)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


# One picture step: [inputs] -> [station] -> [result], with the step number and a caption.
static func step(i: int, s: Dictionary, px := 96) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.box(UiKit.CREAM, Color(0.8, 0.62, 0.3), 3, 14, 8, false))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	card.add_child(hb)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UiKit.box(UiKit.RED, UiKit.GOLD, 2, 20, 4, false))
	var n := UiKit.lbl(str(i), 22, UiKit.CREAM)
	n.custom_minimum_size = Vector2(26, 0)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(n)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(badge)
	var ins: Array = s["in"]
	for j in ins.size():
		if j > 0:
			hb.add_child(_plus())
		hb.add_child(_tile(String(ins[j]), px))
	if String(s["at"]) != "":
		hb.add_child(_arrow())
		hb.add_child(_tile(String(s["at"]), px, String(s["at_name"])))
	hb.add_child(_arrow())
	hb.add_child(_tile(String(s["out"]), px))
	var t := UiKit.lbl(String(s["text"]), 17, UiKit.INK)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(190, 0)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(t)
	return card


static func page(id: String, px := 96) -> Control:
	var info: Dictionary = Recipes.DISHES[id]
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	head.add_child(UiKit.thumb("dish:" + id, 110))
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(UiKit.lbl(String(info["name"]), 38, UiKit.GOLD, 8))
	tv.add_child(UiKit.lbl(String(info["sub"]), 20, UiKit.CREAM))
	var teach := UiKit.lbl(String(info["teach"]), 15, Color(0.95, 0.88, 0.75))
	teach.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	teach.custom_minimum_size = Vector2(300, 0)
	tv.add_child(teach)
	head.add_child(tv)
	root.add_child(head)
	var steps: Array = info["visual"]
	for i in steps.size():
		root.add_child(step(i + 1, steps[i], px))
	return root
