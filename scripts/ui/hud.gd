class_name HUD
extends CanvasLayer
## In-game interface: health, resources, day/night info, build bar and messages.

signal build_selected(kind)
signal pause_pressed
signal night_pressed

var root: Control
var hp_fill: ColorRect
var hp_label: Label
var melee_icon: TextureRect
var gun_icon: TextureRect
var area_label: Label
var res_labels := {}
var phase_icon: TextureRect
var phase_label: Label
var phase_bar: ColorRect
var score_label: Label
var msg_label: Label
var prompt_label: Label
var tip_label: Label
var hurt_rect: ColorRect
var night_btn: Button
var mute_btn: Button
var slots := {}
var slot_sel := {}
var touch: TouchControls
var _msg_tw: Tween


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.build()
	add_child(root)

	hurt_rect = ColorRect.new()
	hurt_rect.color = Color(0.8, 0.05, 0.05, 0.0)
	hurt_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hurt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hurt_rect)

	_build_status()
	_build_phase()
	_build_top_right()
	_build_bar()

	msg_label = UITheme.label("", 16, Color(1.0, 0.92, 0.6))
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	msg_label.position = Vector2(-200, 64)
	msg_label.size = Vector2(400, 20)
	msg_label.modulate.a = 0.0
	root.add_child(msg_label)

	prompt_label = UITheme.label("", 16, Color(0.75, 1.0, 0.7))
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position = Vector2(-150, -58)
	prompt_label.size = Vector2(300, 16)
	root.add_child(prompt_label)

	touch = TouchControls.new()
	root.add_child(touch)


func _panel(pos: Vector2, size: Vector2) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _icon(name: String, pos: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Res.icon(name)
	t.position = pos
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _build_status() -> void:
	var p := _panel(Vector2(4, 4), Vector2(170, 42))
	root.add_child(p)
	p.add_child(_icon("heart", Vector2(5, 4)))
	var bg := ColorRect.new()
	bg.color = Color(0.15, 0.08, 0.1)
	bg.position = Vector2(20, 6)
	bg.size = Vector2(144, 9)
	p.add_child(bg)
	hp_fill = ColorRect.new()
	hp_fill.color = Color(0.86, 0.2, 0.25)
	hp_fill.position = Vector2(21, 7)
	hp_fill.size = Vector2(142, 7)
	p.add_child(hp_fill)
	hp_label = UITheme.label("100", 16)
	hp_label.position = Vector2(80, 1)
	p.add_child(hp_label)
	var x := 4
	for r in Res.RESOURCES:
		p.add_child(_icon(r, Vector2(x, 24)))
		var l := UITheme.label("0", 16)
		l.position = Vector2(x + 13, 19)
		p.add_child(l)
		res_labels[r] = l
		x += 27
	# current weapons
	var wp := _panel(Vector2(4, 48), Vector2(46, 24))
	root.add_child(wp)
	melee_icon = TextureRect.new()
	melee_icon.position = Vector2(4, 4)
	melee_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wp.add_child(melee_icon)
	gun_icon = TextureRect.new()
	gun_icon.position = Vector2(25, 4)
	gun_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wp.add_child(gun_icon)
	area_label = UITheme.label("", 16, Color(0.8, 0.9, 1.0))
	area_label.position = Vector2(54, 50)
	root.add_child(area_label)


func _build_phase() -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_CENTER_TOP)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder)
	var p := _panel(Vector2(-62, 4), Vector2(124, 30))
	holder.add_child(p)
	phase_icon = _icon("sun", Vector2(5, 4))
	p.add_child(phase_icon)
	phase_label = UITheme.label("", 16)
	phase_label.position = Vector2(20, -1)
	phase_label.size = Vector2(100, 16)
	p.add_child(phase_label)
	var bg := ColorRect.new()
	bg.color = Color(0.15, 0.1, 0.15)
	bg.position = Vector2(6, 19)
	bg.size = Vector2(112, 5)
	p.add_child(bg)
	phase_bar = ColorRect.new()
	phase_bar.color = Color(1.0, 0.82, 0.35)
	phase_bar.position = Vector2(7, 20)
	phase_bar.size = Vector2(110, 3)
	p.add_child(phase_bar)
	night_btn = UITheme.button("", 124)
	night_btn.position = Vector2(-62, 36)
	night_btn.add_theme_font_size_override("font_size", 16)
	night_btn.pressed.connect(func(): night_pressed.emit())
	holder.add_child(night_btn)


func _build_top_right() -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder)
	score_label = UITheme.label("", 16, Color(1.0, 0.9, 0.5))
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.position = Vector2(-156, 24)
	score_label.size = Vector2(150, 16)
	holder.add_child(score_label)
	var pause := UITheme.button("II", 22)
	pause.position = Vector2(-28, 4)
	pause.pressed.connect(func(): pause_pressed.emit())
	holder.add_child(pause)
	mute_btn = UITheme.button("", 22)
	mute_btn.position = Vector2(-54, 4)
	mute_btn.pressed.connect(func():
		Audio.toggle_mute()
		_update_mute())
	holder.add_child(mute_btn)
	_update_mute()


func _update_mute() -> void:
	mute_btn.text = ""
	mute_btn.icon = Res.icon("mute" if Save.muted else "sound")


func _build_bar() -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder)
	var n := Res.BUILD_ORDER.size()
	var total := n * 24
	tip_label = UITheme.label("", 16)
	tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_label.position = Vector2(-160, -44)
	tip_label.size = Vector2(320, 16)
	holder.add_child(tip_label)
	for i in n:
		var kind: String = Res.BUILD_ORDER[i]
		var b := TextureButton.new()
		b.texture_normal = load("res://assets/sprites/slot.png")
		b.position = Vector2(-total / 2.0 + i * 24, -26)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): build_selected.emit(kind))
		b.mouse_entered.connect(func(): _show_tip(kind))
		b.mouse_exited.connect(func(): _show_tip(""))
		holder.add_child(b)
		var tex: Texture2D = Res.STRUCT_TEX[kind]
		var icon := TextureRect.new()
		if kind == "campfire":
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(0, 0, 16, 16)
			tex = at
		icon.texture = tex
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(3, 3)
		icon.size = Vector2(16, 16)
		b.add_child(icon)
		var num := UITheme.label(str(i + 1), 16)
		num.position = Vector2(1, 8)
		b.add_child(num)
		var sel := TextureRect.new()
		sel.texture = load("res://assets/sprites/slot_sel.png")
		sel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sel.visible = false
		b.add_child(sel)
		slots[kind] = b
		slot_sel[kind] = sel


var _selected := ""

func _show_tip(kind: String) -> void:
	if kind == "":
		kind = _selected
	if kind == "":
		tip_label.text = ""
		return
	tip_label.text = "%s: %s" % [Lang.t("b_" + kind), Res.cost_text(kind)]


func set_selected(kind: String, player: Player) -> void:
	_selected = kind
	for k in slot_sel:
		slot_sel[k].visible = k == kind
	_show_tip(kind)
	update_affordable(player)


func update_affordable(player: Player) -> void:
	for k in slots:
		var ok := player.has_cost(Res.BUILD[k]["cost"])
		slots[k].modulate = Color.WHITE if ok else Color(0.6, 0.55, 0.55, 0.85)


func set_hp(hp: float, max_hp: float) -> void:
	hp_fill.size.x = 142.0 * clampf(hp / max_hp, 0.0, 1.0)
	hp_label.text = str(int(ceil(hp)))
	hp_fill.color = Color(0.86, 0.2, 0.25) if hp > 30 else Color(1.0, 0.35, 0.2)


func set_weapons(melee: String, gun: String) -> void:
	melee_icon.texture = Res.weapon_icon(melee)
	gun_icon.texture = Res.weapon_icon(gun)


func set_area(text: String) -> void:
	area_label.text = text


func set_inventory(inv: Dictionary) -> void:
	for r in res_labels:
		res_labels[r].text = str(inv.get(r, 0))


func set_phase(is_night: bool, number: int, text: String, frac: float) -> void:
	phase_icon.texture = Res.icon("moon" if is_night else "sun")
	phase_label.text = "%s %d  %s" % [Lang.t("night" if is_night else "day"), number, text]
	phase_bar.size.x = 110.0 * clampf(frac, 0.0, 1.0)
	phase_bar.color = Color(0.55, 0.65, 1.0) if is_night else Color(1.0, 0.82, 0.35)


func set_score(score: int) -> void:
	score_label.text = "%s %d" % [Lang.t("score"), score]


func show_message(text: String, time := 2.2, color := Color(1.0, 0.92, 0.6)) -> void:
	msg_label.text = text
	msg_label.add_theme_color_override("font_color", color)
	if _msg_tw:
		_msg_tw.kill()
	msg_label.modulate.a = 1.0
	msg_label.scale = Vector2.ONE
	_msg_tw = create_tween()
	_msg_tw.tween_interval(time)
	_msg_tw.tween_property(msg_label, "modulate:a", 0.0, 0.5)


func hurt_flash() -> void:
	hurt_rect.color.a = 0.28
	var tw := create_tween()
	tw.tween_property(hurt_rect, "color:a", 0.0, 0.35)
