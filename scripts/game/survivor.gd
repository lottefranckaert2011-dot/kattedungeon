class_name Survivor
extends CharacterBody2D
## A survivor you can find. Waits for help ("HELP!") until you press E,
## then follows you and helps: shooter, fighter, medic or builder.

signal downed_changed(survivor)

var world
var kind := "shooter"
var display_name := "Sam"
var hp := 80.0
var max_hp := 80.0
var speed := 70.0
var joined := false
var downed := false
var alive := true          # zombies only attack "alive" targets
var slot := 0              # position in the group around the player
var radius := 6.0

var sprite: Sprite2D
var weapon: Sprite2D
var bubble: Label
var _dir := 0
var _anim := 0.0
var _cd := 0.0
var _task_t := 0.0
var _path := PackedVector2Array()
var _path_i := 0
var _repath := 0.0
var _far_t := 0.0
var _flash := 0.0
var _bob := 0.0

const FORMATION := [Vector2(-18, 8), Vector2(18, 8), Vector2(-10, 20), Vector2(10, 20)]


func setup(w, k: String) -> void:
	world = w
	kind = k
	var info: Dictionary = Res.SURVIVORS[k]
	display_name = info["name"]
	max_hp = info["hp"]
	hp = max_hp
	speed = info["speed"]


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var sh := Sprite2D.new()
	sh.texture = Res.SHADOW
	sh.z_index = -1
	add_child(sh)
	sprite = Sprite2D.new()
	sprite.texture = Res.SURVIVORS[kind]["tex"]
	sprite.hframes = 6
	sprite.vframes = 3
	sprite.offset = Vector2(0, -11)
	add_child(sprite)
	weapon = Sprite2D.new()
	var wid: String = {"shooter": "pistol", "fighter": "bat", "medic": "", "builder": "axe"}[kind]
	if wid != "":
		weapon.texture = Res.weapon_icon(wid)
	weapon.position = Vector2(0, -8)
	weapon.offset = Vector2(6, 0)
	weapon.visible = false
	add_child(weapon)
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 3.5
	cs.shape = shape
	cs.position = Vector2(0, -2)
	add_child(cs)
	bubble = Label.new()
	bubble.text = Lang.t("help_me")
	bubble.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	bubble.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.1))
	bubble.add_theme_constant_override("outline_size", 4)
	bubble.add_theme_font_size_override("font_size", 16)
	bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.size = Vector2(60, 16)
	bubble.position = Vector2(-30, -40)
	bubble.z_index = 40
	add_child(bubble)
	bubble.visible = not joined


func join(index: int) -> void:
	joined = true
	slot = index
	bubble.visible = false
	Fx.burst(world, global_position + Vector2(0, -10), Color(1.0, 0.9, 0.4), 12, 50.0)


## Called when moving to another area: put next to the player.
func place_near(p: Vector2) -> void:
	position = p + FORMATION[slot % FORMATION.size()]
	velocity = Vector2.ZERO
	_path = PackedVector2Array()


func role_text() -> String:
	return Lang.t("role_" + kind)


func _physics_process(delta: float) -> void:
	_bob += delta
	if _flash > 0.0:
		_flash -= delta
		sprite.modulate = Color(2.5, 1.2, 1.2) if _flash > 0.0 else Color.WHITE
	if not joined:
		bubble.position.y = -40 + sin(_bob * 4.0) * 2.0
		sprite.frame = 0 if int(_bob * 1.2) % 4 != 3 else 12
		sprite.flip_h = int(_bob * 0.6) % 2 == 0
		return
	if downed:
		return
	_cd -= delta
	_task_t -= delta
	_repath -= delta
	var player = world.player
	if player == null:
		return

	var goal: Vector2 = player.global_position + FORMATION[slot % FORMATION.size()]
	var target = null
	match kind:
		"shooter":
			target = _nearest_zombie(global_position, 140.0)
			if target and _cd <= 0.0:
				_cd = 0.75
				var aim: Vector2 = ((target.global_position + Vector2(0, -7)) - (global_position + Vector2(0, -8))).normalized()
				Bullet.fire(world, global_position + Vector2(0, -8) + aim * 9.0, aim, 12.0, false)
				Audio.play("turret_shot", -12.0, 0.15, global_position)
				_show_weapon(aim)
		"fighter":
			target = _nearest_zombie(player.global_position, 110.0)
			if target:
				goal = target.global_position
				if global_position.distance_to(target.global_position) < 16.0 + target.radius and _cd <= 0.0:
					_cd = 0.6
					var dir: Vector2 = (target.global_position - global_position).normalized()
					target.take_damage(17.0, dir * 220.0, true)
					Audio.play("hit", -8.0, 0.15, global_position)
					_show_weapon(dir)
		"medic":
			if _task_t <= 0.0:
				_task_t = 1.0
				_heal_around()
		"builder":
			if _task_t <= 0.0:
				_task_t = 1.0
				_repair_around()

	_move_to(goal, delta, target != null and kind == "fighter")
	if weapon.visible and _cd < 0.3:
		weapon.visible = false


func _move_to(goal: Vector2, delta: float, chasing: bool) -> void:
	var player = world.player
	var to := goal - global_position
	var dist := to.length()
	var dir := Vector2.ZERO
	if dist > 8.0:
		if dist > 64.0:
			if _repath <= 0.0:
				_repath = 0.6
				_path = world.find_path(global_position, goal)
				_path_i = 0
			if _path_i < _path.size():
				while _path_i < _path.size() - 1 and global_position.distance_to(_path[_path_i]) < 5.0:
					_path_i += 1
				dir = (_path[_path_i] - global_position).normalized()
			else:
				dir = to.normalized()
		else:
			dir = to.normalized()
	var spd := speed * (1.25 if dist > 120.0 else 1.0)
	if chasing:
		spd *= 1.1
	velocity = dir * spd
	move_and_slide()
	# Got stuck far away: catch up with the player.
	if player and global_position.distance_to(player.global_position) > 260.0:
		_far_t += delta
		if _far_t > 3.0:
			_far_t = 0.0
			place_near(player.global_position)
	else:
		_far_t = 0.0
	if dir != Vector2.ZERO:
		_face(dir)
		_anim += delta * 9.0
		sprite.frame = _dir * 6 + int(_anim) % 4
	else:
		_anim = 0.0
		sprite.frame = _dir * 6


func _face(v: Vector2) -> void:
	if abs(v.x) > abs(v.y):
		_dir = 2
		sprite.flip_h = v.x < 0
	else:
		_dir = 0 if v.y > 0 else 1


func _show_weapon(dir: Vector2) -> void:
	if weapon.texture == null:
		return
	weapon.visible = true
	weapon.rotation = dir.angle()
	weapon.flip_v = dir.x < 0
	_face(dir)


func _nearest_zombie(from: Vector2, max_d: float):
	var best = null
	var bd := max_d
	for z in world.zombies:
		if z.dead:
			continue
		var d: float = z.global_position.distance_to(from)
		if d < bd:
			bd = d
			best = z
	return best


func _heal_around() -> void:
	var targets: Array = [world.player]
	targets.append_array(world.allies)
	for t in targets:
		if t == null or t == self or not t.alive:
			continue
		if t.global_position.distance_to(global_position) < 60.0 and t.hp < t.max_hp_value():
			t.heal(4.0, false)
			Fx.burst(world, t.global_position + Vector2(0, -14), Color(0.5, 1.0, 0.5), 3, 20.0)
	if hp < max_hp:
		heal(2.0, false)


func _repair_around() -> void:
	for c in world.structures:
		var s: Structure = world.structures[c]
		if s.hp < s.max_hp and s.global_position.distance_to(global_position) < 80.0:
			s.hp = minf(s.max_hp, s.hp + 8.0)
			Fx.burst(world, s.global_position + Vector2(0, -8), Color(0.9, 0.8, 0.5), 3, 20.0)
	# Now and then the builder chops some wood for you during the day.
	if not world.is_night and randf() < 0.04:
		Pickup.spawn(world, "wood", 1, global_position)
		Fx.text(world, global_position + Vector2(0, -20), "%s %s" % [display_name, Lang.t("chopped")], Color(0.9, 0.85, 0.6))


func max_hp_value() -> float:
	return max_hp


func heal(amount: float, _show := true) -> void:
	if downed:
		return
	hp = minf(max_hp, hp + amount)


func take_damage(amount: float, dir: Vector2) -> void:
	if downed or not joined:
		return
	hp -= amount
	_flash = 0.12
	velocity = dir * 50.0
	Fx.burst(world, global_position + Vector2(0, -8), Color(0.7, 0.1, 0.12), 4, 30.0)
	Audio.play("hurt", -8.0, 0.2, global_position)
	if hp <= 0.0:
		hp = 0.0
		downed = true
		alive = false
		weapon.visible = false
		sprite.rotation = PI / 2
		sprite.position.y = 5.0
		sprite.modulate = Color(0.7, 0.7, 0.7)
		downed_changed.emit(self)


## New morning: everybody gets back up.
func revive() -> void:
	if downed:
		downed = false
		alive = true
		hp = max_hp * 0.6
		sprite.rotation = 0.0
		sprite.position.y = 0.0
		sprite.modulate = Color.WHITE
		downed_changed.emit(self)
	else:
		hp = minf(max_hp, hp + max_hp * 0.5)
