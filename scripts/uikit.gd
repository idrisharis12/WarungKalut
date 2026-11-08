class_name UiKit
extends RefCounted

const ICONS := "res://Assets/game-icons.net.png/icons/000000/transparent/1x1/"
const KEYS := "res://Assets/kenney_input-prompts_1.5/Keyboard & Mouse/Default/keyboard_%s.png"
const INK := Color(0.17, 0.09, 0.07)
const CREAM := Color(0.99, 0.94, 0.82)
const GOLD := Color(0.98, 0.77, 0.25)
const RED := Color(0.66, 0.16, 0.13)
const TEAL := Color(0.09, 0.45, 0.42)
const LEAF := Color(0.36, 0.7, 0.3)
const DARK := Color(0.17, 0.07, 0.06, 0.92)

static var _mats := {}
const FONT_PATH := "res://Assets/fonts/NotoSans-Bold.ttf"
static var _font: Font


static func font() -> Font:
	if _font == null:
		var sys := SystemFont.new()
		sys.font_names = PackedStringArray(["DejaVu Sans"])
		sys.font_weight = 700
		if ResourceLoader.exists(FONT_PATH):
			var ff := load(FONT_PATH) as FontFile
			ff.fallbacks = [sys]
			_font = ff
		else:
			_font = sys
	return _font


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 18
	return t


static func box(bg: Color, border := Color(0, 0, 0, 0), bw := 0, radius := 14, margin := 10, shadow := true) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	if shadow:
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 6
		sb.shadow_offset = Vector2(0, 3)
	return sb


static func lbl(text: String, size := 18, col := CREAM, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", int(round(size * Prefs.text_scale)))
	l.add_theme_color_override("font_color", col)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", INK)
		l.add_theme_constant_override("outline_size", outline)
	return l


static func _icon_mat(tint: Color) -> ShaderMaterial:
	var key := tint.to_html()
	if not _mats.has(key):
		var sh := Shader.new()
		sh.code = "shader_type canvas_item; uniform vec4 tint; void fragment() { COLOR = vec4(tint.rgb, texture(TEXTURE, UV).a * tint.a); }"
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("tint", tint)
		_mats[key] = m
	return _mats[key]


static func _tex_rect(px: int) -> TextureRect:
	var tr := TextureRect.new()
	tr.custom_minimum_size = Vector2(px, px)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


static func icon(rel: String, px: int, tint := Color.WHITE) -> TextureRect:
	var tr := _tex_rect(px)
	var p := ICONS + rel
	if ResourceLoader.exists(p):
		tr.texture = load(p)
	tr.material = _icon_mat(tint)
	return tr


static func key_icon(k: String, px: int) -> TextureRect:
	var tr := _tex_rect(px)
	var p: String = KEYS % k
	if ResourceLoader.exists(p):
		tr.texture = load(p)
	return tr


# "icon:<author/name.png>" is a flat icon, anything else a 3D thumbnail (see Thumbs).
static func thumb(key: String, px: int) -> Control:
	if key.begins_with("icon:"):
		return icon(key.substr(5), px, INK)
	var tr := _tex_rect(px)
	tr.texture = Thumbs.tex(key)
	return tr


static func button(text: String, col: Color, size := 26) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", INK)
	b.add_theme_constant_override("outline_size", 6)
	b.add_theme_stylebox_override("normal", box(col, GOLD, 3, 16, 14))
	b.add_theme_stylebox_override("hover", box(col.lightened(0.18), Color.WHITE, 3, 16, 14))
	b.add_theme_stylebox_override("pressed", box(col.darkened(0.2), GOLD, 3, 16, 14))
	b.add_theme_stylebox_override("focus", box(col.lightened(0.1), Color.WHITE, 4, 16, 14))
	b.add_theme_stylebox_override("disabled", box(Color(0.3, 0.3, 0.3), Color(0.5, 0.5, 0.5), 3, 16, 14))
	b.focus_mode = Control.FOCUS_ALL
	b.resized.connect(func(): b.pivot_offset = b.size / 2.0)
	var pop := func(to: float, snd: bool):
		if snd and not b.disabled:
			Sfx.play("click")
		var tw := b.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "scale", Vector2.ONE * to, 0.14)
	b.mouse_entered.connect(pop.bind(1.06, true))
	b.mouse_exited.connect(pop.bind(1.0, false))
	b.focus_entered.connect(pop.bind(1.06, true))
	b.focus_exited.connect(pop.bind(1.0, false))
	return b


# A keyboard key drawn as a chunky cap. Shows whatever key an action is bound to.
static func keycap(text: String, px := 30, dark := false) -> PanelContainer:
	var pc := PanelContainer.new()
	var bg := Color(0.22, 0.12, 0.1) if dark else CREAM
	var fg := CREAM if dark else INK
	var sb := box(bg, GOLD if dark else Color(0.75, 0.6, 0.35), 2, maxi(px / 4, 5), 0, false)
	sb.border_width_bottom = 5
	sb.content_margin_left = px * 0.28
	sb.content_margin_right = px * 0.28
	sb.content_margin_top = px * 0.04
	sb.content_margin_bottom = px * 0.0
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(px, px)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := lbl(text, int(px * (0.5 if text.length() < 4 else 0.38)), fg)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pc.add_child(l)
	return pc


static func action_key(action: String, px := 30, dark := false) -> PanelContainer:
	return keycap(Controls.key_name(action), px, dark)
