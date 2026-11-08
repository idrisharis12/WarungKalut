class_name Gp
extends RefCounted

static var _cb_pause: JavaScriptObject
static var _cb_resume: JavaScriptObject
static var _inited := false
static var _was_paused := false
static var _holds := 0


static func _web() -> bool:
	return OS.has_feature("web")


# Registers the GamePix pause/resume handlers and reports that loading is done.
static func init() -> void:
	if _inited or not _web():
		return
	_inited = true
	_cb_pause = JavaScriptBridge.create_callback(_on_pause)
	_cb_resume = JavaScriptBridge.create_callback(_on_resume)
	var w := JavaScriptBridge.get_interface("window")
	w.__wkPause = _cb_pause
	w.__wkResume = _cb_resume
	JavaScriptBridge.eval("""
		(function(){
			var h = function(f){ return function(){ try{ f(); }catch(e){} }; };
			var p = h(function(){ window.__wkPause(); });
			var r = h(function(){ window.__wkResume(); });
			if (window.GamePix && GamePix.events) {
				GamePix.events.on('pause', p);
				GamePix.events.on('resume', r);
			}
			document.addEventListener('visibilitychange', function(){
				if (document.hidden) { p(); } else { r(); }
			});
			if (window.GamePix && GamePix.lifecycle) {
				try { GamePix.lifecycle.loading(100); GamePix.lifecycle.loaded(); } catch(e){}
			}
		})();
	""", true)


static func game_start() -> void:
	if _web():
		JavaScriptBridge.eval("try{ if(window.GamePix) GamePix.lifecycle.gameStart(); }catch(e){}", true)


static func _on_pause(_args: Array) -> void:
	if _holds > 0:
		return
	_holds = 1
	var tree := Engine.get_main_loop() as SceneTree
	_was_paused = tree.paused
	tree.paused = true
	AudioServer.set_bus_mute(0, true)


static func _on_resume(_args: Array) -> void:
	if _holds == 0:
		return
	_holds = 0
	var tree := Engine.get_main_loop() as SceneTree
	tree.paused = _was_paused
	AudioServer.set_bus_mute(0, false)
