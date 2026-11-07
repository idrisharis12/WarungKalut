class_name Chef
extends CharacterBody3D

@export var speed := 4.5
@export var reach := 1.3
@export var model_path := "res://Assets/kenney_mini-shop_2.1/Models/GLB format/character-employee.glb"

const RUN_MULT := 1.6
const DASH_SPEED := 13.0
const HOP := 0.55
const DASH_TIME := 0.18
const DASH_COOLDOWN := 0.8

var player := 0
var held: Node3D
var stations: Array[Station] = []
var hand := Node3D.new()
var kitchen: Kitchen
var _model: Node3D
var _anim: AnimationPlayer
var _dash := 0.0
var _cd := 0.0
var _face := Vector3(0, 0, 1)
var _carry := Sprite3D.new()
var _carry_key := ""
var _last: Station
var _prompt_layer := CanvasLayer.new()
var _prompt := PanelContainer.new()
var _prompt_row := HBoxContainer.new()
var _prompt_sig := ""
var tutorial_lock := false
var _hat: Node3D
var _model_scale := Vector3.ONE
var _t := 0.0
var _shadow := Sprite3D.new()


func _a(n: String) -> String:
	return n if player == 0 else "p2_" + n


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.0
	shape.shape = cap
	shape.position.y = 0.5
	add_child(shape)
	hand.position = Vector3(0, 0.75, 0.45)
	add_child(hand)
	_carry.top_level = true
	_carry.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_carry.no_depth_test = true
	_carry.shaded = false
	_carry.pixel_size = 0.0055
	_carry.visible = false
	add_child(_carry)
	_build_prompt()
	if Recipes.coop:
		var tag := Label3D.new()
		tag.text = "P%d" % (player + 1)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		tag.pixel_size = 0.006
		tag.font_size = 48
		tag.outline_size = 14
		tag.modulate = Color(1, 0.85, 0.25) if player == 0 else Color(0.4, 0.85, 1.0)
		tag.position = Vector3(0, 1.55, 0)
		add_child(tag)
	Prefs.load_prefs()
	model_path = Prefs.OUTFITS[Prefs.outfit if player == 0 else Prefs.outfit2]
	_shadow.texture = _blob()
	_shadow.rotation_degrees.x = -90
	_shadow.pixel_size = 0.0125
	_shadow.position.y = 0.03
	_shadow.shaded = false
	_shadow.modulate = Color(0, 0, 0, 0.5)
	add_child(_shadow)
	if ResourceLoader.exists(model_path):
		_model = (load(model_path) as PackedScene).instantiate()
		add_child(_model)
		Kitchen.fit_height(_model, 1.25)
		_model_scale = _model.scale
		Toon.apply(_model, 0.012)
		_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		_make_hat(Prefs.hat if player == 0 else Prefs.hat2)


static var _blob_tex: ImageTexture


func _blob() -> ImageTexture:
	if _blob_tex == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				var d := Vector2(x - 31.5, y - 31.5).length() / 31.5
				img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) * 1.2))
		_blob_tex = ImageTexture.create_from_image(img)
	return _blob_tex


func _make_hat(kind: int) -> void:
	if kind == 0:
		return
	_hat = Node3D.new()
	_hat.position.y = 1.2
	var mi := MeshInstance3D.new()
	var m := StandardMaterial3D.new()
	match kind:
		1:
			var c := CylinderMesh.new()
			c.top_radius = 0.17
			c.bottom_radius = 0.13
			c.height = 0.3
			mi.mesh = c
			mi.position.y = 0.16
			m.albedo_color = Color(0.98, 0.97, 0.92)
		2:
			var c := CylinderMesh.new()
			c.top_radius = 0.15
			c.bottom_radius = 0.16
			c.height = 0.17
			mi.mesh = c
			mi.position.y = 0.08
			m.albedo_color = Color(0.08, 0.08, 0.1)
		3:
			var c := SphereMesh.new()
			c.radius = 0.17
			c.height = 0.2
			mi.mesh = c
			mi.position.y = 0.06
			m.albedo_color = Color(0.15, 0.4, 0.75)
			var brim := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.22, 0.02, 0.16)
			brim.mesh = bm
			brim.position = Vector3(0, 0.0, 0.2)
			brim.material_override = m
			_hat.add_child(brim)
	mi.material_override = m
	_hat.add_child(mi)
	add_child(_hat)


func _build_prompt() -> void:
	_prompt_layer.layer = 0
	add_child(_prompt_layer)
	_prompt.theme = UiKit.theme()
	_prompt.add_theme_stylebox_override("panel", UiKit.box(Color(0.13, 0.06, 0.05, 0.95), UiKit.GOLD if player == 0 else Color(0.5, 0.85, 1.0), 3, 16, 6))
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_row.add_theme_constant_override("separation", 6)
	_prompt.add_child(_prompt_row)
	_prompt.pivot_offset = Vector2(0, 0)
	_prompt.hide()
	_prompt_layer.add_child(_prompt)


func _actions(s: Station) -> Array:
	var out := []
	var K := Station.Kind
	if s.on_fire:
		return [["work", "Put out (hold)"]]
	if held == null:
		if s.dispenses():
			out.append(["interact", "Take"])
		elif s.item != null:
			out.append(["interact", "Pick up"])
		if s.item != null:
			match s.kind:
				K.BOARD:
					out.append(["work", "Chop (tap)"])
				K.MIXER:
					out.append(["work", "Mix (hold)"])
				K.WASH:
					if s.item is Vessel and (s.item as Vessel).dirty:
						out.append(["work", "Wash (hold)"])
				K.TARIK:
					if s.item is Vessel and (s.item as Vessel).contents.is_empty():
						out.append(["work", "Pull (tap)"])
		return out
	if held is Ingredient and s.item is Vessel and (s.item as Vessel).can_add(held as Ingredient):
		return [["interact", "Add to plate"]]
	if held is Vessel and s.item is Ingredient and (held as Vessel).can_add(s.item as Ingredient):
		return [["interact", "Add to plate"]]
	if s.accepts(held):
		var v := {K.HATCH: "Serve", K.BIN: "Throw away", K.WASH: "Put in sink", K.BOARD: "Put on board", K.MIXER: "Put in mixer", K.FRY: "Put in wok", K.BOIL: "Put in pot", K.TARIK: "Put under kettle"}
		out.append(["interact", v.get(s.kind, "Put down")])
	return out


func _update_prompt() -> void:
	var n := _nearest()
	var list := _actions(n) if n else []
	if list.is_empty():
		_prompt.hide()
		return
	var sig := ""
	for a in list:
		sig += "%s%s%s" % [a[0], a[1], Controls.key_name(_a(a[0]))]
	if sig != _prompt_sig:
		_prompt_sig = sig
		for c in _prompt_row.get_children():
			c.queue_free()
		for i in list.size():
			if i > 0:
				_prompt_row.add_child(UiKit.lbl("  ", 10))
			_prompt_row.add_child(UiKit.action_key(_a(list[i][0]), 30, true))
			var l := UiKit.lbl(String(list[i][1]), 18, UiKit.CREAM, 5)
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_prompt_row.add_child(l)
		_prompt.reset_size()
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var p := cam.unproject_position(n.global_position + Vector3(0, 0.2, 0.66))
	_prompt.position = p + Vector2(-_prompt.size.x / 2.0, 20)
	_prompt.show()


func _physics_process(delta: float) -> void:
	var dir := Input.get_vector(_a("move_left"), _a("move_right"), _a("move_up"), _a("move_down"))
	var moving := dir.length() > 0.1
	var want := Vector3(dir.x, 0, dir.y) * speed
	if moving:
		_face = Vector3(dir.x, 0, dir.y).normalized()
	_cd = maxf(_cd - delta, 0.0)
	if Input.is_action_just_pressed(_a("dash")) and _cd <= 0.0:
		_dash = DASH_TIME
		_cd = DASH_COOLDOWN
		Sfx.play("jump")
	if _dash > 0.0:
		_dash -= delta
		velocity = _face * DASH_SPEED
	else:
		var slick := kitchen != null and kitchen.puddle_on and kitchen.puddle.has_point(Vector2(global_position.x, global_position.z))
		var run := Input.is_action_pressed(_a("dash")) and moving
		velocity = velocity.lerp(want * (RUN_MULT if run else 1.0), 0.04 if slick else 1.0)
	move_and_slide()
	if moving:
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.y), 0.25)
	var anim := "idle"
	_t += delta
	if _model:
		var hop := sin(clampf(1.0 - _dash / DASH_TIME, 0.0, 1.0) * PI) * HOP if _dash > 0.0 else 0.0
		_model.position.y = hop
		var breathe := 1.0 + sin(_t * 2.6) * 0.012 if not moving and _dash <= 0.0 else 1.0
		var stretch := 1.0 + (0.18 * sin(clampf(1.0 - _dash / DASH_TIME, 0.0, 1.0) * PI) if _dash > 0.0 else 0.0)
		_model.scale = _model_scale * Vector3(1.0 / sqrt(stretch), stretch * breathe, 1.0 / sqrt(stretch))
		_shadow.scale = Vector3.ONE * (1.0 - hop * 0.8)
		if _hat:
			_hat.position.y = 1.2 * stretch + hop
	if _dash > 0.0 or (moving and Input.is_action_pressed(_a("dash"))):
		anim = "sprint"
	elif held != null:
		anim = "holding-both"
	elif moving:
		anim = "walk"
	_play(anim)
	_update_cues()
	_update_prompt()


func _update_cues() -> void:
	var key := Thumbs.key_for(held) if held != null else ""
	if key != _carry_key:
		_carry_key = key
		_carry.visible = key != ""
		if key != "":
			_carry.texture = Thumbs.tex(key)
	_carry.global_position = global_position + Vector3(0, 2.35 + sin(_t * 4.0) * 0.06, 0)
	var n := _nearest()
	if n != _last:
		if is_instance_valid(_last):
			_last.near = false
		_last = n
	if n:
		n.near = true
	for st in stations:
		st.hint = _wants(st)


func _wants(st: Station) -> bool:
	if held == null or st.item != null:
		return false
	if not (st.kind in [Station.Kind.BOARD, Station.Kind.FRY, Station.Kind.BOIL, Station.Kind.MIXER, Station.Kind.TARIK, Station.Kind.HATCH, Station.Kind.WASH]):
		return false
	if not st.accepts(held):
		return false
	if st.kind == Station.Kind.HATCH:
		return held is Vessel and Recipes.dish_of((held as Vessel).contents) != ""
	return true


func _play(name: String) -> void:
	if _anim and _anim.has_animation(name) and _anim.current_animation != name:
		_anim.play(name)


func _nearest() -> Station:
	var best: Station
	var best_d := reach
	for s in stations:
		var d := global_position.distance_to(s.global_position)
		if d < best_d:
			best_d = d
			best = s
	return best


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed(_a("interact")):
		_interact()
	elif e.is_action_pressed(_a("work")):
		var s := _nearest()
		if s:
			s.work_press()
			s.work_hold(true)
	elif e.is_action_released(_a("work")):
		var s := _nearest()
		if s:
			s.work_hold(false)


func _interact() -> void:
	var s := _nearest()
	if s == null:
		return
	if held == null:
		if s.dispenses():
			held = s.take_from_crate()
			add_child(held)
		elif s.item != null:
			held = s.take()
			held.reparent(self, false)
		else:
			return
		held.position = hand.position
		held.rotation = Vector3.ZERO
		Sfx.play("pick")
		return
	if held is Ingredient and s.item is Vessel and (s.item as Vessel).can_add(held as Ingredient):
		(s.item as Vessel).add(held as Ingredient)
		held = null
		Sfx.play("put")
		return
	if held is Vessel and s.item is Ingredient and (held as Vessel).can_add(s.item as Ingredient):
		var ing := s.take() as Ingredient
		(held as Vessel).add(ing)
		Sfx.play("put")
		return
	if s.accepts(held):
		var h := held
		held = null
		s.put(h)
		Sfx.play("put")
