class_name Kitchen
extends Node3D

const FURN := "res://Assets/Furniture Kit-glb/"
const FOOD := "res://Assets/kenney_food-kit/Models/GLB format/"
const KIT := "res://Assets/warung_kitchen/"
const SHOP := "res://Assets/kenney_mini-shop_2.1/Models/GLB format/"
const CITY := "res://Assets/City Kit-glb/"
const SUBURB := "res://Assets/Suburban Houses Pack-glb/"
const SURV := "res://Assets/Survival Kit-glb/"
const BLOCKY := "res://Assets/kenney_blocky-characters_20/Models/GLB format/"
const SKY := "res://Assets/kenney_skyboxes/Skyboxes/"
const TILE := 1.0
const START_PLATES := 4
const WALL_H := 1.5

var game: Game
var puddle := Rect2(2.0, 1.0, 4.0, 1.6)
var puddle_on := false
var plates_station: Station
var return_station: Station
var customers: Array[Node3D] = []
var _env: Environment
var _sun: DirectionalLight3D
var _cart: AnimatableBody3D
var _puddle_node: MeshInstance3D
var _chefs: Array[Chef] = []
var _cop: Node3D
var _cop_chase := false


# Scales node so its meshes are `h` tall, centres it on x/z and sits it on y=0.
static func fit_height(n: Node3D, h: float) -> void:
	var box := _aabb(n)
	if box.size.y > 0.0001:
		n.scale *= h / box.size.y
	_ground(n)


static func fit_scale(n: Node3D, s: float) -> void:
	n.scale *= s
	_ground(n)


static func fit_width(n: Node3D, w: float) -> void:
	var box := _aabb(n)
	var m := maxf(box.size.x, box.size.z)
	if m > 0.0001:
		n.scale *= w / m
	_ground(n)


static func _ground(n: Node3D) -> void:
	var box := _aabb(n)
	var c := box.get_center()
	n.position += Vector3(-c.x, -box.position.y, -c.z)


static func _aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var b := (n.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return AABB(out.position * n.scale, out.size * n.scale) if not first else out


func _ready() -> void:
	_input_map()
	Sfx.music()
	_floor()
	_surroundings()
	_camera()
	var chef := Chef.new()
	chef.position = Vector3(5.5, 0, 1.6)
	add_child(chef)
	var chef2: Chef
	if Recipes.coop:
		chef2 = Chef.new()
		chef2.player = 1
		chef2.position = Vector3(6.6, 0, 1.6)
		add_child(chef2)
	_chefs.append(chef)
	if chef2:
		_chefs.append(chef2)
	game = Game.new()
	add_child(game)
	game.police_called.connect(_police_call)
	game.police_left.connect(func(): _cop_chase = false)
	_layout(chef)
	if chef2:
		chef2.stations = chef.stations
		chef2.kitchen = self
	_props()
	_customers()
	Toon.apply(self)
	game.served_ok.connect(_cheer)
	_on_stage(Recipes.level)
	if Recipes.tutorial:
		var tut := Tutorial.new()
		add_child(tut)
		tut.setup.call_deferred(chef, game)


func _layout(chef: Chef) -> void:
	var K := Station.Kind
	# back row (z=0): ingredient crates, glass crate, tea, counters
	var back: Array = [
		[K.CRATE, "batter"], [K.CRATE, "chicken"], [K.CRATE, "shallot"], [K.CRATE, "rice"],
		[K.CRATE, "anchovy"], [K.CRATE, "cucumber"], [K.CRATE, "sambal"], [K.CRATE, "glass"],
		[K.TARIK, ""], [K.COUNTER, ""], [K.COUNTER, ""],
	]
	for i in back.size():
		_station(back[i][0], back[i][1], Vector3(i * TILE, 0, 0), 0.0, chef)
	# island (z=3): reachable from both aisles
	var island: Array = [K.BOARD, K.BOARD, K.MIXER, K.FRY, K.BOIL, K.COUNTER]
	for i in island.size():
		_station(island[i], "", Vector3(3.0 + i * TILE, 0, 3.0), 0.0, chef)
	# left wall (x=-1)
	for z in range(1, 6):
		_station(K.COUNTER, "", Vector3(-1.0, 0, z), PI / 2, chef)
	# front row (z=6): washing and clean plates
	var front: Array = [K.COUNTER, K.COUNTER, K.WASH, K.COUNTER, K.PLATES, K.COUNTER, K.COUNTER, K.BIN, K.COUNTER, K.COUNTER, K.COUNTER]
	for i in front.size():
		var st := _station(front[i], "", Vector3(i * TILE, 0, 6.0), PI, chef)
		if front[i] == K.PLATES:
			plates_station = st
			st.set_stock(START_PLATES)
	# right wall (x=11): hatch out, dirty plates back in
	_station(K.COUNTER, "", Vector3(11.0, 0, 1.0), -PI / 2, chef)
	_station(K.HATCH, "", Vector3(11.0, 0, 2.0), -PI / 2, chef)
	return_station = _station(K.RETURN, "", Vector3(11.0, 0, 3.0), -PI / 2, chef)
	_station(K.COUNTER, "", Vector3(11.0, 0, 4.0), -PI / 2, chef)
	_station(K.COUNTER, "", Vector3(11.0, 0, 5.0), -PI / 2, chef)
	for s in chef.stations:
		s.vessel_gone.connect(_vessel_gone)
		s.plate_washed.connect(func(): plates_station.set_stock(plates_station.stock + 1))


func _vessel_gone(plate: bool, delay: float) -> void:
	if not plate:
		return
	get_tree().create_timer(delay).timeout.connect(func(): return_station.set_stock(return_station.stock + 1))


func _props() -> void:
	_fit(SHOP + "cash-register.glb", Vector3(11, 0.9, 1), 0.6, -PI / 2)
	_fit(FURN + "Radio.glb", Vector3(9, 0.9, 0), 0.5, 0.0)
	_fit(FURN + "Kitchen Coffee Machine.glb", Vector3(10, 0.9, 0), 0.5, 0.0)
	_fit(FURN + "Kitchen Blender.glb", Vector3(10, 0.9, 6), 0.4, PI, true)
	_fit(FURN + "Plant Small.glb", Vector3(-1, 0.9, 1), 0.4, 0.0, true)
	_fit(FURN + "Lamp Round Table.glb", Vector3(-1, 0.9, 5), 0.5, 0.0, true)
	_fit(FOOD + "bowl.glb", Vector3(0, 0.9, 6), 0.4, 0.0, true)
	_fit(SHOP + "shopping-basket.glb", Vector3(1, 0.9, 6), 0.5, 0.0, true)


# fit by width (or height when `height` is true), place at pos with yaw
func _fit(path: String, pos: Vector3, size: float, yaw: float, height := false) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var m := (load(path) as PackedScene).instantiate() as Node3D
	add_child(m)
	if height:
		Kitchen.fit_height(m, size)
	else:
		Kitchen.fit_width(m, size)
	m.position += pos
	m.rotation.y = yaw
	return m


func _customers() -> void:
	var picks := ["character-d", "character-h", "character-m", "character-b"]
	var spots := [Vector3(12.4, 0, 2.0), Vector3(13.5, 0, 2.5), Vector3(13.2, 0, 1.2), Vector3(14.4, 0, 3.0)]
	for i in picks.size():
		var p: String = BLOCKY + picks[i] + ".glb"
		if not ResourceLoader.exists(p):
			continue
		var c := (load(p) as PackedScene).instantiate() as Node3D
		add_child(c)
		Kitchen.fit_height(c, 1.1)
		c.position += spots[i]
		c.rotation.y = -PI / 2
		_anim(c, "idle")
		customers.append(c)
	_fit(SHOP + "display-bread.glb", Vector3(12.0, 0, 5.2), 1.2, -PI / 2)
	_fit(SHOP + "display-fruit.glb", Vector3(12.0, 0, 6.4), 1.2, -PI / 2)


const COP_SPAWN := Vector3(15.5, 0, 2.5)
const COP_SPEED := 1.9
const COP_CATCH := 0.85


func _police_call() -> void:
	_cop_chase = true
	if is_instance_valid(_cop):
		return
	var p := BLOCKY + "character-j.glb"
	if not ResourceLoader.exists(p):
		return
	_cop = Node3D.new()
	var m := (load(p) as PackedScene).instantiate() as Node3D
	_cop.add_child(m)
	add_child(_cop)
	Kitchen.fit_height(m, 1.25)
	Toon.apply(_cop, 0.012)
	_cop.position = COP_SPAWN
	_anim(m, "walk")


func _process(delta: float) -> void:
	if not is_instance_valid(_cop) or game.over:
		return
	var target := COP_SPAWN
	if _cop_chase:
		var best := INF
		for c in _chefs:
			var d := _cop.position.distance_to(c.global_position)
			if d < best:
				best = d
				target = c.global_position
		if best < COP_CATCH:
			game.busted()
			return
	var to := target - _cop.position
	to.y = 0.0
	if to.length() < 0.1:
		if not _cop_chase:
			_cop.queue_free()
			_cop = null
		return
	_cop.position += to.normalized() * minf(COP_SPEED * delta, to.length())
	_cop.rotation.y = lerp_angle(_cop.rotation.y, atan2(to.x, to.z), 0.2)


func _anim(n: Node3D, a: String) -> void:
	var ap := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap and ap.has_animation(a):
		ap.play(a)


func _cheer() -> void:
	if customers.is_empty():
		return
	var c: Node3D = customers.pick_random()
	_anim(c, "emote-yes")
	get_tree().create_timer(1.6).timeout.connect(func(): if is_instance_valid(c): _anim(c, "idle"))


func _on_stage(i: int) -> void:
	if i == 1 or i >= 2:
		puddle_on = true
		_puddle_visual()
	if i >= 2 and _cart == null:
		_make_cart()
	_set_sky(i)


func _set_sky(i: int) -> void:
	var names: Array[String] = ["skybox-morning.png", "skybox-day.png", "skybox-night.png", "skybox-night.png"]
	var path: String = SKY + names[clampi(i, 0, 3)]
	if _env and ResourceLoader.exists(path):
		var pm := PanoramaSkyMaterial.new()
		pm.panorama = load(path)
		var sky := Sky.new()
		sky.sky_material = pm
		_env.sky = sky
		_env.background_mode = Environment.BG_COLOR
	if _sun:
		_sun.light_energy = 0.4 if i >= 2 else 0.75
		_sun.light_color = Color(0.7, 0.75, 1.0) if i >= 2 else Color(1.0, 0.96, 0.88)


func _puddle_visual() -> void:
	if _puddle_node:
		return
	_puddle_node = MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(puddle.size.x, 0.02, puddle.size.y)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 0.55, 0.85, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	b.material = m
	_puddle_node.mesh = b
	_puddle_node.position = Vector3(puddle.position.x + puddle.size.x / 2.0, 0.03, puddle.position.y + puddle.size.y / 2.0)
	add_child(_puddle_node)


func _make_cart() -> void:
	_cart = AnimatableBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.0, 1.0, 0.7)
	cs.shape = bs
	cs.position.y = 0.5
	_cart.add_child(cs)
	var cart := _fit(SHOP + "shopping-cart.glb", Vector3.ZERO, 1.0, PI / 2)
	if cart:
		remove_child(cart)
		_cart.add_child(cart)
	else:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.0, 0.9, 0.7)
		mi.mesh = bm
		mi.position.y = 0.5
		_cart.add_child(mi)
	var l := Label3D.new()
	l.text = "CART"
	l.position = Vector3(0, 1.4, 0)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.pixel_size = 0.006
	_cart.add_child(l)
	_cart.position = Vector3(1.5, 0, 4.7)
	add_child(_cart)
	var tw := create_tween().set_loops()
	tw.tween_property(_cart, "position:x", 9.5, 7.0)
	tw.tween_property(_cart, "position:x", 1.5, 7.0)


func _station(kind: Station.Kind, id: String, pos: Vector3, yaw: float, chef: Chef) -> Station:
	var s := Station.new()
	s.kind = kind
	s.crate_id = id
	s.position = pos
	s.rotation.y = yaw
	add_child(s)
	var model := FURN + "Kitchen Cabinet.glb"
	var no_scale := false
	match kind:
		Station.Kind.FRY, Station.Kind.BOIL:
			model = FURN + "Kitchen Stove.glb"
		Station.Kind.WASH:
			model = FURN + "Kitchen Sink.glb"
		Station.Kind.BIN:
			model = FURN + "Trashcan.glb"
		Station.Kind.HATCH:
			model = KIT + "serving-hatch.glb"
			no_scale = true
	if ResourceLoader.exists(model):
		var m := (load(model) as PackedScene).instantiate() as Node3D
		s.add_child(m)
		if no_scale:
			Kitchen.fit_scale(m, 1.0)
		else:
			Kitchen.fit_height(m, 0.9)
			_ground_square(m)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.95, 1.0, 0.95)
	cs.shape = bs
	cs.position.y = 0.5
	body.add_child(cs)
	s.add_child(body)
	_station_look(s)
	s.dish_served.connect(game.serve)
	s.fire_started.connect(game.fire_started)
	chef.stations.append(s)
	chef.kitchen = self
	return s


# Each station is one cabinet/stove plus the tool that defines it, sized to read from the camera.
const TOPS := {
	Station.Kind.BOARD: [FOOD + "cutting-board.glb", 0.95, 0.0],
	Station.Kind.FRY: [KIT + "wok.glb", 0.95, 0.0],
	Station.Kind.BOIL: [FOOD + "pot-stew.glb", 0.8, 0.0],
	Station.Kind.MIXER: [KIT + "mixing-bowl.glb", 0.8, 0.0],
	Station.Kind.TARIK: [KIT + "kettle.glb", 0.7, 0.0],
}


func _station_look(s: Station) -> void:
	if TOPS.has(s.kind):
		var t: Array = TOPS[s.kind]
		var y := 0.9 if s.kind != Station.Kind.FRY and s.kind != Station.Kind.BOIL else 0.98
		if ResourceLoader.exists(t[0]):
			var m := (load(t[0]) as PackedScene).instantiate() as Node3D
			s.add_child(m)
			Kitchen.fit_width(m, float(t[1]))
			m.position.y += y
	if s.kind == Station.Kind.CRATE:
		var key := "glass" if s.crate_id == "glass" else s.crate_id + ":raw"
		var tex := Thumbs.sprite(key)
		if tex != null:
			var n := 2 if key == "glass" else 1
			for i in n:
				var sh := Sprite3D.new()
				sh.texture = _shadow_tex()
				sh.axis = Vector3.AXIS_Y
				sh.pixel_size = 0.0035
				sh.shaded = false
				sh.modulate = Color(1, 1, 1, 0.45)
				s.add_child(sh)
				var sp := Sprite3D.new()
				sp.texture = tex
				sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				sp.shaded = false
				sp.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
				sp.pixel_size = (0.95 if key != "glass" else 0.7) / 256.0
				s.add_child(sp)
				var dx := 0.0 if n == 1 else (-0.22 if i == 0 else 0.22)
				sp.position = Vector3(dx, 0.95 + (0.0 if key != "glass" else 0.05), 0.02)
				sh.position = Vector3(dx, 0.92, 0)
				if key == "glass":
					sp.position.y = 0.97
					sh.pixel_size = 0.0022
		return


static var _shadow: ImageTexture


func _shadow_tex() -> ImageTexture:
	if _shadow == null:
		var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
		for y in 128:
			for x in 128:
				var d := Vector2(x - 63.5, y - 63.5).length() / 64.0
				img.set_pixel(x, y, Color(0.1, 0.04, 0.02, clampf(1.0 - d, 0.0, 1.0) * 0.9))
		_shadow = ImageTexture.create_from_image(img)
	return _shadow


func _ground_square(m: Node3D) -> void:
	var box := Kitchen._aabb(m)
	var k := TILE * 0.95 / maxf(box.size.x, box.size.z)
	m.scale *= Vector3(k, 1.0, k)
	m.position = Vector3.ZERO
	Kitchen._ground(m)


func _decor(path: String, pos: Vector3, k: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var m := (load(path) as PackedScene).instantiate() as Node3D
	add_child(m)
	Kitchen.fit_scale(m, k)
	m.position += pos


func _batik() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	var base := Color(0.62, 0.2, 0.15)
	var gold := Color(0.95, 0.75, 0.3)
	var teal := Color(0.1, 0.45, 0.42)
	for y in 64:
		for x in 64:
			var dx := absf(fmod(x, 32.0) - 16.0)
			var dy := absf(fmod(y, 32.0) - 16.0)
			var d := dx + dy
			var c := base
			if d < 4.0:
				c = gold
			elif d < 8.0:
				c = teal
			elif absf(d - 16.0) < 1.5:
				c = gold.darkened(0.25)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _floor() -> void:
	var f := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(14, 0.1, 8)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _batik()
	mat.uv1_scale = Vector3(14, 8, 1)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	b.material = mat
	f.mesh = b
	f.position = Vector3(5, -0.05, 3)
	add_child(f)
	var ground := MeshInstance3D.new()
	var gb := BoxMesh.new()
	gb.size = Vector3(90, 0.1, 60)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.13, 0.06, 0.05)
	gb.material = gm
	ground.mesh = gb
	ground.position = Vector3(5, -0.12, 3)
	add_child(ground)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-60, 20, 0)
	_sun.light_color = Color(1.0, 0.96, 0.88)
	_sun.light_energy = 0.75
	add_child(_sun)
	var we := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.2, 0.17, 0.2)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(1.0, 0.95, 0.9)
	_env.ambient_light_energy = 0.55
	we.environment = _env
	add_child(we)
	_set_sky(0)


# Wall pieces from the Mini Shop kit placed edge to edge along a line.
func _wall_line(from: Vector3, to: Vector3, along_x: bool, skip: Rect2 = Rect2()) -> void:
	var plain := SHOP + "wall.glb"
	var win := SHOP + "wall-window.glb"
	if not ResourceLoader.exists(plain):
		return
	var step := 1.0
	var pos := from
	var i := 0
	while (pos.x <= to.x + 0.01 if along_x else pos.z <= to.z + 0.01):
		var m := (load(win if i % 3 == 1 and ResourceLoader.exists(win) else plain) as PackedScene).instantiate() as Node3D
		add_child(m)
		Kitchen.fit_height(m, WALL_H)
		var bx := Kitchen._aabb(m)
		var long_x := bx.size.x >= bx.size.z
		if along_x != long_x:
			m.rotation.y = PI / 2
		step = maxf(bx.size.x, bx.size.z)
		var skipped := skip.size != Vector2.ZERO and skip.has_point(Vector2(pos.x, pos.z))
		if skipped:
			m.queue_free()
		else:
			m.position += pos
		pos += Vector3(step, 0, 0) if along_x else Vector3(0, 0, step)
		i += 1


func _surroundings() -> void:
	_wall_line(Vector3(-1.6, 0, -0.62), Vector3(11.6, 0, -0.62), true)
	for i in 6:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(i * 2.2, 3.0, 2.0)
		lamp.light_color = Color(1.0, 0.85, 0.6)
		lamp.omni_range = 5.0
		lamp.light_energy = 0.15
		add_child(lamp)


func _camera() -> void:
	var c := Camera3D.new()
	c.projection = Camera3D.PROJECTION_ORTHOGONAL
	c.keep_aspect = Camera3D.KEEP_HEIGHT
	c.far = 80.0
	c.position = Vector3(5, 20, 3 + 6.5)
	add_child(c)
	c.look_at(Vector3(5, 0, 3))
	# Ortho view sized so the whole kitchen fits between the HUD bands.
	var fit := func():
		var sz := get_viewport().get_visible_rect().size
		var free := (sz.y - Game.TOP - Game.BOT) / sz.y
		c.size = maxf(7.5 / free, 13.4 * sz.y / sz.x)
		c.v_offset = (Game.TOP - Game.BOT) / 2.0 / sz.y * c.size
	get_viewport().size_changed.connect(fit)
	fit.call()


func _input_map() -> void:
	Controls.apply()
