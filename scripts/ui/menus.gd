class_name Menus
extends CanvasLayer
## Main menu, help screen, pause menu and game-over screen.

signal play_pressed
signal resume_pressed
signal menu_pressed
signal again_pressed

var dim: ColorRect
var main_box: Control
var help_box: Control
var pause_box: Control
var over_box: Control
var best_label: Label
var over_stats: Label
var over_new: Label
var _sound_buttons: Array[Button] = []
var _lang_button: Button
var _title_t := 0.0
var _title: Label
var _villagers: Array = []
var ui: Control


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = UITheme.build()
	add_child(ui)
	dim = ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.08, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(dim)
	_build_main()
	_build_help()
	_build_pause()
	_build_over()
	hide_all()


func _center_box(w: float) -> VBoxContainer:
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(holder)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(w, 0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	holder.add_child(v)
	return v


func _centered(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return c


func _build_main() -> void:
	var v := _center_box(240)
	main_box = v.get_parent()
	_title = UITheme.label(Lang.t("title"), 32, Color(0.62, 0.9, 0.42))
	_title.add_theme_font_override("font", UITheme.title_font())
	_title.add_theme_constant_override("outline_size", 8)
	_title.add_theme_color_override("font_outline_color", Color(0.12, 0.2, 0.1))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.pivot_offset = Vector2(120, 16)
	v.add_child(_title)
	var sub := UITheme.label(Lang.t("subtitle"), 16, Color(1.0, 0.85, 0.55))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.custom_minimum_size = Vector2(0, 30)
	v.add_child(row)
	for skin in ["zombie_farmer", "zombie_granny", "zombie_brute", "zombie_girl", "zombie_cap"]:
		var at := AtlasTexture.new()
		var tex: Texture2D = Res.ZOMBIE_TEX[skin]
		at.atlas = tex
		at.region = Rect2(0, 0, tex.get_width() / 6.0, tex.get_height() / 3.0)
		var tr := TextureRect.new()
		tr.texture = at
		tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		tr.custom_minimum_size = Vector2(20, 28)
		row.add_child(tr)
		_villagers.append([tr, at, tex])
	var play := UITheme.button(Lang.t("play"), 120)
	play.pressed.connect(func(): play_pressed.emit())
	v.add_child(_centered(play))
	var how := UITheme.button(Lang.t("how"), 120)
	how.pressed.connect(func():
		hide_all()
		help_box.visible = true
		dim.visible = true)
	v.add_child(_centered(how))
	var h2 := HBoxContainer.new()
	h2.alignment = BoxContainer.ALIGNMENT_CENTER
	h2.add_theme_constant_override("separation", 4)
	v.add_child(h2)
	var snd := _sound_button(84)
	h2.add_child(snd)
	_lang_button = UITheme.button("NL / EN", 32)
	_lang_button.text = "EN" if Lang.lang == "nl" else "NL"
	_lang_button.pressed.connect(func():
		Lang.lang = "en" if Lang.lang == "nl" else "nl"
		get_tree().reload_current_scene())
	h2.add_child(_lang_button)
	best_label = UITheme.label("", 16, Color(1.0, 0.9, 0.5))
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(best_label)


func _sound_button(w: int) -> Button:
	var b := UITheme.button("", w)
	b.pressed.connect(func():
		Audio.toggle_mute()
		_refresh_sound())
	_sound_buttons.append(b)
	return b


func _refresh_sound() -> void:
	for b in _sound_buttons:
		b.text = Lang.t("sound_off" if Save.muted else "sound_on")


func _build_help() -> void:
	var v := _center_box(380)
	help_box = v.get_parent()
	var panel := PanelContainer.new()
	v.add_child(panel)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	panel.add_child(inner)
	var t := UITheme.label(Lang.t("help_title"), 16, Color(0.62, 0.9, 0.42))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(t)
	var body := UITheme.label(Lang.t("help_text"), 16)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(360, 0)
	inner.add_child(body)
	var back := UITheme.button(Lang.t("back"), 90)
	back.pressed.connect(show_main)
	inner.add_child(_centered(back))


func _build_pause() -> void:
	var v := _center_box(160)
	pause_box = v.get_parent()
	var t := UITheme.label(Lang.t("paused"), 32, Color(1.0, 0.9, 0.5))
	t.add_theme_font_override("font", UITheme.title_font())
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var r := UITheme.button(Lang.t("resume"), 120)
	r.pressed.connect(func(): resume_pressed.emit())
	v.add_child(_centered(r))
	v.add_child(_centered(_sound_button(120)))
	var m := UITheme.button(Lang.t("menu"), 120)
	m.pressed.connect(func(): menu_pressed.emit())
	v.add_child(_centered(m))


func _build_over() -> void:
	var v := _center_box(260)
	over_box = v.get_parent()
	var t := UITheme.label(Lang.t("game_over"), 16, Color(1.0, 0.4, 0.35))
	t.add_theme_font_override("font", UITheme.title_font())
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	over_new = UITheme.label(Lang.t("new_best"), 16, Color(1.0, 0.9, 0.3))
	over_new.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(over_new)
	var panel := PanelContainer.new()
	v.add_child(panel)
	over_stats = UITheme.label("", 16)
	over_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(over_stats)
	var a := UITheme.button(Lang.t("again"), 120)
	a.pressed.connect(func(): again_pressed.emit())
	v.add_child(_centered(a))
	var m := UITheme.button(Lang.t("menu"), 120)
	m.pressed.connect(func(): menu_pressed.emit())
	v.add_child(_centered(m))


func hide_all() -> void:
	for b in [main_box, help_box, pause_box, over_box]:
		b.visible = false
	dim.visible = false


func show_main() -> void:
	hide_all()
	_refresh_sound()
	main_box.visible = true
	dim.visible = true
	dim.color.a = 0.45
	if Save.best_score > 0:
		best_label.text = "%s: %d  (%s %d)" % [Lang.t("best"), Save.best_score, Lang.t("night"), Save.best_night]
	else:
		best_label.text = ""


func show_pause() -> void:
	hide_all()
	_refresh_sound()
	pause_box.visible = true
	dim.visible = true
	dim.color.a = 0.55


func show_over(nights: int, kills: int, score: int, is_best: bool) -> void:
	hide_all()
	over_box.visible = true
	dim.visible = true
	dim.color.a = 0.0
	create_tween().tween_property(dim, "color:a", 0.6, 1.0)
	over_new.visible = is_best
	over_stats.text = "%s: %d\n%s: %d\n%s: %d\n%s: %d" % [
		Lang.t("survived"), nights, Lang.t("kills"), kills, Lang.t("score"), score, Lang.t("best"), Save.best_score]
	over_box.modulate.a = 0.0
	create_tween().tween_property(over_box, "modulate:a", 1.0, 0.6).set_delay(0.6)


func _process(delta: float) -> void:
	if not main_box.visible:
		return
	_title_t += delta
	_title.rotation = sin(_title_t * 1.6) * 0.03
	var f := int(_title_t * 6.0) % 4
	for v in _villagers:
		var tex: Texture2D = v[2]
		var fw: float = tex.get_width() / 6.0
		var fh: float = tex.get_height() / 3.0
		v[1].region = Rect2(f * fw, 0, fw, fh)
