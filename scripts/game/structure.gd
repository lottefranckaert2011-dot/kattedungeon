class_name Structure
extends StaticBody2D
## Something the player built: barricade, stone wall, spike trap, turret or campfire.

var world
var kind := ""
var cell := Vector2i.ZERO
var hp := 1.0
var max_hp := 1.0
var blocks := true
var ammo := 0
var sprite: Sprite2D
var gun: Sprite2D
var light: PointLight2D
var _timer := 0.0
var _flash := 0.0
var _anim := 0.0
var _dead := false

const TURRET_RANGE := 120.0
const TURRET_RATE := 0.55
const TURRET_MAX_AMMO := 40
const SPIKE_RATE := 0.45
const SPIKE_DAMAGE := 9.0
const FIRE_HEAL := 3.0

func setup(w, k: String, c: Vector2i) -> void:
	world = w
	kind = k
	cell = c
	var info: Dictionary = Res.BUILD[k]
	max_hp = info["hp"]
	hp = max_hp
	blocks = info["blocks"]
	collision_layer = 1 if blocks else 0
	collision_mask = 0
	position = world.cell_center(c) + Vector2(0, 6)
	if not blocks:
		z_index = 0

	if k != "spikes":
		var sh := Sprite2D.new()
		sh.texture = Res.SHADOW
		sh.z_index = -1
		sh.position = Vector2(0, 1)
		add_child(sh)
	sprite = Sprite2D.new()
	sprite.texture = Res.STRUCT_TEX[k]
	sprite.centered = false
	var tex_w := 16
	var tex_h: int = sprite.texture.get_height()
	if k == "campfire":
		sprite.hframes = 3
	sprite.offset = Vector2(-tex_w / 2.0, -tex_h + 2)
	add_child(sprite)
	if k == "spikes":
		# Spikes lie flat on the ground: draw them below walkers.
		z_index = -3

	if blocks:
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = Vector2(16, 10)
		cs.shape = rs
		cs.position = Vector2(0, -4)
		add_child(cs)

	if k == "turret":
		ammo = TURRET_MAX_AMMO
		gun = Sprite2D.new()
		gun.texture = Res.TURRET_GUN
		gun.position = Vector2(0, -12)
		gun.offset = Vector2(3, 0)
		add_child(gun)
	if k == "campfire":
		light = PointLight2D.new()
		light.texture = Lights.radial(96)
		light.color = Color(1.0, 0.7, 0.4)
		light.energy = 1.2
		light.position = Vector2(0, -6)
		add_child(light)

	sprite.scale = Vector2(1.3, 0.6)
	var tw := create_tween()
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if _dead:
		return
	_timer -= delta
	_anim += delta
	if _flash > 0.0:
		_flash -= delta
		sprite.modulate = Color(2.0, 1.4, 1.4) if _flash > 0.0 else Color.WHITE
	match kind:
		"turret":
			_turret(delta)
		"spikes":
			_spikes()
		"campfire":
			sprite.frame = int(_anim * 8.0) % 3
			light.energy = 1.1 + sin(_anim * 13.0) * 0.08 + sin(_anim * 7.0) * 0.06
			if _timer <= 0.0:
				_timer = 1.0
				var p = world.player
				if p and p.alive and p.global_position.distance_to(global_position) < 40.0:
					p.heal(FIRE_HEAL, false)
	queue_redraw()


func _turret(_delta: float) -> void:
	if ammo <= 0:
		return
	var target = null
	var best := TURRET_RANGE
	for z in world.zombies:
		if z.dead:
			continue
		var d: float = z.global_position.distance_to(global_position)
		if d < best:
			best = d
			target = z
	if target == null:
		return
	var aim: Vector2 = (target.global_position + Vector2(0, -8)) - (global_position + gun.position)
	gun.rotation = aim.angle()
	gun.flip_v = abs(gun.rotation) > PI / 2
	if _timer <= 0.0:
		_timer = TURRET_RATE
		ammo -= 1
		Bullet.fire(world, global_position + gun.position + aim.normalized() * 8.0, aim.normalized(), 12.0, false)
		Audio.play("turret_shot", -9.0, 0.1, global_position)


func _spikes() -> void:
	if _timer > 0.0:
		return
	var hit := false
	for z in world.zombies:
		if z.dead:
			continue
		if z.global_position.distance_to(global_position + Vector2(0, -4)) < 11.0:
			z.take_damage(SPIKE_DAMAGE, Vector2.ZERO, false)
			hit = true
	if hit:
		_timer = SPIKE_RATE
		Audio.play("spike", -8.0, 0.15, global_position)
		damage(4.0, true)


func refill(amount: int) -> int:
	var used := mini(amount, TURRET_MAX_AMMO - ammo)
	ammo += used
	return used


func damage(amount: float, silent := false) -> void:
	if _dead:
		return
	hp -= amount
	_flash = 0.12
	if not silent:
		Audio.play("barricade_hit", -4.0, 0.15, global_position)
	if hp <= 0.0:
		_destroy()


func _destroy() -> void:
	_dead = true
	world.remove_structure(self)
	collision_layer = 0
	Audio.play("break", -2.0, 0.1, global_position)
	Fx.burst(world, global_position + Vector2(0, -6), Color(0.6, 0.42, 0.25), 10)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)


func _draw() -> void:
	if hp < max_hp and not _dead:
		var w := 14.0
		var y := -float(sprite.texture.get_height()) - 1.0
		draw_rect(Rect2(-w / 2 - 1, y - 1, w + 2, 4), Color(0.1, 0.08, 0.1))
		draw_rect(Rect2(-w / 2, y, w * hp / max_hp, 2), Color(0.95, 0.75, 0.3))
	if kind == "turret" and not _dead:
		var y2 := -24.0
		var frac := float(ammo) / TURRET_MAX_AMMO
		draw_rect(Rect2(-7, y2, 14, 2), Color(0.1, 0.08, 0.1, 0.8))
		draw_rect(Rect2(-7, y2, 14 * frac, 2), Color(1.0, 0.85, 0.4) if ammo > 0 else Color(0.8, 0.2, 0.2))
