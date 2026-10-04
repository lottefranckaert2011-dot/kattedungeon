class_name Player
extends CharacterBody2D
## The survivor. Walks, swings an axe (zombies, trees, rocks, crates),
## shoots a pistol, searches houses, eats and builds.

signal hp_changed(hp, max_hp)
signal inventory_changed
signal died
signal message(text)
signal weapons_changed

const SPEED := 72.0
const MAX_HP := 100.0
const FOOD_HEAL := 30.0

var world
var main
var hp := MAX_HP
var alive := true
var inv := {"wood": 6, "stone": 0, "scrap": 0, "ammo": 12, "food": 1, "coins": 0}
var melee := "axe"
var gun := "pistol"
var owned: Array = ["axe", "pistol"]
var aim := Vector2.DOWN
var move_input := Vector2.ZERO
var touch_mode := false

var sprite: Sprite2D
var axe: Sprite2D
var pistol: Sprite2D
var slash: Sprite2D
var light: PointLight2D
var _dir := 0
var _anim := 0.0
var _axe_cd := 0.0
var _gun_cd := 0.0
var _invuln := 0.0
var _step := 0.0
var _swing_t := 0.0
var _gun_show := 0.0
var _chop_tick := 0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var sh := Sprite2D.new()
	sh.texture = Res.SHADOW
	sh.z_index = -1
	add_child(sh)
	sprite = Sprite2D.new()
	sprite.texture = Res.PLAYER
	sprite.hframes = 6
	sprite.vframes = 3
	sprite.offset = Vector2(0, -11)
	add_child(sprite)

	axe = Sprite2D.new()
	axe.texture = Res.weapon_icon(melee)
	axe.offset = Vector2(5, -5)
	axe.position = Vector2(0, -9)
	axe.visible = false
	add_child(axe)
	pistol = Sprite2D.new()
	pistol.texture = Res.weapon_icon(gun)
	pistol.offset = Vector2(7, 0)
	pistol.position = Vector2(0, -8)
	pistol.visible = false
	add_child(pistol)
	slash = Sprite2D.new()
	slash.texture = Res.SLASH
	slash.hframes = 3
	slash.visible = false
	slash.position = Vector2(0, -8)
	add_child(slash)

	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 4.0
	cs.shape = shape
	cs.position = Vector2(0, -2)
	add_child(cs)

	light = PointLight2D.new()
	light.texture = Lights.radial(160)
	light.energy = 0.0
	light.color = Color(1.0, 0.92, 0.75)
	light.position = Vector2(0, -8)
	add_child(light)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	_axe_cd -= delta
	_gun_cd -= delta
	_invuln -= delta
	_gun_show -= delta
	pistol.visible = _gun_show > 0.0

	var input := move_input
	if not touch_mode or input == Vector2.ZERO:
		var k := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if k != Vector2.ZERO:
			input = k
	velocity = input * SPEED
	move_and_slide()

	if touch_mode:
		if input != Vector2.ZERO:
			aim = input.normalized()
	else:
		var m := get_global_mouse_position() - (global_position + Vector2(0, -8))
		if m.length() > 2.0:
			aim = m.normalized()

	var face := aim
	if input != Vector2.ZERO and (touch_mode or _swing_t <= 0.0):
		face = input
	_face(face)
	if input != Vector2.ZERO:
		_anim += delta * 9.0
		sprite.frame = _dir * 6 + int(_anim) % 4
		_step -= delta
		if _step <= 0.0:
			_step = 0.32
			Audio.play("step", -16.0, 0.15)
	else:
		_anim = 0.0
		sprite.frame = _dir * 6

	if _swing_t > 0.0:
		_swing_t -= delta
		var t := 1.0 - _swing_t / 0.22
		if melee == "chainsaw":
			axe.rotation = aim.angle() + randf_range(-0.08, 0.08)
			axe.flip_v = aim.x < 0
		else:
			axe.flip_v = false
			axe.rotation = aim.angle() + lerpf(-1.9, 1.3, t) * (1.0 if aim.x >= 0 else -1.0)
		slash.frame = clampi(int(t * 3.0), 0, 2)
		if _swing_t <= 0.0:
			axe.visible = false
			slash.visible = false
	if _gun_show > 0.0:
		pistol.rotation = aim.angle()
		pistol.flip_v = aim.x < 0

	if _invuln > 0.0:
		sprite.modulate.a = 0.5 if int(_invuln * 20.0) % 2 == 0 else 1.0
	else:
		sprite.modulate.a = 1.0


func _face(v: Vector2) -> void:
	if v == Vector2.ZERO:
		return
	if abs(v.x) > abs(v.y):
		_dir = 2
		sprite.flip_h = v.x < 0
	else:
		_dir = 0 if v.y > 0 else 1


## Auto-aim for touch controls: nearest zombie within range.
func auto_aim(max_range: float) -> void:
	var best := max_range
	for z in world.zombies:
		if z.dead:
			continue
		var d: float = z.global_position.distance_to(global_position)
		if d < best:
			best = d
			aim = (z.global_position - global_position).normalized()


func attack() -> void:
	if not alive or _axe_cd > 0.0:
		return
	if touch_mode:
		auto_aim(48.0)
	var w: Dictionary = Res.WEAPONS[melee]
	var dmg: float = w["damage"]
	var reach: float = w["range"]
	_axe_cd = w["cooldown"]
	_swing_t = minf(0.22, maxf(0.12, w["cooldown"] * 1.5))
	axe.visible = true
	slash.visible = true
	slash.rotation = aim.angle()
	slash.flip_v = aim.x < 0
	slash.position = Vector2(0, -8) + aim * 8.0
	Audio.play("swing", -6.0 if melee != "chainsaw" else -12.0, 0.15)
	var origin := global_position + Vector2(0, -6)
	var hit_any := false
	for z in world.zombies:
		if z.dead:
			continue
		var to: Vector2 = (z.global_position + Vector2(0, -6)) - origin
		if to.length() < reach + z.radius and (to.length() < 8.0 or abs(aim.angle_to(to)) < 1.25):
			z.take_damage(dmg, aim * float(w["knock"]), true)
			hit_any = true
	if hit_any:
		Audio.play("hit", -2.0, 0.12)
		main.shake(1.5)
		return
	# No zombie hit: chop the closest prop in front of us.
	var best = null
	var bd := reach + 4.0
	for e in world.entities.get_children():
		if e is Prop and e.can_harvest():
			var to2: Vector2 = e.hit_point() - origin
			var d := to2.length()
			if d < bd and (d < 10.0 or abs(aim.angle_to(to2)) < 1.1):
				bd = d
				best = e
	if best:
		if melee == "chainsaw":
			# the chainsaw hits very often: only every third tick chops
			_chop_tick += 1
			if _chop_tick % 3 != 0:
				return
		best.harvest_hit(int(w["chop"]))


func shoot() -> void:
	if not alive or _gun_cd > 0.0:
		return
	var w: Dictionary = Res.WEAPONS[gun]
	_gun_cd = w["cooldown"]
	if inv["ammo"] <= 0:
		Audio.play("empty", -4.0)
		message.emit(Lang.t("no_ammo"))
		_gun_cd = 0.5
		return
	if touch_mode:
		auto_aim(170.0)
	inv["ammo"] -= 1
	inventory_changed.emit()
	_gun_show = 0.4
	var start := global_position + Vector2(0, -8) + aim * 11.0
	var pellets: int = w["pellets"]
	var spread: float = w["spread"]
	for i in pellets:
		var a := randf_range(-spread, spread)
		if pellets > 1:
			a = lerpf(-spread, spread, float(i) / (pellets - 1)) + randf_range(-0.05, 0.05)
		Bullet.fire(world, start, aim.rotated(a), w["damage"])
	Fx.burst(world, start, Color(1.0, 0.9, 0.5), 4, 30.0)
	match gun:
		"shotgun":
			Audio.play("shot", 0.0, 0.05)
			Audio.play("barricade_hit", -10.0, 0.1)
			main.shake(2.5)
			velocity -= aim * 80.0
		"smg":
			Audio.play("turret_shot", -6.0, 0.12)
			main.shake(0.6)
		_:
			Audio.play("shot", -5.0, 0.08)
			main.shake(1.0)


## Next owned gun (Tab / mouse wheel / touch swap button).
func switch_gun() -> void:
	var guns: Array = []
	for id in owned:
		if not Res.WEAPONS[id]["melee"]:
			guns.append(id)
	if guns.size() < 2:
		return
	equip(guns[(guns.find(gun) + 1) % guns.size()])
	message.emit("%s: %s" % [Lang.t("swapped"), Lang.t("w_" + gun)])


func give_weapon(id: String) -> void:
	if not id in owned:
		owned.append(id)
	equip(id)


func equip(id: String) -> void:
	if Res.WEAPONS[id]["melee"]:
		melee = id
		axe.texture = Res.weapon_icon(id)
	else:
		gun = id
		pistol.texture = Res.weapon_icon(id)
		_gun_show = 0.6
	Audio.play("reload", -6.0)
	weapons_changed.emit()


func gun_count() -> int:
	var n := 0
	for id in owned:
		if not Res.WEAPONS[id]["melee"]:
			n += 1
	return n


func eat() -> void:
	if not alive:
		return
	if inv["food"] <= 0:
		message.emit(Lang.t("no_food"))
		Audio.play("error", -8.0)
		return
	if hp >= MAX_HP:
		message.emit(Lang.t("full_hp"))
		return
	inv["food"] -= 1
	inventory_changed.emit()
	heal(FOOD_HEAL, true)
	Audio.play("eat", -4.0)


func max_hp_value() -> float:
	return MAX_HP


func heal(amount: float, show := true) -> void:
	if not alive or hp >= MAX_HP:
		return
	hp = minf(MAX_HP, hp + amount)
	hp_changed.emit(hp, MAX_HP)
	if show:
		Fx.text(world, global_position + Vector2(0, -16), "+%d" % int(amount), Color(0.5, 1.0, 0.5))


func take_damage(amount: float, dir: Vector2) -> void:
	if not alive or _invuln > 0.0:
		return
	hp -= amount
	_invuln = 0.45
	velocity = dir * 60.0
	hp_changed.emit(hp, MAX_HP)
	Audio.play("hurt", -2.0, 0.1)
	world.add_splat(global_position + Vector2(0, -2))
	Fx.burst(world, global_position + Vector2(0, -8), Color(0.7, 0.1, 0.12), 6, 40.0)
	main.shake(3.0)
	main.hurt_flash()
	if hp <= 0.0:
		hp = 0.0
		alive = false
		sprite.modulate = Color(1, 1, 1, 1)
		var tw := create_tween()
		tw.tween_property(sprite, "rotation", PI / 2, 0.3)
		tw.parallel().tween_property(sprite, "position:y", 5.0, 0.3)
		died.emit()


func add_item(kind: String, amount: int, at: Vector2) -> void:
	inv[kind] = inv.get(kind, 0) + amount
	inventory_changed.emit()
	Audio.play("scrap" if kind == "scrap" or kind == "coins" else "pickup", -9.0, 0.15)
	Fx.text(world, at + Vector2(0, -6), "+%d %s" % [amount, Lang.t(kind)], Color(1.0, 0.95, 0.75))


func has_cost(cost: Dictionary) -> bool:
	for k in cost:
		if inv.get(k, 0) < cost[k]:
			return false
	return true


func pay(cost: Dictionary) -> void:
	for k in cost:
		inv[k] -= cost[k]
	inventory_changed.emit()


## Cell in front of the player (used for touch building).
func front_cell() -> Vector2i:
	var c: Vector2i = world.to_cell(global_position + Vector2(0, -4))
	var d := aim
	if abs(d.x) > abs(d.y):
		c.x += 1 if d.x > 0 else -1
	else:
		c.y += 1 if d.y > 0 else -1
	return c
