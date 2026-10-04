class_name TouchControls
extends Control
## Multi-touch controls for phones/tablets: a floating joystick on the left
## and action buttons on the right. Hidden until the first touch.

signal action(name)

const BASE_R := 22.0

var move := Vector2.ZERO
var active := false
var show_interact := false
var build_mode := false

var _joy_index := -1
var _joy_center := Vector2.ZERO
var _joy_pos := Vector2.ZERO
var _buttons := {}        # name -> {pos, r, icon}
var _pressed := {}        # touch index -> button name
var _base_tex: Texture2D = preload("res://assets/sprites/joy_base.png")
var _knob_tex: Texture2D = preload("res://assets/sprites/joy_knob.png")
var _btn_tex: Texture2D = preload("res://assets/sprites/touch_btn.png")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _layout() -> void:
	var s := size
	_buttons = {
		"attack": {"pos": Vector2(s.x - 30, s.y - 56), "r": 16.0, "icon": "axe"},
		"shoot": {"pos": Vector2(s.x - 66, s.y - 70), "r": 14.0, "icon": "gun"},
		"eat": {"pos": Vector2(s.x - 24, s.y - 96), "r": 11.0, "icon": "food"},
	}
	if show_interact:
		_buttons["interact"] = {"pos": Vector2(s.x - 70, s.y - 108), "r": 13.0, "icon": "", "text": "E"}
	if build_mode:
		_buttons["attack"]["text"] = Lang.t("place")
		_buttons["attack"]["icon"] = ""
		_buttons["cancel"] = {"pos": Vector2(s.x - 24, s.y - 128), "r": 10.0, "icon": "", "text": "X"}


func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventScreenTouch:
		visible = true
		_layout()
		if event.pressed:
			var b := _button_at(event.position)
			if b != "":
				_pressed[event.index] = b
				action.emit(b)
				get_viewport().set_input_as_handled()
			elif event.position.x < size.x * 0.45 and event.position.y > 50 and _joy_index == -1:
				_joy_index = event.index
				_joy_center = event.position
				_joy_pos = event.position
				get_viewport().set_input_as_handled()
		else:
			_pressed.erase(event.index)
			if event.index == _joy_index:
				_joy_index = -1
				move = Vector2.ZERO
		queue_redraw()
	elif event is InputEventScreenDrag and event.index == _joy_index:
		_joy_pos = event.position
		var d: Vector2 = _joy_pos - _joy_center
		if d.length() > BASE_R:
			_joy_center += d - d.normalized() * BASE_R
		d = _joy_pos - _joy_center
		move = d / BASE_R if d.length() > 3.0 else Vector2.ZERO
		get_viewport().set_input_as_handled()
		queue_redraw()


func is_held(name: String) -> bool:
	return name in _pressed.values()


func _button_at(p: Vector2) -> String:
	for n in _buttons:
		if p.distance_to(_buttons[n]["pos"]) <= _buttons[n]["r"] + 6.0:
			return n
	return ""


func refresh(interact: bool, building: bool) -> void:
	if interact != show_interact or building != build_mode:
		show_interact = interact
		build_mode = building
		_layout()
		queue_redraw()


func _draw() -> void:
	if not visible:
		return
	_layout()
	var font := UITheme.font()
	for n in _buttons:
		var b: Dictionary = _buttons[n]
		var r: float = b["r"]
		var col := Color(1, 1, 1, 0.9 if is_held(n) else 0.6)
		draw_texture_rect(_btn_tex, Rect2(b["pos"] - Vector2(r, r), Vector2(r, r) * 2), false, col)
		if b["icon"] != "":
			draw_texture_rect(Res.icon(b["icon"]), Rect2(b["pos"] - Vector2(6, 6), Vector2(12, 12)), false)
		elif b.has("text"):
			var t: String = b["text"]
			var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			draw_string_outline(font, b["pos"] + Vector2(-w / 2.0, 4), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0.1, 0.06, 0.1))
			draw_string(font, b["pos"] + Vector2(-w / 2.0, 4), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	if _joy_index != -1:
		draw_texture(_base_tex, _joy_center - _base_tex.get_size() / 2.0)
		draw_texture(_knob_tex, _joy_pos - _knob_tex.get_size() / 2.0)
	else:
		var hint := Vector2(48, size.y - 52)
		draw_texture(_base_tex, hint - _base_tex.get_size() / 2.0, Color(1, 1, 1, 0.5))
