class_name UITheme
## Builds the pixel-art UI theme (Kenney Pixel font + wooden buttons).

const FONT_PATH := "res://assets/fonts/kenney_pixel.ttf"
const TITLE_FONT_PATH := "res://assets/fonts/kenney_blocks.ttf"

static var _font: FontFile
static var _title_font: FontFile

static func font() -> FontFile:
	if _font == null:
		_font = _load_pixel_font(FONT_PATH)
	return _font

static func title_font() -> FontFile:
	if _title_font == null:
		_title_font = _load_pixel_font(TITLE_FONT_PATH)
	return _title_font

static func _load_pixel_font(path: String) -> FontFile:
	var f: FontFile = load(path)
	f = f.duplicate()
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.generate_mipmaps = false
	return f

static func box(path: String, margin: int, content := 4) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(path)
	sb.texture_margin_left = margin
	sb.texture_margin_right = margin
	sb.texture_margin_top = margin
	sb.texture_margin_bottom = margin
	sb.content_margin_left = content + 2
	sb.content_margin_right = content + 2
	sb.content_margin_top = content - 1
	sb.content_margin_bottom = content
	return sb

static func build() -> Theme:
	var th := Theme.new()
	th.default_font = font()
	th.default_font_size = 16
	th.set_color("font_color", "Label", Color(1, 0.97, 0.9))
	th.set_color("font_outline_color", "Label", Color(0.12, 0.08, 0.1))
	th.set_constant("outline_size", "Label", 4)
	th.set_constant("line_spacing", "Label", -2)

	var normal := box("res://assets/sprites/panel.png", 6)
	var hover := normal.duplicate()
	hover.modulate_color = Color(1.15, 1.12, 1.0)
	var pressed := normal.duplicate()
	pressed.modulate_color = Color(0.8, 0.75, 0.7)
	th.set_stylebox("normal", "Button", normal)
	th.set_stylebox("hover", "Button", hover)
	th.set_stylebox("pressed", "Button", pressed)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_stylebox("disabled", "Button", pressed)
	th.set_color("font_color", "Button", Color(0.25, 0.14, 0.08))
	th.set_color("font_hover_color", "Button", Color(0.15, 0.08, 0.04))
	th.set_color("font_pressed_color", "Button", Color(0.15, 0.08, 0.04))
	th.set_color("font_focus_color", "Button", Color(0.25, 0.14, 0.08))
	th.set_stylebox("panel", "PanelContainer", box("res://assets/sprites/panel_dark.png", 6, 6))
	th.set_stylebox("panel", "Panel", box("res://assets/sprites/panel_dark.png", 6, 6))
	return th

static func label(text: String, size := 16, color := Color(1, 0.97, 0.9)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func button(text: String, min_w := 110) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 20)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): Audio.play("click", -6.0, 0.05))
	return b
