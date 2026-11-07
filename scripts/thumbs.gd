class_name Thumbs
extends RefCounted

const ING := "res://Assets/warung_ingredients/"
const KIT := "res://Assets/warung_kitchen/"
const FOOD := "res://Assets/kenney_food-kit/Models/GLB format/"
const SIZE := 192

static var _cache := {}


# Keys: "plate", "glass", "teh:tarik", "dish:<id>", "<ingredient>:<state>", "kit:<model>", "food:<model>".
# Each key renders its 3D model once in its own off-screen viewport.
static func sprite(key: String) -> Texture2D:
	if key.begins_with("kit:") or key.begins_with("food:") or key.begins_with("dish:") or key.begins_with("icon:"):
		return null
	var path := "res://Assets/sprites/%s.png" % key.replace(":", "-")
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


static func tex(key: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var sp := sprite(key)
	if sp != null:
		_cache[key] = sp
		return sp
	if key.begins_with("dish:"):
		var png := "res://Assets/dishes/%s.png" % key.substr(5)
		if ResourceLoader.exists(png):
			var pt := load(png) as Texture2D
			_cache[key] = pt
			return pt
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	root.add_child.call_deferred(vp)
	_build.call_deferred(vp, key)
	var t := vp.get_texture()
	_cache[key] = t
	return t


static func key_for(n: Node3D) -> String:
	if n is Ingredient:
		return "%s:%s" % [(n as Ingredient).ingredient_id, (n as Ingredient).state]
	if n is Vessel:
		var v := n as Vessel
		if v.is_glass:
			return "teh:tarik" if v.contents.has("teh:tarik") else "glass"
		var d := Recipes.dish_of(v.contents)
		return "dish:" + d if d != "" else "plate"
	return ""


static func _load(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	return (load(path) as PackedScene).instantiate() as Node3D


static func _fit_max(m: Node3D, s: float) -> void:
	var b := Kitchen._aabb(m)
	var mx := maxf(b.size.x, maxf(b.size.y, b.size.z))
	if mx > 0.0001:
		m.scale *= s / mx
	Kitchen._ground(m)


static func _put(parent: Node3D, path: String, size: float, pos := Vector3.ZERO) -> Node3D:
	var m := _load(path)
	if m == null:
		return null
	parent.add_child(m)
	_fit_max(m, size)
	m.position += pos
	return m


static func _build(vp: SubViewport, key: String) -> void:
	var root := Node3D.new()
	vp.add_child(root)
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 0.97, 0.92)
	env.ambient_light_energy = 0.8
	var cam := Camera3D.new()
	cam.environment = env
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.45
	var pos := Vector3(0, 2.4, 2.0)
	cam.transform = Transform3D(Basis.looking_at(Vector3(0, 0.3, 0) - pos, Vector3.UP), pos)
	root.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 0.9
	root.add_child(sun)

	var holder := Node3D.new()
	root.add_child(holder)
	var parts := key.split(":")
	if key == "plate":
		_put(holder, Vessel.PLATE, 1.15)
	elif key == "glass":
		_put(holder, Vessel.CUP, 0.95)
	elif key == "teh:tarik":
		_put(holder, Vessel.CUP_TEA, 0.95)
	elif parts[0] == "dish":
		var items: Array = Recipes.DISHES[parts[1]]["items"]
		if items == ["teh:tarik"]:
			_put(holder, Vessel.CUP_TEA, 0.95)
		else:
			_put(holder, Vessel.PLATE, 1.15)
			for i in items.size():
				var a := float(i) * TAU / items.size() + 0.6
				var r := 0.26 if items.size() > 1 else 0.0
				_put(holder, ING + String(items[i]).replace(":", "-") + ".glb", 0.42, Vector3(cos(a) * r, 0.07, sin(a) * r))
	elif parts[0] == "kit":
		_put(holder, KIT + parts[1] + ".glb", 0.95)
	elif parts[0] == "food":
		_put(holder, FOOD + parts[1] + ".glb", 0.95)
	else:
		_put(holder, ING + key.replace(":", "-") + ".glb", 0.9)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var tree := Engine.get_main_loop() as SceneTree
	for i in 4:
		await tree.process_frame
	if is_instance_valid(vp):
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
