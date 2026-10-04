extends Node
## Thin wrapper around the CrazyGames HTML5 SDK (v3).
##
## The SDK itself is loaded by the HTML shell (see export_presets.cfg -> html/head_include),
## which also defines a small `window.ZDBridge` helper. Outside the browser every call is a no-op,
## so the game runs exactly the same in the editor or as a desktop build.

signal ad_started
signal ad_finished

var _web := false
var _ad_callback: JavaScriptObject
var _ad_running := false
var _gameplay := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_web = OS.has_feature("web")
	if _web:
		_ad_callback = JavaScriptBridge.create_callback(_on_ad_event)

func _call(js: String) -> void:
	if _web:
		JavaScriptBridge.eval("try { if (window.ZDBridge) { %s } } catch (e) { console.warn(e); }" % js, true)

func loading_stop() -> void:
	_call("window.ZDBridge.loadingStop();")

func gameplay_start() -> void:
	if _gameplay:
		return
	_gameplay = true
	_call("window.ZDBridge.gameplayStart();")

func gameplay_stop() -> void:
	if not _gameplay:
		return
	_gameplay = false
	_call("window.ZDBridge.gameplayStop();")

func happytime() -> void:
	_call("window.ZDBridge.happytime();")

func is_ad_running() -> bool:
	return _ad_running

## Requests a midgame ad (shown between nights / before a restart).
## ad_finished is always emitted, also when no ad is available.
func request_midgame() -> void:
	if not _web:
		ad_finished.emit.call_deferred()
		return
	var bridge = JavaScriptBridge.get_interface("ZDBridge")
	if bridge == null:
		ad_finished.emit.call_deferred()
		return
	bridge.requestAd("midgame", _ad_callback)

func _on_ad_event(args: Array) -> void:
	var what := str(args[0]) if args.size() > 0 else "error"
	if what == "started":
		_ad_running = true
		Audio.set_ad_mute(true)
		get_tree().paused = true
		ad_started.emit()
	else:
		_ad_running = false
		Audio.set_ad_mute(false)
		ad_finished.emit()
