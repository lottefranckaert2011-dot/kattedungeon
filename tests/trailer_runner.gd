extends Node
## Dev tool: plays a scripted ~17 s scene for the CrazyGames preview videos.
## Record with Godot's Movie Maker, see tools/make_videos.sh.
## Args (after --): "landscape" or "portrait", optional world seed.

const FPS := 30.0
const END := 17.0

var main
var portrait := false
var seed_value := 4242
var t := 0.0
var done := {}
var dir := Vector2i(1, 0)        # where the zombies come from
var side := Vector2i(0, 1)       # along the barricade line
var base := Vector2i.ZERO
var plan: Array = []             # [kind, cell] to build one by one
var spawns: Array = []           # [time, type, along-offset]
var _build_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 100   # after main.gd, so the camera tweak sticks
	var args := OS.get_cmdline_user_args()
	portrait = args.size() > 0 and args[0] == "portrait"
	if args.size() > 1:
		seed_value = int(args[1])
	if portrait:
		# same width as the real game (the HUD is made for 480), 2:3 like the video
		get_window().content_scale_size = Vector2i(480, 720)
		dir = Vector2i(0, 1)
		side = Vector2i(1, 0)
	Lang.lang = "en"
	Save.tutorial_done = true
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)


func once(key: String) -> bool:
	if done.has(key):
		return false
	done[key] = true
	return true


func _process(_delta: float) -> void:
	t += 1.0 / FPS
	var p = main.player
	if t > 0.05 and once("start"):
		_setup()
	if not done.has("start"):
		return
	# keep the hero (and team) standing: no blinking, no game over
	p.hp = Player.MAX_HP
	p.hunger = 100.0
	p._invuln = 0.09
	for a in main.allies:
		a.hp = a.max_hp

	# day: walk a little, then build the defence line
	if t < 1.0:
		_hold(Vector2(dir))
	elif once("stop_walk"):
		_hold(Vector2.ZERO)
		_make_plan()
		main.build_kind = "barricade"
	if t > 1.1 and not plan.is_empty():
		_build_t -= 1.0 / FPS
		if _build_t <= 0.0:
			_build_t = 0.22
			var step: Array = plan.pop_front()
			main.build_kind = step[0]
			if main._cell_ok(step[1]):
				main._try_build(step[1])
			if plan.is_empty():
				main.build_kind = ""
				main.ghost.visible = false
	_aim_at(base + dir * 6)

	# night falls
	if t > 4.4 and once("night"):
		main.force_weather = "clear"
		main.night_num = 2
		main.phase_time = main.phase_len - 0.01
	if done.has("night") and main.is_night:
		main.spawn_timer = 99.0
		if once("wave"):
			var n := 0
			for s in spawns:
				n += s[3]
			main.wave_total = n
	for s in spawns:
		if t >= s[0] and once("spawn%f" % s[0]):
			main.wave_spawned += s[3]
			for i in s[3]:
				var c: Vector2i = base + dir * (12 + i % 2) + side * (s[2] + i - s[3] / 2)
				main._spawn_zombie(s[1], c)

	# fight: shoot the nearest zombie
	if main.is_night and t < 15.2:
		var z = _nearest_zombie(150.0)
		if z:
			_aim_at_pos(z.global_position + Vector2(0, -6))
			p.shoot()

	# sunrise: the leftovers burn away
	if t > 15.2 and once("sunrise"):
		main.phase_time = main.night_len
	# keep the picture tidy: dropped loot fades quickly
	for n in main.world.entities.get_children():
		if n is Pickup and n._age > 1.0:
			n.modulate.a = 1.0 - (n._age - 1.0) / 0.5
			if n._age > 1.5:
				n.queue_free()
	# look a bit towards where the zombies come from
	var look := clampf((t - 1.0) / 2.0, 0.0, 1.0)
	main.camera.position = p.position + Vector2(0, -8) + Vector2(dir) * look * (40.0 if portrait else 70.0)
	# a little less dark than in the real game, so the video reads well on small cards
	if main.is_night:
		main.canvas_mod.color = main.canvas_mod.color.lerp(Color.WHITE, 0.2)
	if t > END and once("quit"):
		get_tree().quit()


func _setup() -> void:
	for t2 in ["dog", "bloater", "spitter", "brute"]:
		main._seen_types[t2] = true
	main._build_world(0, seed_value)
	main._start_game()
	main.hud.show_message("", 0.01)
	var p = main.player
	p.inv = {"wood": 80, "stone": 40, "scrap": 40, "ammo": 300, "food": 3, "coins": 40}
	p.give_weapon("shotgun")
	p.inventory_changed.emit()
	for k in ["shooter", "fighter"]:
		var sv := Survivor.new()
		sv.setup(main.world, k)
		main.world.entities.add_child(sv)
		main.allies.append(sv)
		sv.join(main.allies.size() - 1)
		sv.place_near(p.position)
		main.rescued_kinds.append(k)
	main.world.allies = main.allies
	# an open spot near home, so the whole wall fits and the fight is easy to see
	base = _find_spot()
	p.position = main.world.cell_center(base - dir * 4)
	for a in main.allies:
		a.place_near(p.position)
	main.camera.position = p.position
	main.camera.reset_smoothing()
	main.camera.process_priority = 200   # update after this script moved it
	spawns = [
		[5.0, "walker", -2, 2], [5.6, "runner", 2, 2], [6.2, "dog", 0, 1],
		[6.8, "walker", -3, 2], [7.4, "bloater", 0, 1], [8.0, "spitter", 3, 1],
		[8.6, "runner", -1, 2], [9.4, "brute", 1, 1], [10.0, "walker", -2, 2],
		[10.8, "dog", 2, 1], [11.4, "bloater", -2, 1], [12.0, "walker", 0, 3],
		[12.8, "runner", 3, 1], [13.4, "spitter", -3, 1],
	]


func _free(c: Vector2i, solid_only: bool) -> bool:
	var w = main.world
	if not w.in_bounds(c):
		return false
	if solid_only:
		return not w.astar.is_point_solid(c) and w.g_at(c) != World.G.WATER
	return w.can_build(c)


func _find_spot() -> Vector2i:
	# Score every spot: blocked cells count heavily, distance to home a little.
	var w = main.world
	var home: Vector2i = w.to_cell(w.player_start)
	var saved := base
	var best := home
	var best_score := INF
	for y in range(8, World.H - 8):
		for x in range(14, World.W - 14):
			var c := Vector2i(x, y)
			var d := Vector2(c - home).length()
			if d < 9.0:   # away from the home door (no "go home" prompt)
				continue
			base = c
			_make_plan()
			var bad := 0
			for step in plan:
				if not _free(step[1], false):
					bad += 1
			for a in range(-5, 14):
				for b in range(-2, 3):
					if (a < -1 and b != 0) or (a >= -1 and a <= 4):
						continue
					if not _free(c + dir * a + side * b, true):
						bad += 1
			var score := bad * 100.0 + d
			if score < best_score:
				best_score = score
				best = c
	base = saved
	plan.clear()
	return best


func _make_plan() -> void:
	plan.clear()
	var line := base + dir * 3
	var order := [0, -1, 1, -2, 2, -3, 3, -4, 4]
	for k in order:
		var kind := "gate" if k == 0 else "barricade"
		plan.append([kind, line + side * k])
	plan.append(["turret", base + dir * 1 + side * -2])
	plan.append(["turret", base + dir * 1 + side * 2])
	plan.append(["campfire", base - dir * 1 + side * 1])
	plan.append(["spikes", line + dir + side * -1])
	plan.append(["spikes", line + dir + side * 1])


func _hold(v: Vector2) -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)
	if v.x > 0: Input.action_press("move_right")
	if v.x < 0: Input.action_press("move_left")
	if v.y > 0: Input.action_press("move_down")
	if v.y < 0: Input.action_press("move_up")


func _aim_at(c: Vector2i) -> void:
	_aim_at_pos(main.world.cell_center(c))


func _aim_at_pos(pos: Vector2) -> void:
	var vp := get_viewport()
	vp.warp_mouse(vp.get_canvas_transform() * pos)


func _nearest_zombie(max_d: float):
	var best = null
	var bd := max_d
	for z in main.world.zombies:
		if z.dead:
			continue
		var d: float = z.global_position.distance_to(main.player.global_position)
		if d < bd:
			bd = d
			best = z
	return best
