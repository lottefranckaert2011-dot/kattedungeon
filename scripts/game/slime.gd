class_name Slime
extends Node2D
## A blob of green slime lobbed by a spitter zombie. It flies in an arc
## (over barricades!) and splashes where the target was standing.

const FLIGHT_TIME := 0.85
const ARC_HEIGHT := 34.0
const SPLASH_RADIUS := 14.0

var world
var start := Vector2.ZERO
var target := Vector2.ZERO
var damage := 9.0
var _t := 0.0
var _blob: Sprite2D
var _shadow: Sprite2D

static func lob(w, from: Vector2, to: Vector2, dmg: float) -> void:
	var s := Slime.new()
	s.world = w
	s.start = from
	# a little inaccurate, so you can dodge by moving
	s.target = to + Vector2(randf_range(-8, 8), randf_range(-6, 6))
	s.damage = dmg
	w.add_child(s)

func _ready() -> void:
	z_index = 25
	_shadow = Sprite2D.new()
	_shadow.texture = Res.SHADOW
	_shadow.scale = Vector2(0.6, 0.6)
	_shadow.z_index = -24
	add_child(_shadow)
	_blob = Sprite2D.new()
	_blob.texture = Res.SLIME
	add_child(_blob)

func _process(delta: float) -> void:
	_t += delta / FLIGHT_TIME
	var ground := start.lerp(target, clampf(_t, 0.0, 1.0))
	var height := sin(clampf(_t, 0.0, 1.0) * PI) * ARC_HEIGHT
	position = ground
	_shadow.position = Vector2(0, 0)
	_blob.position = Vector2(0, -height)
	_blob.rotation += delta * 8.0
	if _t >= 1.0:
		_splash()

func _splash() -> void:
	Audio.play("splat", -3.0, 0.15, target)
	Fx.burst(world, target, Color(0.45, 0.85, 0.3), 10, 50.0)
	var puddle := Sprite2D.new()
	puddle.texture = Res.PUDDLE
	puddle.position = target
	world.decals.add_child(puddle)
	var tw := puddle.create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(puddle, "modulate:a", 0.0, 1.5)
	tw.tween_callback(puddle.queue_free)
	var people: Array = [world.player]
	people.append_array(world.allies)
	for p in people:
		if p == null or not p.alive:
			continue
		if p.global_position.distance_to(target) < SPLASH_RADIUS:
			p.take_damage(damage, (p.global_position - target).normalized())
			if p.has_method("slow_down"):
				p.slow_down(1.4)
	for c in world.structures.keys():
		var st = world.structures.get(c)
		if st and st.global_position.distance_to(target) < SPLASH_RADIUS:
			st.damage(damage, true)
	queue_free()
