class_name Zombie
extends CharacterBody2D
## A shambling villager. Follows an A* path to the player and breaks
## through barricades that stand in the way.

signal died(zombie)

var world
var type := "walker"
var hp := 30.0
var max_hp := 30.0
var speed := 24.0
var damage := 8.0
var struct_damage := 8.0
var score := 10
var radius := 6.0
var dead := false

var sprite: Sprite2D
var _frame_w := 16
var _dir := 0              # 0 down, 1 up, 2 side
var _anim := 0.0
var _path := PackedVector2Array()
var _path_i := 0
var _repath := 0.0
var _attack_cd := 0.0
var _attack_anim := 0.0
var _knock := Vector2.ZERO
var _flash := 0.0
var _groan := 0.0
var _stuck := 0.0
var _target_struct: Structure = null
var _fuse := -1.0           # bloater: seconds until it explodes
var _exploded := false

const EXPLODE_RADIUS := 44.0
const SPIT_RANGE := 100.0


func setup(w, t: String, night: int) -> void:
	world = w
	type = t
	var info: Dictionary = Res.ZOMBIE_TYPES[t]
	var scale_hp := 1.0 + 0.1 * (night - 1)
	max_hp = info["hp"] * scale_hp
	hp = max_hp
	speed = info["speed"] * randf_range(0.9, 1.12) * (1.0 + 0.02 * mini(night, 10))
	damage = info["damage"]
	struct_damage = info["struct_damage"]
	score = info["score"]
	collision_layer = 4
	collision_mask = 1 | 8   # world + gates (gates only stop zombies)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	var skin: String = Res.ZOMBIE_SKIN.get(t, "")
	if skin == "":
		skin = Res.WALKER_SKINS.pick_random()
	var tex: Texture2D = Res.ZOMBIE_TEX[skin]
	_frame_w = tex.get_width() / 6
	var sh := Sprite2D.new()
	sh.texture = Res.SHADOW
	sh.z_index = -1
	if t == "brute" or t == "bloater":
		sh.scale = Vector2(1.5, 1.3)
		radius = 8.0 if t == "brute" else 9.0
	elif t == "dog":
		sh.scale = Vector2(1.1, 0.9)
		radius = 5.0
	add_child(sh)
	sprite = Sprite2D.new()
	sprite.texture = tex
	sprite.hframes = 6
	sprite.vframes = 3
	sprite.offset = Vector2(0, -tex.get_height() / 6.0 + 1)
	add_child(sprite)

	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 5.0 if t == "brute" or t == "bloater" else 4.0
	cs.shape = shape
	cs.position = Vector2(0, -2)
	add_child(cs)
	_repath = randf() * 0.4
	_groan = randf_range(1.0, 6.0)


func _physics_process(delta: float) -> void:
	if dead:
		return
	_attack_cd -= delta
	_repath -= delta
	_groan -= delta
	_attack_anim = maxf(0.0, _attack_anim - delta)
	if _flash > 0.0:
		_flash -= delta
		sprite.modulate = Color(3.0, 3.0, 3.0) if _flash > 0.0 else Color.WHITE

	if _fuse >= 0.0:
		_fuse -= delta
		sprite.modulate = Color(2.0, 3.0, 1.2) if int(_fuse * 14.0) % 2 == 0 else Color.WHITE
		sprite.scale = Vector2.ONE * (1.0 + (0.8 - _fuse) * 0.3)
		velocity = _knock
		move_and_slide()
		_knock = _knock.move_toward(Vector2.ZERO, 500.0 * delta)
		if _fuse <= 0.0:
			_explode()
		return

	if _groan <= 0.0:
		_groan = randf_range(4.0, 10.0)
		if type == "dog":
			Audio.play("groan", -12.0, 0.1, global_position, 1.7)
		else:
			Audio.play("groan", -10.0, 0.15, global_position)

	# Attack whoever is closest: the player or one of the survivors helping them.
	var player = _pick_target()
	var desired := Vector2.ZERO
	var reach := 12.0 + radius
	if player and player.alive:
		var to_p: Vector2 = player.global_position - global_position
		var dist := to_p.length()
		if dist < reach and type != "spitter":
			_face(to_p)
			if type == "bloater":
				_start_fuse()
			elif _attack_cd <= 0.0:
				_attack_cd = {"runner": 0.8, "dog": 0.6}.get(type, 1.0)
				_attack_anim = 0.35
				player.take_damage(damage, to_p.normalized())
				Audio.play("zattack", -4.0, 0.12, global_position, 1.5 if type == "dog" else 1.0)
		elif type == "spitter" and dist < SPIT_RANGE:
			# Keep some distance and lob slime (it flies over barricades!).
			_face(to_p)
			desired = -to_p.normalized() if dist < 48.0 else Vector2.ZERO
			if _attack_cd <= 0.0:
				_attack_cd = randf_range(2.2, 2.8)
				_attack_anim = 0.35
				Slime.lob(world, global_position + Vector2(0, -14), player.global_position, damage)
				Audio.play("spit", -4.0, 0.1, global_position)
		else:
			if _repath <= 0.0:
				_repath = randf_range(0.45, 0.75)
				_path = world.find_path(global_position, player.global_position)
				_path_i = 0
			_target_struct = null
			if dist < 26.0 or _path.is_empty():
				desired = to_p.normalized()
			else:
				while _path_i < _path.size() - 1 and global_position.distance_to(_path[_path_i]) < 5.0:
					_path_i += 1
				var nxt: Vector2 = _path[_path_i]
				var s = world.structures.get(world.to_cell(nxt))
				if s != null and s.blocks:
					_target_struct = s
				desired = (nxt - global_position).normalized()
			if _target_struct == null and _stuck > 0.5:
				_target_struct = _nearest_blocking_structure()
			if _target_struct != null and is_instance_valid(_target_struct) \
					and global_position.distance_to(_target_struct.global_position) < 18.0 + radius:
				desired = Vector2.ZERO
				_face(_target_struct.global_position - global_position)
				if type == "bloater":
					_start_fuse()
				elif _attack_cd <= 0.0:
					_attack_cd = 1.0
					_attack_anim = 0.35
					_target_struct.damage(struct_damage)
					if randf() < 0.3:
						Audio.play("zattack", -8.0, 0.12, global_position)

	var sep := Vector2.ZERO
	for z in world.zombies:
		if z == self or z.dead:
			continue
		var d: Vector2 = global_position - z.global_position
		var l := d.length()
		if l < 10.0 and l > 0.01:
			sep += d / l * (10.0 - l) * 6.0
	velocity = desired * speed + sep + _knock
	var before := global_position
	move_and_slide()
	_knock = _knock.move_toward(Vector2.ZERO, 500.0 * delta)
	var moved := global_position.distance_to(before)
	if desired != Vector2.ZERO and moved < speed * delta * 0.25:
		_stuck += delta
	else:
		_stuck = maxf(0.0, _stuck - delta)
	if desired != Vector2.ZERO:
		_face(desired)
	_animate(delta, desired != Vector2.ZERO)


func _pick_target():
	var best = world.player
	var bd := INF
	if best and best.alive:
		bd = best.global_position.distance_to(global_position)
	else:
		best = null
	for a in world.allies:
		if a.joined and a.alive:
			# survivors only draw attention when they are clearly closer
			var d: float = a.global_position.distance_to(global_position) + 12.0
			if d < bd:
				bd = d
				best = a
	return best


func _nearest_blocking_structure() -> Structure:
	var best: Structure = null
	var bd := 24.0
	for c in world.structures:
		var s: Structure = world.structures[c]
		if not s.blocks:
			continue
		var d := global_position.distance_to(s.global_position)
		if d < bd:
			bd = d
			best = s
	return best


func _face(v: Vector2) -> void:
	if abs(v.x) > abs(v.y) * 1.1:
		_dir = 2
		sprite.flip_h = v.x < 0
	else:
		_dir = 0 if v.y > 0 else 1


func _animate(delta: float, moving: bool) -> void:
	var col := 0
	if _attack_anim > 0.0:
		col = 4 if _attack_anim > 0.17 else 5
	elif moving:
		_anim += delta * speed / 7.0
		col = int(_anim) % 4
	sprite.frame = _dir * 6 + col


func take_damage(amount: float, knock: Vector2, show_blood := true) -> void:
	if dead:
		return
	hp -= amount
	_flash = 0.08
	var k := 1.0 if type != "brute" else 0.3
	_knock += knock * k
	if show_blood:
		Fx.burst(world, global_position + Vector2(0, -8), Color(0.45, 0.62, 0.3), 5, 40.0)
	Fx.text(world, global_position + Vector2(0, -12), str(int(round(amount))), Color(1.0, 0.95, 0.6))
	if hp <= 0.0:
		_die()


func _start_fuse() -> void:
	if _fuse >= 0.0 or _exploded:
		return
	_fuse = 0.8
	Audio.play("groan", -2.0, 0.05, global_position, 1.5)


## The bloater bursts: hurts everything around it, smashes barricades.
func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	dead = true
	collision_layer = 0
	collision_mask = 0
	var center := global_position + Vector2(0, -6)
	Audio.play("boom", 0.0, 0.08, global_position)
	Fx.burst(world, center, Color(0.5, 0.85, 0.3), 30, 120.0)
	Fx.burst(world, center, Color(0.9, 0.95, 0.5), 12, 70.0)
	for i in 3:
		world.add_splat(global_position + Vector2(randf_range(-14, 14), randf_range(-8, 8)), true)
	if world.player and world.player.main:
		world.player.main.shake(5.0)
	for c in world.structures.keys():
		var st: Structure = world.structures.get(c)
		if st == null:
			continue
		var ds := st.global_position.distance_to(global_position)
		if ds < EXPLODE_RADIUS:
			st.damage(struct_damage * (1.0 - ds / EXPLODE_RADIUS * 0.5))
	var people: Array = [world.player]
	people.append_array(world.allies)
	for t in people:
		if t == null or not t.alive:
			continue
		var dp: float = t.global_position.distance_to(global_position)
		if dp < EXPLODE_RADIUS:
			t.take_damage(damage * (1.0 - dp / EXPLODE_RADIUS * 0.5), (t.global_position - global_position).normalized())
	for z in world.zombies.duplicate():
		if z == self or z.dead:
			continue
		var dz: float = z.global_position.distance_to(global_position)
		if dz < EXPLODE_RADIUS:
			z.take_damage.call_deferred(40.0, (z.global_position - global_position).normalized() * 180.0, false)
	_drop()
	died.emit(self)
	sprite.visible = false
	var tw := create_tween()
	tw.tween_interval(0.2)
	tw.tween_callback(queue_free)


func _die() -> void:
	if type == "bloater":
		_explode()
		return
	dead = true
	collision_layer = 0
	collision_mask = 0
	Audio.play("zdie", -2.0, 0.12, global_position)
	world.add_splat(global_position + Vector2(0, -2), true)
	_drop()
	died.emit(self)
	sprite.modulate = Color.WHITE
	var tw := create_tween()
	tw.tween_property(sprite, "rotation", PI / 2 * (1 if randf() < 0.5 else -1), 0.25)
	tw.parallel().tween_property(sprite, "position:y", 4.0, 0.25)
	tw.tween_interval(0.6)
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)


func _drop() -> void:
	var r := randf()
	# Coins for the weapon shop.
	var coins: int = {"walker": randi_range(1, 2), "runner": 3, "brute": 8, "dog": 1, "bloater": 4, "spitter": 3}[type]
	Pickup.spawn(world, "coins", coins, global_position)
	if type == "brute":
		Pickup.spawn(world, "scrap", 1, global_position)
		Pickup.spawn(world, "ammo", 4, global_position)
		if randf() < 0.5:
			Pickup.spawn(world, "food", 1, global_position)
		return
	if r < 0.3:
		Pickup.spawn(world, "ammo", randi_range(2, 3), global_position)
	elif r < 0.45:
		Pickup.spawn(world, "scrap", 1, global_position)
	elif r < 0.53:
		Pickup.spawn(world, "food", 1, global_position)
