class_name Fx
## Small visual effects: particle bursts and floating text.

static func burst(world, pos: Vector2, color: Color, amount := 8, speed := 50.0) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.emitting = false
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.45
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, 160)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = color
	world.entities.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)

static func text(world, pos: Vector2, msg: String, color := Color.WHITE) -> void:
	var l := Label.new()
	l.text = msg
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.1))
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_font_size_override("font_size", 16)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(120, 16)
	l.position = pos - Vector2(60, 24)
	l.z_index = 50
	world.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 14.0, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.5)
	tw.tween_callback(l.queue_free)
