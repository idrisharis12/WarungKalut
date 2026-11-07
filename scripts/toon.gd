class_name Toon
extends RefCounted

static var _shader: Shader = load("res://shaders/toon.gdshader")
static var _line: Shader = load("res://shaders/outline.gdshader")
static var _cache := {}


static func _convert(m: Material, width: float) -> Material:
	var key := "%d_%s" % [m.get_instance_id(), width]
	if _cache.has(key):
		return _cache[key]
	var out: Material = m
	if m is StandardMaterial3D and (m as StandardMaterial3D).transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
		var sm := m as StandardMaterial3D
		var mat := ShaderMaterial.new()
		mat.shader = _shader
		mat.set_shader_parameter("albedo", sm.albedo_color)
		mat.set_shader_parameter("use_vcol", sm.vertex_color_use_as_albedo)
		if sm.albedo_texture:
			mat.set_shader_parameter("albedo_tex", sm.albedo_texture)
			mat.set_shader_parameter("use_tex", true)
		if width > 0.0 and sm.cull_mode == BaseMaterial3D.CULL_BACK:
			var ol := ShaderMaterial.new()
			ol.shader = _line
			ol.set_shader_parameter("width", width)
			mat.next_pass = ol
		out = mat
	_cache[key] = out
	return out


# Turns every imported (non-primitive) mesh under n into flat cel-shaded surfaces with an ink outline.
static func apply(n: Node, width := 0.022) -> void:
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh == null or mi.mesh is PrimitiveMesh or mi.has_meta("toon"):
			continue
		mi.set_meta("toon", true)
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i)
			if m:
				mi.set_surface_override_material(i, _convert(m, width))
