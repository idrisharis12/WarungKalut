class_name Vessel
extends Node3D

const PLATE := "res://Assets/kenney_food-kit/Models/GLB format/plate.glb"
const CUP := "res://Assets/warung_kitchen/teh-glass.glb"
const CUP_TEA := "res://Assets/warung_kitchen/teh-tarik.glb"
const PULLS := 8

var is_glass := false
var dirty := false
var _grime: MeshInstance3D
var contents: Array[String] = []
var pulls := 0
var _base: Node3D
var _tops: Array[Node3D] = []


func _ready() -> void:
	_set_base(CUP if is_glass else PLATE)


func _set_base(path: String) -> void:
	if _base:
		_base.queue_free()
	if not ResourceLoader.exists(path):
		return
	_base = (load(path) as PackedScene).instantiate() as Node3D
	add_child(_base)
	Kitchen.fit_width(_base, 0.3 if is_glass else 0.7)


func set_dirty(d: bool) -> void:
	dirty = d
	if d and _grime == null:
		_grime = MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.17
		c.bottom_radius = 0.17
		c.height = 0.012
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.35, 0.22, 0.1)
		c.material = m
		_grime.mesh = c
		_grime.position.y = 0.07
		add_child(_grime)
	elif not d and _grime != null:
		_grime.queue_free()
		_grime = null


func can_add(ing: Ingredient) -> bool:
	var key := "%s:%s" % [ing.ingredient_id, ing.state]
	return not dirty and not is_glass and contents.size() < 4 and Recipes.ITEM_NAMES.has(key) and not contents.has(key)


func add(ing: Ingredient) -> void:
	var key := "%s:%s" % [ing.ingredient_id, ing.state]
	contents.append(key)
	var path := "%s%s-%s.glb" % [ing.models_dir, ing.ingredient_id, ing.state]
	if ResourceLoader.exists(path):
		var m := Ingredient.make_visual(ing.ingredient_id, ing.state, ing.models_dir)
		add_child(m)
		var a := (contents.size() - 1) * TAU / 4.0
		var spr := m.get_child_count() > 0 and m.get_child(0) is Sprite3D
		m.position = Vector3(cos(a) * 0.15, 0.06 if not spr else 0.1, sin(a) * 0.15)
		m.scale = Vector3.ONE * (0.6 if spr else 0.85)
		_tops.append(m)
	ing.queue_free()


# Teh Tarik: one call per button press. Returns progress 0..1.
func pull() -> float:
	if not is_glass or contents.size() > 0:
		return 1.0
	pulls += 1
	if _base:
		_base.position.y = 0.0
		var tw := create_tween()
		tw.tween_property(_base, "position:y", 0.12, 0.08)
		tw.tween_property(_base, "position:y", 0.0, 0.08)
	if pulls >= PULLS:
		contents.append("teh:tarik")
		_set_base(CUP_TEA)
	return float(pulls) / PULLS


func summary() -> String:
	if contents.is_empty():
		return "empty"
	return ", ".join(PackedStringArray(contents.map(func(k): return Recipes.ITEM_NAMES.get(k, k))))
