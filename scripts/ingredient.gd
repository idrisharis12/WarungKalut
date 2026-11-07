class_name Ingredient
extends Node3D

signal state_changed(new_state: String)
signal progress_changed(value: float)
signal burnt

enum Action { NONE, CHOP, BOIL, FRY, MIX }


@export var ingredient_id := "chilli"
@export var models_dir := "res://Assets/warung_ingredients/"
@export var chop_hits := 5
@export var cook_seconds := 6.0
@export var burn_seconds := 5.0
@export var mix_seconds := 3.0

var state := "raw"
var progress := 0.0
var action := Action.NONE
var _mesh: Node3D
var _t := 0.0
var _hits := 0
var _base_scale := Vector3.ONE
var _tween: Tween
var _burn_timer := 0.0


func _ready() -> void:
	scale = Vector3.ONE * 1.7
	_swap_mesh("raw", false)


func has_state(s: String) -> bool:
	return ResourceLoader.exists(_path(s))


func _path(s: String) -> String:
	return "%s%s-%s.glb" % [models_dir, ingredient_id, s]


func _swap_mesh(s: String, pop: bool) -> void:
	if not has_state(s):
		return
	if _mesh:
		_mesh.queue_free()
	_mesh = make_visual(ingredient_id, s, models_dir)
	add_child(_mesh)
	state = s
	progress = 0.0
	_burn_timer = 0.0
	if pop:
		_mesh.scale = Vector3.ONE * 0.4
		var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_mesh, "scale", Vector3.ONE, 0.35)
	state_changed.emit(s)


# Illustrated sprite when one exists for this state, otherwise the 3D model.
static func make_visual(id: String, st: String, dir := "res://Assets/warung_ingredients/") -> Node3D:
	var tex := Thumbs.sprite("%s:%s" % [id, st])
	if tex != null:
		var sp := Sprite3D.new()
		sp.texture = tex
		sp.pixel_size = 0.55 / 256.0
		sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sp.shaded = false
		sp.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
		sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sp.position.y = 0.18
		sp.set_meta("sprite", true)
		var holder := Node3D.new()
		holder.add_child(sp)
		return holder
	return (load("%s%s-%s.glb" % [dir, id, st]) as PackedScene).instantiate()


func start(a: Action) -> void:
	action = a
	_t = 0.0


func stop() -> void:
	action = Action.NONE
	if _mesh:
		var tw := create_tween().set_parallel()
		tw.tween_property(_mesh, "position", Vector3.ZERO, 0.15)
		tw.tween_property(_mesh, "rotation", Vector3.ZERO, 0.15)
		tw.tween_property(_mesh, "scale", Vector3.ONE, 0.15)


# CHOP: call once per button press while the chef stands at the cutting board.
func chop_hit() -> void:
	if state != "raw" or not has_state("chopped"):
		return
	_hits += 1
	progress = float(_hits) / chop_hits
	progress_changed.emit(progress)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_mesh.scale = Vector3(1.25, 0.55, 1.25)
	_tween.tween_property(_mesh, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_mesh.position = Vector3(randf_range(-0.01, 0.01), 0, randf_range(-0.01, 0.01))
	_burst(4, 0.9)
	if _hits >= chop_hits:
		_hits = 0
		_swap_mesh("chopped", true)
		_burst(14, 1.4)


func _process(delta: float) -> void:
	if action == Action.NONE or _mesh == null:
		return
	_t += delta
	match action:
		Action.BOIL:
			_mesh.position.y = sin(_t * 7.0) * 0.012
			_mesh.rotation.z = sin(_t * 5.0) * 0.08
			_mesh.rotation.x = cos(_t * 4.3) * 0.08
			_cook_progress(delta, "cooked")
			if fmod(_t, 0.25) < delta:
				_burst(1, 0.5, Color(1, 1, 1, 0.7))
		Action.FRY:
			var toss := maxf(0.0, sin(_t * 9.0))
			_mesh.position.y = toss * 0.05
			_mesh.rotation.z = sin(_t * 9.0) * 0.18
			_mesh.rotation.y += delta * 3.0
			_cook_progress(delta, "cooked")
			if fmod(_t, 0.15) < delta:
				_burst(1, 0.6, Color(1, 0.8, 0.3, 0.9))
		Action.MIX:
			var a := _t * 8.0
			_mesh.position = Vector3(cos(a), 0, sin(a)) * 0.03
			_mesh.rotation.y = -a
			progress = clampf(_t / mix_seconds, 0.0, 1.0)
			progress_changed.emit(progress)
			if progress >= 1.0:
				action = Action.NONE
				_swap_mesh("mixed", true)
				_burst(12, 1.2)


func _cook_progress(delta: float, target: String) -> void:
	if state == "burnt":
		return
	if state != target:
		progress = clampf(progress + delta / cook_seconds, 0.0, 1.0)
		progress_changed.emit(progress)
		if progress >= 1.0 and has_state(target):
			_swap_mesh(target, true)
			Sfx.play("cook")
			_burst(10, 1.2)
		return
	_burn_timer += delta
	var warn := _burn_timer / burn_seconds
	progress_changed.emit(1.0 + warn)
	if warn > 0.6:
		_mesh.scale = Vector3.ONE * (1.0 + sin(_t * 30.0) * 0.04)
	if warn >= 1.0:
		state = "burnt"
		_tint(Color(0.12, 0.1, 0.1))
		burnt.emit()
		Sfx.play("burn")
		_burst(16, 1.5, Color(0.15, 0.15, 0.15, 0.9))


func _tint(c: Color) -> void:
	for n in _mesh.find_children("*", "Sprite3D", true, false):
		(n as Sprite3D).modulate = c.lightened(0.15)
	for n in _mesh.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c
		mi.material_override = mat


func _burst(count: int, spread: float, color := Color(1, 1, 1, 0.9)) -> void:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = count
	p.lifetime = 0.5
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 0.3 * spread
	p.initial_velocity_max = 0.8 * spread
	p.gravity = Vector3(0, -2.5, 0)
	var m := SphereMesh.new()
	m.radius = 0.012
	m.height = 0.024
	m.radial_segments = 6
	m.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material = mat
	p.mesh = m
	add_child(p)
	p.position.y = 0.04
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)
