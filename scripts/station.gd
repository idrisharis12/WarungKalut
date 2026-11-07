class_name Station
extends Node3D

enum Kind { COUNTER, CRATE, BOARD, FRY, BOIL, MIXER, BIN, HATCH, TARIK, RETURN, WASH, PLATES }

signal dish_served(contents: Array)
signal vessel_gone(plate: bool, delay: float)
signal plate_washed
signal fire_started

const FIRE_KINDS := [Kind.FRY, Kind.BOIL]
const SPREAD_AFTER := 5.0
const PUT_OUT_TIME := 1.6

const CRATE_NAMES := {
	"chilli": "CHILLI", "shallot": "SHALLOT", "chicken": "CHICKEN", "rice": "RICE",
	"anchovy": "ANCHOVY", "cucumber": "CUCUMBER", "sambal": "SAMBAL", "batter": "BATTER",
	"glass": "GLASS",
}

@export var kind := Kind.COUNTER
@export var crate_id := "chilli"

var item: Node3D
var slot := Node3D.new()
var label := Label3D.new()
var guide := false
var _sign := Node3D.new()
var _arrow: Label3D
var _pfill := Sprite3D.new()
static var _plaque: ImageTexture
var stock := 0
var wash_seconds := 3.0
var wash_left := 3.0
var washing := false
var near := false
var hint := false
var prog := 0.0
var _stack: Array[Vessel] = []
var _badge := Sprite3D.new()
var _ring := MeshInstance3D.new()
var _ring_mat := StandardMaterial3D.new()
var _badge_key := ""
var _t := 0.0
var on_fire := false
var fire_t := 0.0
var out_left := PUT_OUT_TIME
var _fire: Node3D
var _putting_out := false

static var _white: ImageTexture


func _ready() -> void:
	slot.position = Vector3(0, 1.0, 0)
	add_child(slot)
	label.text = _title()
	_make_sign()
	_make_overlays()


static func _plaque_tex() -> ImageTexture:
	if _plaque == null:
		var w := 192
		var h := 56
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			for x in w:
				var dx := maxf(absf(x - w / 2.0 + 0.5) - (w / 2.0 - h / 2.0), 0.0)
				var dy := absf(y - h / 2.0 + 0.5)
				var d := sqrt(dx * dx + dy * dy)
				var a := clampf(h / 2.0 - d, 0.0, 1.0)
				var shade := 1.0 - 0.18 * (float(y) / h)
				img.set_pixel(x, y, Color(shade, shade, shade, a))
		_plaque = ImageTexture.create_from_image(img)
	return _plaque


func _sign_color() -> Color:
	match kind:
		Kind.CRATE:
			return Color(0.1, 0.5, 0.45)
		Kind.BOARD, Kind.MIXER, Kind.FRY, Kind.BOIL, Kind.TARIK:
			return Color(0.78, 0.22, 0.16)
		Kind.HATCH:
			return Color(0.9, 0.65, 0.12)
		Kind.WASH:
			return Color(0.2, 0.5, 0.85)
		Kind.PLATES, Kind.RETURN:
			return Color(0.55, 0.42, 0.3)
	return Color(0.35, 0.3, 0.3)


func _sign_icon() -> String:
	match kind:
		Kind.BOARD:
			return "delapouite/cleaver.png"
		Kind.MIXER:
			return "delapouite/whisk.png"
		Kind.FRY:
			return "carl-olsen/flame.png"
		Kind.BOIL:
			return "delapouite/cooking-pot.png"
		Kind.TARIK:
			return "delapouite/teapot-leaves.png"
		Kind.HATCH:
			return "lorc/ringing-bell.png"
		Kind.WASH:
			return "lorc/water-splash.png"
		Kind.BIN:
			return "delapouite/trash-can.png"
		Kind.PLATES:
			return "lorc/knife-fork.png"
		Kind.RETURN:
			return "lorc/recycle.png"
	return ""


static var _white_icons := {}


static func _white_icon(path: String) -> Texture2D:
	if not _white_icons.has(path):
		var img := (load(path) as Texture2D).get_image()
		img.convert(Image.FORMAT_RGBA8)
		for y in img.get_height():
			for x in img.get_width():
				img.set_pixel(x, y, Color(1, 1, 1, img.get_pixel(x, y).a))
		_white_icons[path] = ImageTexture.create_from_image(img)
	return _white_icons[path]


func _make_sign() -> void:
	_sign.top_level = true
	add_child(_sign)
	if _title() == "":
		return
	var tex := _plaque_tex()
	var icon_path := UiKit.ICONS + _sign_icon()
	var has_icon := _sign_icon() != "" and ResourceLoader.exists(icon_path)
	var w := 1.0 if has_icon else 0.95
	var edge := Sprite3D.new()
	edge.texture = tex
	edge.modulate = Color(0.12, 0.05, 0.04)
	var fill := Sprite3D.new()
	fill.texture = tex
	fill.modulate = _sign_color()
	for sp: Sprite3D in [edge, fill]:
		sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sp.no_depth_test = true
		sp.shaded = false
		sp.render_priority = 1
		_sign.add_child(sp)
	var px := w / tex.get_width()
	edge.pixel_size = px * 1.07
	fill.pixel_size = px
	fill.render_priority = 2
	_pfill.texture = tex
	_pfill.centered = false
	_pfill.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height() / 2.0)
	_pfill.region_enabled = true
	_pfill.region_rect = Rect2(0, 0, 0, tex.get_height())
	_pfill.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_pfill.no_depth_test = true
	_pfill.shaded = false
	_pfill.pixel_size = px
	_pfill.render_priority = 3
	_pfill.visible = false
	_sign.add_child(_pfill)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.0042
	label.font_size = 40
	label.outline_size = 8
	label.outline_modulate = Color(0.1, 0.04, 0.03)
	label.render_priority = 4
	label.position = Vector3(0.11 if has_icon else 0.0, 0.0, 0.0)
	_sign.add_child(label)
	if has_icon:
		var ic := Sprite3D.new()
		ic.texture = _white_icon(icon_path)
		ic.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		ic.no_depth_test = true
		ic.shaded = false
		ic.pixel_size = 0.3 / 512.0
		ic.modulate = Color(1, 0.95, 0.8)
		ic.position = Vector3(-0.38, 0, 0)
		ic.render_priority = 4
		_sign.add_child(ic)


func _make_overlays() -> void:
	_badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_badge.no_depth_test = true
	_badge.shaded = false
	_badge.pixel_size = 0.0034
	_badge.position = Vector3(0, 2.28, 0)
	_badge.visible = false
	add_child(_badge)
	var c := CylinderMesh.new()
	c.top_radius = 0.6
	c.bottom_radius = 0.6
	c.height = 0.02
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.albedo_color = Color(1, 0.85, 0.2, 0.0)
	c.material = _ring_mat
	_ring.mesh = c
	_ring.position.y = 0.97
	_ring.visible = false
	add_child(_ring)


func _title() -> String:
	match kind:
		Kind.CRATE:
			return CRATE_NAMES.get(crate_id, crate_id.to_upper())
		Kind.BOARD:
			return "CHOP"
		Kind.FRY:
			return "FRY"
		Kind.BOIL:
			return "BOIL"
		Kind.MIXER:
			return "MIX"
		Kind.BIN:
			return "TRASH"
		Kind.HATCH:
			return "SERVE"
		Kind.TARIK:
			return "PULL TEA"
		Kind.WASH:
			return "WASH"
		Kind.RETURN:
			return "DIRTY x%d" % stock
		Kind.PLATES:
			return "PLATES x%d" % stock
	return ""


func set_stock(n: int) -> void:
	stock = maxi(n, 0)
	label.text = _title()
	for v in _stack:
		v.queue_free()
	_stack.clear()
	for i in mini(stock, 5):
		var v := Vessel.new()
		add_child(v)
		v.position.y = 0.93 + i * 0.06
		if kind == Kind.RETURN:
			v.set_dirty(true)
		_stack.append(v)


func dispenses() -> bool:
	return kind == Kind.CRATE or ((kind == Kind.RETURN or kind == Kind.PLATES) and stock > 0)


func accepts(held: Node3D) -> bool:
	if item != null or kind == Kind.RETURN or kind == Kind.PLATES or on_fire:
		return false
	if held is Vessel:
		var v := held as Vessel
		match kind:
			Kind.COUNTER, Kind.BIN:
				return true
			Kind.HATCH:
				return not v.contents.is_empty() and not v.dirty
			Kind.TARIK:
				return v.is_glass and v.contents.is_empty()
			Kind.WASH:
				return not v.is_glass and v.dirty
		return false
	var ing := held as Ingredient
	match kind:
		Kind.COUNTER, Kind.BIN:
			return true
		Kind.BOARD:
			return ing.state == "raw" and ing.has_state("chopped")
		Kind.FRY, Kind.BOIL:
			return (ing.state == "raw" or ing.state == "chopped") and ing.has_state("cooked")
		Kind.MIXER:
			return ing.state == "raw" and ing.has_state("mixed")
	return false


func take_from_crate() -> Node3D:
	if kind == Kind.RETURN or kind == Kind.PLATES:
		var p := Vessel.new()
		if kind == Kind.RETURN:
			p.set_dirty(true)
		set_stock(stock - 1)
		return p
	if crate_id == "glass":
		var v := Vessel.new()
		v.is_glass = true
		return v
	var ing := Ingredient.new()
	ing.ingredient_id = crate_id
	return ing


func put(held: Node3D) -> void:
	if kind == Kind.BIN:
		if held is Vessel:
			vessel_gone.emit(not (held as Vessel).is_glass, 2.0)
		held.queue_free()
		return
	if kind == Kind.HATCH:
		var v := held as Vessel
		Sfx.play("serve")
		dish_served.emit(v.contents.duplicate())
		vessel_gone.emit(not v.is_glass, 6.0)
		held.queue_free()
		return
	item = held
	held.reparent(slot, false)
	held.position = Vector3.ZERO
	held.rotation = Vector3.ZERO
	if kind == Kind.WASH:
		wash_left = wash_seconds
	if held is Ingredient:
		var ing := held as Ingredient
		ing.progress_changed.connect(_on_progress)
		ing.burnt.connect(_ignite)
		if kind == Kind.FRY:
			ing.start(Ingredient.Action.FRY)
		elif kind == Kind.BOIL:
			ing.start(Ingredient.Action.BOIL)


func take() -> Node3D:
	var out := item
	if out == null or on_fire:
		return null
	if out is Ingredient:
		var ing := out as Ingredient
		ing.stop()
		ing.progress_changed.disconnect(_on_progress)
		if ing.burnt.is_connected(_ignite):
			ing.burnt.disconnect(_ignite)
	washing = false
	item = null
	label.text = _title()
	return out


func work_press() -> void:
	if item == null:
		return
	if kind == Kind.BOARD and item is Ingredient:
		(item as Ingredient).chop_hit()
		Sfx.play("chop")
	elif kind == Kind.TARIK and item is Vessel:
		Sfx.play("tarik")
		var p := (item as Vessel).pull()
		label.text = _title()


func work_hold(on: bool) -> void:
	_putting_out = on and on_fire
	if kind == Kind.WASH:
		washing = on and item is Vessel and (item as Vessel).dirty
		if not on:
			label.text = _title()
		return
	if kind != Kind.MIXER or not (item is Ingredient):
		return
	var ing := item as Ingredient
	if on:
		if ing.action != Ingredient.Action.MIX and ing.state == "raw":
			ing.start(Ingredient.Action.MIX)
	else:
		ing.stop()


func _ignite() -> void:
	if on_fire or not (kind in FIRE_KINDS):
		return
	on_fire = true
	fire_t = 0.0
	out_left = PUT_OUT_TIME
	fire_started.emit()
	Sfx.play("fire")
	_fire = Node3D.new()
	add_child(_fire)
	_fire.position.y = 1.0
	var p := CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 0.7
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.6
	p.gravity = Vector3(0, 1.0, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.3
	var q := QuadMesh.new()
	q.size = Vector2(0.32, 0.32)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = m
	p.mesh = q
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 0.9, 0.3, 0.95), Color(1, 0.4, 0.1, 0.8), Color(0.3, 0.1, 0.05, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	p.color_ramp = g
	_fire.add_child(p)
	var l := OmniLight3D.new()
	l.light_color = Color(1, 0.55, 0.2)
	l.light_energy = 2.0
	l.omni_range = 3.0
	l.position.y = 0.5
	_fire.add_child(l)


func _put_out() -> void:
	on_fire = false
	_putting_out = false
	if _fire:
		_fire.queue_free()
		_fire = null
	if item is Ingredient:
		var ing := item as Ingredient
		ing.stop()
	label.text = _title()
	Sfx.play("splash")


func _tick_fire(delta: float) -> void:
	fire_t += delta
	if _putting_out:
		out_left -= delta
		prog = 1.0 - out_left / PUT_OUT_TIME
		if out_left <= 0.0:
			_put_out()
			return
	else:
		out_left = minf(out_left + delta * 0.5, PUT_OUT_TIME)
	if fire_t >= SPREAD_AFTER:
		fire_t = 0.0
		for n in get_parent().get_children():
			var o := n as Station
			if o != null and not o.on_fire and o.kind in FIRE_KINDS and o.global_position.distance_to(global_position) < 1.2:
				o._ignite()
				break


func _process(delta: float) -> void:
	_t += delta
	if on_fire:
		_tick_fire(delta)
	_update_overlays()
	if not washing:
		return
	var v := item as Vessel
	if v == null or not v.dirty:
		washing = false
		return
	wash_left -= delta
	if wash_left <= 0.0:
		washing = false
		item = null
		v.queue_free()
		label.text = _title()
		Sfx.play("clean")
		plate_washed.emit()
	else:
		prog = 1.0 - wash_left / wash_seconds


func _update_overlays() -> void:
	var shown := item != null and kind != Kind.BIN and not on_fire
	var key := Thumbs.key_for(item) if shown else ""
	if key != _badge_key:
		_badge_key = key
		_badge.visible = key != ""
		if key != "":
			_badge.texture = Thumbs.tex(key)
	if kind == Kind.TARIK and item is Vessel:
		prog = float((item as Vessel).pulls) / Vessel.PULLS if not (item as Vessel).contents.size() > 0 else 1.0
	elif item == null:
		prog = 0.0
	var burning := prog > 1.0
	var frac := clampf(prog, 0.0, 1.0)
	var bar_on := (on_fire and prog > 0.0) or (item != null and prog > 0.0 and (frac < 1.0 or burning))
	if _pfill.texture:
		_pfill.visible = bar_on
		if bar_on:
			var fr := 1.0 if burning else frac
			_pfill.region_rect = Rect2(0, 0, _pfill.texture.get_width() * fr, _pfill.texture.get_height())
			var c := Color(0.95, 0.25, 0.2) if burning else Color(0.35, 0.8, 0.3)
			if on_fire:
				c = Color(0.3, 0.65, 1.0)
			_pfill.modulate = c
			if burning:
				_pfill.modulate.a = 0.6 + 0.4 * sin(_t * 14.0)
	var a := 0.0
	if hint:
		a = 0.35 + 0.25 * sin(_t * 5.0)
	if near:
		a = maxf(a, 0.55)
	if guide:
		a = maxf(a, 0.5 + 0.3 * sin(_t * 6.0))
	_ring.visible = a > 0.0
	_ring_mat.albedo_color = Color(1, 0.85, 0.2, a) if not near else Color(1, 1, 1, a * 0.5)
	if guide:
		_ring_mat.albedo_color = Color(0.4, 1.0, 0.45, a)
	var target := 1.15 if near else 1.0
	_sign.scale = _sign.scale.lerp(Vector3.ONE * target, 0.2)
	_sign.global_position = global_position + Vector3(0, 0.2 + (0.05 * sin(_t * 6.0) if guide else 0.0), 0.66)
	label.modulate = Color(1, 1, 0.75) if near else Color.WHITE
	if guide and _arrow == null:
		_arrow = Label3D.new()
		_arrow.text = "▼"
		_arrow.font_size = 90
		_arrow.pixel_size = 0.006
		_arrow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_arrow.no_depth_test = true
		_arrow.modulate = Color(0.4, 1.0, 0.45)
		_arrow.outline_size = 14
		_arrow.outline_modulate = Color(0.1, 0.04, 0.03)
		_arrow.render_priority = 6
		add_child(_arrow)
	if _arrow:
		_arrow.visible = guide
		_arrow.position = Vector3(0, 2.55 + 0.18 * absf(sin(_t * 4.0)), 0)


func _on_progress(v: float) -> void:
	prog = v
	label.text = _title()
