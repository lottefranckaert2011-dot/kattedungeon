class_name Shop
extends CanvasLayer
## The weapon shop: spend coins on better weapons, ammo and food.

signal closed

var player: Player
var ui: Control
var coins_label: Label
var _rows := []   # [item, button, price_label]


func _ready() -> void:
	layer = 18
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.theme = UITheme.build()
	add_child(ui)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.08, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	panel.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	v.add_child(head)
	var title := UITheme.label(Lang.t("shop_title"), 16, Color(1.0, 0.85, 0.4))
	title.add_theme_font_override("font", UITheme.title_font())
	head.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var coin := TextureRect.new()
	coin.texture = Res.icon("coins")
	coin.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(coin)
	coins_label = UITheme.label("0", 16, Color(1.0, 0.9, 0.4))
	head.add_child(coins_label)

	for item in Res.SHOP:
		v.add_child(_make_row(item))

	var close := UITheme.button(Lang.t("close"), 100)
	close.pressed.connect(close_shop)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(close)


func _make_row(item: Dictionary) -> Control:
	var id: String = item["id"]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.custom_minimum_size = Vector2(300, 24)
	var icon := TextureRect.new()
	icon.texture = Res.weapon_icon(id) if Res.WEAPONS.has(id) else Res.icon(item["give"].keys()[0])
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.custom_minimum_size = Vector2(18, 18)
	row.add_child(icon)
	var texts := VBoxContainer.new()
	texts.add_theme_constant_override("separation", -1)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(texts)
	texts.add_child(UITheme.label(Lang.t("w_" + id), 16))
	var desc := Lang.t("d_" + id)
	if Res.WEAPONS.has(id):
		var w: Dictionary = Res.WEAPONS[id]
		desc = "%s - %d %s" % [desc, int(w["damage"] * w.get("pellets", 1)), Lang.t("damage")]
	texts.add_child(UITheme.label(desc, 16, Color(0.75, 0.75, 0.8)))
	var price := UITheme.label("%d" % item["price"], 16, Color(1.0, 0.9, 0.4))
	price.custom_minimum_size = Vector2(26, 0)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(price)
	var coin := TextureRect.new()
	coin.texture = Res.icon("coins")
	coin.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(coin)
	var b := UITheme.button(Lang.t("buy"), 70)
	b.pressed.connect(func(): _buy(item))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(b)
	_rows.append([item, b, price])
	return row


func open_shop(p: Player) -> void:
	player = p
	visible = true
	_refresh()
	Audio.play("search_house", -4.0)


func close_shop() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("pause") or event.is_action_pressed("interact")):
		get_viewport().set_input_as_handled()
		close_shop()


func _refresh() -> void:
	coins_label.text = str(player.inv.get("coins", 0))
	for r in _rows:
		var item: Dictionary = r[0]
		var b: Button = r[1]
		var id: String = item["id"]
		var owned := id in player.owned
		r[2].visible = not owned
		if owned:
			var in_hand := player.melee == id or player.gun == id
			b.text = Lang.t("equipped" if in_hand else "equip")
			b.disabled = in_hand
		else:
			b.text = Lang.t("buy")
			b.disabled = false
			b.modulate = Color.WHITE if player.inv.get("coins", 0) >= item["price"] else Color(0.75, 0.7, 0.7)


func _buy(item: Dictionary) -> void:
	var id: String = item["id"]
	if id in player.owned:
		player.equip(id)
		_refresh()
		return
	var price: int = item["price"]
	if player.inv.get("coins", 0) < price:
		Audio.play("error", -6.0)
		coins_label.text = Lang.t("no_coins")
		return
	player.inv["coins"] -= price
	if item.has("give"):
		for k in item["give"]:
			player.inv[k] = player.inv.get(k, 0) + item["give"][k]
	else:
		player.give_weapon(id)
	player.inventory_changed.emit()
	Audio.play("highscore", -6.0)
	_refresh()
