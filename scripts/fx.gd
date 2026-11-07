class_name Fx
extends RefCounted

static var _layer: CanvasLayer
static var _left: ColorRect
static var _right: ColorRect
static var _busy := false


static func _ensure() -> void:
	if is_instance_valid(_layer):
		return
	_layer = CanvasLayer.new()
	_layer.layer = 100
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var r := ColorRect.new()
		r.color = Color(0.5, 0.12, 0.1)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var edge := ColorRect.new()
		edge.color = UiKit.GOLD
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.add_child(edge)
		_layer.add_child(r)
		if i == 0:
			_left = r
		else:
			_right = r
	(Engine.get_main_loop() as SceneTree).root.add_child(_layer)


static func _place(open: float) -> void:
	var sz := (Engine.get_main_loop() as SceneTree).root.get_visible_rect().size
	var w := sz.x / 2.0
	_left.size = Vector2(w + 4, sz.y)
	_right.size = Vector2(w + 4, sz.y)
	_left.position = Vector2(-w * open - 4 * open, 0)
	_right.position = Vector2(w + w * open, 0)
	var le := _left.get_child(0) as ColorRect
	le.position = Vector2(_left.size.x - 8, 0)
	le.size = Vector2(8, sz.y)
	var re := _right.get_child(0) as ColorRect
	re.position = Vector2.ZERO
	re.size = Vector2(8, sz.y)


# Curtain wipe: closes, swaps the scene, then opens.
static func go(path := "") -> void:
	if _busy:
		return
	_busy = true
	var tree := Engine.get_main_loop() as SceneTree
	tree.paused = false
	_ensure()
	_layer.visible = true
	_place(1.0)
	var tw := _layer.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(_place, 1.0, 0.0, 0.32)
	await tw.finished
	if path == "":
		tree.reload_current_scene()
	else:
		tree.change_scene_to_file(path)
	for i in 3:
		await tree.process_frame
	var tw2 := _layer.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw2.tween_method(_place, 0.0, 1.0, 0.32)
	await tw2.finished
	_layer.visible = false
	_busy = false
