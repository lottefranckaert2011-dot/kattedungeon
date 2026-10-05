class_name Weather
extends CanvasLayer
## Night weather: rain (with lightning) or thick fog. Both limit how far you can see
## with a dark/foggy ring around the player, drawn on top of the world but below the HUD.

var mode := "clear"
var _vignette: TextureRect
var _grad: Gradient
var _rain: CPUParticles2D
var _flash: ColorRect
var _puffs: Array[Sprite2D] = []
var _strength := 0.0          # 0 = clear, 1 = full weather
var _target := 0.0
var _thunder_t := 8.0
var _t := 0.0


func _ready() -> void:
	layer = 5
	_grad = Gradient.new()
	var tex := GradientTexture2D.new()
	tex.gradient = _grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 72
	_vignette = TextureRect.new()
	_vignette.texture = tex
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vignette)

	# fog puffs drifting across the screen
	for i in 7:
		var p := Sprite2D.new()
		p.texture = Lights.radial(128)
		p.scale = Vector2(2.2, 1.3) * randf_range(0.8, 1.3)
		p.position = Vector2(randf_range(0, 480), randf_range(0, 270))
		p.modulate = Color(0.8, 0.84, 0.9, 0.0)
		add_child(p)
		_puffs.append(p)

	var drop := Image.create(1, 6, false, Image.FORMAT_RGBA8)
	for y in 6:
		drop.set_pixel(0, y, Color(0.75, 0.85, 1.0, 0.25 + y * 0.12))
	_rain = CPUParticles2D.new()
	_rain.texture = ImageTexture.create_from_image(drop)
	_rain.amount = 160
	_rain.lifetime = 0.7
	_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain.emission_rect_extents = Vector2(300, 10)
	_rain.position = Vector2(240, -20)
	_rain.direction = Vector2(-0.25, 1.0)
	_rain.spread = 3.0
	_rain.gravity = Vector2.ZERO
	_rain.initial_velocity_min = 380.0
	_rain.initial_velocity_max = 460.0
	_rain.emitting = false
	add_child(_rain)

	_flash = ColorRect.new()
	_flash.color = Color(0.9, 0.95, 1.0, 0.0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_apply()


## "clear", "rain" or "fog".
func set_mode(m: String) -> void:
	mode = m if m != "clear" else mode
	_target = 0.0 if m == "clear" else 1.0
	if m == "rain":
		_rain.emitting = true
		Audio.play_ambience("rain", -6.0)
		_thunder_t = randf_range(4.0, 9.0)
	elif m == "fog":
		_rain.emitting = false
		Audio.play_ambience("wind", -10.0)
	else:
		_rain.emitting = false
		Audio.play_ambience("")


func _process(delta: float) -> void:
	_t += delta
	_strength = move_toward(_strength, _target, delta * 0.5)
	var vp := get_viewport().get_visible_rect().size
	_rain.position = Vector2(vp.x / 2.0 + 40.0, -20)
	_rain.emission_rect_extents = Vector2(vp.x / 2.0 + 60.0, 10)
	for p in _puffs:
		p.position.x += delta * (6.0 + p.scale.x * 2.0)
		p.position.y += sin(_t * 0.3 + p.scale.y) * delta * 3.0
		if p.position.x > vp.x + 120.0:
			p.position = Vector2(-120.0, randf_range(0, vp.y))
		var a := 0.32 * _strength if mode == "fog" else 0.0
		p.modulate.a = a
	if mode == "rain" and _target > 0.0:
		_thunder_t -= delta
		if _thunder_t <= 0.0:
			_thunder_t = randf_range(7.0, 14.0)
			_lightning()
	_apply()


func _lightning() -> void:
	var tw := create_tween()
	_flash.color.a = 0.55
	tw.tween_property(_flash, "color:a", 0.0, 0.12)
	tw.tween_property(_flash, "color:a", 0.35, 0.05)
	tw.tween_property(_flash, "color:a", 0.0, 0.25)
	get_tree().create_timer(randf_range(0.3, 0.9)).timeout.connect(func(): Audio.play("thunder", -2.0, 0.1))


func _apply() -> void:
	# Clear centre around the player, weather colour towards the edges.
	var s := _strength
	var col: Color
	var inner: float
	if mode == "fog":
		col = Color(0.62, 0.66, 0.72)
		inner = 0.16
	else:
		col = Color(0.03, 0.04, 0.1)
		inner = 0.3
	_grad.offsets = PackedFloat32Array([0.0, inner, 0.75, 1.0])
	_grad.colors = PackedColorArray([
		Color(col, 0.0), Color(col, 0.0), Color(col, 0.88 * s), Color(col, 0.97 * s)])
	visible = s > 0.001
