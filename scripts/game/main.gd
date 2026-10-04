extends Node2D
## Game controller: menus, day/night cycle, zombie waves, building and score.

enum State { MENU, PLAY, PAUSE, OVER }

const FIRST_DAY := 75.0
const DAY_LENGTH := 50.0
const DUSK := 8.0
const DAY_COLOR := Color(1, 1, 1)
const DUSK_COLOR := Color(1.0, 0.78, 0.62)
const NIGHT_COLOR := Color(0.36, 0.38, 0.58)
const BUILD_RANGE := 4.5 * 16.0

static var auto_start := false

var state := State.MENU
var world: World
var player: Player
var camera: Camera2D
var canvas_mod: CanvasModulate
var hud: HUD
var menus: Menus
var ghost: Sprite2D

var is_night := false
var day_num := 1
var night_num := 0
var phase_time := 0.0
var phase_len := FIRST_DAY
var wave_total := 0
var wave_spawned := 0
var spawn_timer := 0.0
var wander_timer := 12.0
var kills := 0
var kill_score := 0
var nights_survived := 0
var build_kind := ""
var _shake := 0.0
var _hint_i := 0
var _hint_timer := 2.0
var _cursor_set := false


func _ready() -> void:
	_setup_input()

	process_mode = Node.PROCESS_MODE_ALWAYS
	world = World.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	world.generate(randi())

	player = Player.new()
	player.world = world
	player.main = self
	player.position = world.player_start
	world.entities.add_child(player)
	world.player = player
	player.hp_changed.connect(func(hp, mx): hud.set_hp(hp, mx))
	player.inventory_changed.connect(_on_inventory)
	player.died.connect(_on_player_died)
	player.message.connect(func(t): hud.show_message(t, 1.2, Color(1, 0.6, 0.5)))

	camera = Camera2D.new()
	camera.position = player.position
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(world.map_size().x)
	camera.limit_bottom = int(world.map_size().y)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	add_child(camera)

	canvas_mod = CanvasModulate.new()
	canvas_mod.color = DAY_COLOR
	add_child(canvas_mod)

	ghost = Sprite2D.new()
	ghost.centered = false
	ghost.visible = false
	ghost.z_index = 30
	world.add_child(ghost)

	hud = HUD.new()
	hud.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(hud)
	hud.build_selected.connect(_toggle_build)
	hud.pause_pressed.connect(_pause)
	hud.night_pressed.connect(_skip_day)
	hud.touch.action.connect(_on_touch_action)
	hud.set_hp(player.hp, Player.MAX_HP)
	hud.set_inventory(player.inv)
	hud.update_affordable(player)
	hud.set_score(0)

	menus = Menus.new()
	add_child(menus)
	menus.play_pressed.connect(_start_game)
	menus.resume_pressed.connect(_resume)
	menus.menu_pressed.connect(_to_menu)
	menus.again_pressed.connect(_again)

	CrazySDK.ad_finished.connect(_on_ad_finished)
	CrazySDK.loading_stop()

	var touch := DisplayServer.is_touchscreen_available() and (OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"))
	_set_touch(touch)

	if auto_start:
		auto_start = false
		_start_game()
	else:
		_enter_menu()


func _setup_input() -> void:
	var map := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"attack": [KEY_SPACE], "shoot": [KEY_F], "interact": [KEY_E],
		"eat": [KEY_R, KEY_H], "pause": [KEY_P, KEY_ESCAPE], "start_night": [KEY_N],
		"build_1": [KEY_1], "build_2": [KEY_2], "build_3": [KEY_3], "build_4": [KEY_4], "build_5": [KEY_5],
	}
	for action in map:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


# ------------------------------------------------------------------ states

func _enter_menu() -> void:
	state = State.MENU
	world.process_mode = Node.PROCESS_MODE_DISABLED
	hud.visible = false
	menus.show_main()
	Audio.play_music("menu")
	CrazySDK.gameplay_stop()


func _start_game() -> void:
	state = State.PLAY
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	hud.visible = true
	menus.hide_all()
	get_tree().paused = false
	day_num = 1
	is_night = false
	phase_time = 0.0
	phase_len = FIRST_DAY
	Audio.play_music("day")
	hud.show_message(Lang.t("gather_hint"), 3.5)
	_hint_i = 0 if not Save.tutorial_done else 99
	_hint_timer = 4.5
	CrazySDK.gameplay_start()
	_update_phase_ui()


func _pause() -> void:
	if state != State.PLAY:
		return
	state = State.PAUSE
	get_tree().paused = true
	menus.show_pause()
	CrazySDK.gameplay_stop()


func _resume() -> void:
	if state != State.PAUSE:
		return
	state = State.PLAY
	get_tree().paused = false
	menus.hide_all()
	CrazySDK.gameplay_start()


func _to_menu() -> void:
	get_tree().paused = false
	CrazySDK.gameplay_stop()
	get_tree().reload_current_scene()


func _again() -> void:
	auto_start = true
	_pending_restart = true
	CrazySDK.request_midgame()


var _pending_restart := false

func _on_ad_finished() -> void:
	if _pending_restart:
		_pending_restart = false
		get_tree().paused = false
		get_tree().reload_current_scene()
		return
	get_tree().paused = state == State.PAUSE


func _on_player_died() -> void:
	state = State.OVER
	build_kind = ""
	ghost.visible = false
	CrazySDK.gameplay_stop()
	var score := _score()
	var best := Save.submit(score, nights_survived)
	Audio.play_music("gameover", 0.6)
	if best and score > 0:
		Audio.play("highscore", -2.0)
		CrazySDK.happytime()
	await get_tree().create_timer(1.4).timeout
	hud.visible = false
	menus.show_over(nights_survived, kills, score, best and score > 0)


func _score() -> int:
	return kill_score + nights_survived * 250


# ------------------------------------------------------------------ loop

func _process(delta: float) -> void:
	_update_camera(delta)
	if state != State.PLAY or get_tree().paused:
		return
	if hud.touch.visible != player.touch_mode:
		_set_touch(hud.touch.visible)
	Audio.listener_pos = player.global_position
	phase_time += delta
	if is_night:
		_night_process(delta)
	else:
		_day_process(delta)
	_update_lighting()
	_update_build_ghost()
	_update_prompt()
	_tutorial(delta)
	_update_phase_ui()
	if hud.touch.visible:
		player.move_input = hud.touch.move
		if hud.touch.is_held("attack") and build_kind == "":
			player.attack()
		if hud.touch.is_held("shoot"):
			player.shoot()
	else:
		player.move_input = Vector2.ZERO
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and build_kind == "" and _mouse_in_world():
			player.attack()
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and build_kind == "":
			player.shoot()
		if Input.is_action_pressed("attack"):
			player.attack()
		if Input.is_action_pressed("shoot"):
			player.shoot()


func _mouse_in_world() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	return hovered == null


func _update_camera(delta: float) -> void:
	if player:
		camera.position = player.position + Vector2(0, -8)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 12.0)
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	else:
		camera.offset = Vector2.ZERO


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func hurt_flash() -> void:
	hud.hurt_flash()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and hud.touch.visible:
		if event.is_action("move_left") or event.is_action("move_right") or event.is_action("move_up") or event.is_action("move_down"):
			_set_touch(false)
	if event.is_action_pressed("pause"):
		if build_kind != "" and event is InputEventKey and event.physical_keycode == KEY_ESCAPE:
			_toggle_build(build_kind)
		elif state == State.PLAY:
			_pause()
		elif state == State.PAUSE:
			_resume()
		return
	if state != State.PLAY:
		return
	for i in Res.BUILD_ORDER.size():
		if event.is_action_pressed("build_%d" % (i + 1)):
			_toggle_build(Res.BUILD_ORDER[i])
	if event.is_action_pressed("interact"):
		_interact()
	if event.is_action_pressed("eat"):
		player.eat()
	if event.is_action_pressed("start_night"):
		_skip_day()
	if event is InputEventMouseButton and event.pressed and build_kind != "" and not hud.touch.visible:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_try_build(_mouse_cell())
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_toggle_build(build_kind)


func _set_touch(on: bool) -> void:
	hud.touch.active = true
	hud.touch.visible = on
	player.touch_mode = on
	if on:
		Input.set_custom_mouse_cursor(null)
	else:
		_set_cursor()


func _set_cursor() -> void:
	if _cursor_set:
		return
	_cursor_set = true
	var img := Image.create(19, 19, false, Image.FORMAT_RGBA8)
	var dark := Color(0.1, 0.06, 0.1)
	var light := Color(1.0, 0.95, 0.8)
	for i in 19:
		for t in [8, 9, 10]:
			if abs(i - 9) > 2:
				var c := light if t == 9 else dark
				img.set_pixel(i, t, c)
				img.set_pixel(t, i, c)
	Input.set_custom_mouse_cursor(ImageTexture.create_from_image(img), Input.CURSOR_ARROW, Vector2(9, 9))


func _on_touch_action(name: String) -> void:
	if state != State.PLAY:
		return
	match name:
		"attack":
			if build_kind != "":
				_try_build(player.front_cell())
			else:
				player.attack()
		"shoot":
			player.shoot()
		"eat":
			player.eat()
		"interact":
			_interact()
		"cancel":
			if build_kind != "":
				_toggle_build(build_kind)


# ------------------------------------------------------------------ day / night

func _day_process(delta: float) -> void:
	if phase_time >= phase_len:
		_start_night()
		return
	# A few stragglers wander in during the day after the first night.
	if night_num >= 1:
		wander_timer -= delta
		if wander_timer <= 0.0:
			wander_timer = randf_range(9.0, 15.0)
			if _alive_zombies() < 2 + night_num / 2:
				_spawn_zombie("walker")


func _skip_day() -> void:
	if state != State.PLAY or is_night:
		return
	var left := phase_len - phase_time
	if left > DUSK:
		kill_score += int(left)
		phase_time = phase_len - 0.01


func _start_night() -> void:
	is_night = true
	night_num += 1
	phase_time = 0.0
	wave_total = 6 + night_num * 4
	wave_spawned = 0
	spawn_timer = 2.0
	Audio.play("bell", 0.0, 0.0)
	Audio.play_music("night" if night_num % 2 == 1 else "night2")
	hud.show_message(Lang.t("night_comes"), 3.0, Color(1.0, 0.5, 0.45))
	shake(2.0)


func _night_process(delta: float) -> void:
	spawn_timer -= delta
	var max_alive := mini(30 + night_num * 2, 50)
	if wave_spawned < wave_total and spawn_timer <= 0.0 and _alive_zombies() < max_alive:
		spawn_timer = maxf(0.35, 1.7 - night_num * 0.12)
		var group := mini(randi_range(1, 2 + night_num / 3), wave_total - wave_spawned)
		var cell: Vector2i = world.spawn_cells.pick_random()
		for i in group:
			_spawn_zombie(_pick_type(), cell)
			wave_spawned += 1
	if wave_spawned >= wave_total and _alive_zombies() == 0:
		_end_night()


func _pick_type() -> String:
	var r := randf()
	var brute_share := 0.0 if night_num < 3 else minf(0.05 * (night_num - 2), 0.25)
	var runner_share := 0.0 if night_num < 2 else minf(0.12 + 0.03 * night_num, 0.35)
	if r < brute_share:
		return "brute"
	if r < brute_share + runner_share:
		return "runner"
	return "walker"


func _end_night() -> void:
	is_night = false
	nights_survived = night_num
	day_num += 1
	phase_time = 0.0
	phase_len = DAY_LENGTH
	world.new_day(day_num)
	player.heal(20.0)
	Audio.play("day_start", -2.0, 0.0)
	Audio.play_music("day")
	hud.show_message("%s  +%d" % [Lang.t("day_comes"), 250], 3.0, Color(0.7, 1.0, 0.6))
	hud.set_score(_score())
	# A natural break: good moment for a CrazyGames midgame ad.
	CrazySDK.request_midgame()


func _alive_zombies() -> int:
	var n := 0
	for z in world.zombies:
		if not z.dead:
			n += 1
	return n


func _spawn_zombie(type: String, cell := Vector2i(-1, -1)) -> void:
	if cell.x < 0:
		cell = world.spawn_cells.pick_random()
	var z := Zombie.new()
	z.setup(world, type, maxi(night_num, 1))
	z.position = world.cell_center(cell) + Vector2(randf_range(-5, 5), randf_range(-5, 5))
	z.died.connect(_on_zombie_died)
	world.entities.add_child(z)
	world.zombies.append(z)


func _on_zombie_died(z: Zombie) -> void:
	kills += 1
	kill_score += z.score
	world.zombies.erase(z)
	hud.set_score(_score())


func _update_lighting() -> void:
	var c := DAY_COLOR
	var light := 0.0
	if is_night:
		var t := clampf(phase_time / 3.0, 0.0, 1.0)
		c = DUSK_COLOR.lerp(NIGHT_COLOR, t)
		light = t
	else:
		var left := phase_len - phase_time
		if left < DUSK:
			var t := 1.0 - left / DUSK
			c = DAY_COLOR.lerp(DUSK_COLOR, t)
			light = t * 0.3
		elif phase_time < 3.0 and day_num > 1:
			c = NIGHT_COLOR.lerp(DAY_COLOR, phase_time / 3.0)
			light = 1.0 - phase_time / 3.0
	canvas_mod.color = c
	player.light.energy = light * 1.1


func _update_phase_ui() -> void:
	if is_night:
		var left := wave_total - wave_spawned + _alive_zombies()
		hud.set_phase(true, night_num, "%s: %d" % [Lang.t("zombies_left"), left], float(left) / maxf(1.0, wave_total))
		hud.night_btn.visible = false
	else:
		var left := maxf(0.0, phase_len - phase_time)
		hud.set_phase(false, day_num, "%d:%02d" % [int(left) / 60, int(left) % 60], left / phase_len)
		hud.night_btn.visible = left > DUSK
		hud.night_btn.text = "N: " + Lang.t("night") + " >>"


# ------------------------------------------------------------------ building

func _toggle_build(kind: String) -> void:
	if state != State.PLAY:
		return
	build_kind = "" if build_kind == kind else kind
	hud.set_selected(build_kind, player)
	if build_kind != "":
		var tex: Texture2D = Res.STRUCT_TEX[build_kind]
		if build_kind == "campfire":
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(0, 0, 16, 16)
			tex = at
		ghost.texture = tex
		ghost.offset = Vector2(0, 16 - tex.get_height() + 6 - 2)
		hud.show_message(Lang.t("build_mode_touch" if hud.touch.visible else "build_mode"), 1.6, Color(0.8, 0.95, 1.0))
	ghost.visible = build_kind != ""


func _mouse_cell() -> Vector2i:
	return world.to_cell(world.get_global_mouse_position())


func _cell_ok(c: Vector2i) -> bool:
	if not world.can_build(c):
		return false
	var center := world.cell_center(c)
	if center.distance_to(player.global_position) > BUILD_RANGE:
		return false
	if Res.BUILD[build_kind]["blocks"]:
		if world.to_cell(player.global_position + Vector2(0, -2)) == c:
			return false
		for z in world.zombies:
			if not z.dead and world.to_cell(z.global_position) == c:
				return false
	return true


func _update_build_ghost() -> void:
	if build_kind == "":
		return
	var c := player.front_cell() if hud.touch.visible else _mouse_cell()
	ghost.position = Vector2(c.x * 16, c.y * 16)
	var ok := _cell_ok(c) and player.has_cost(Res.BUILD[build_kind]["cost"])
	ghost.modulate = Color(0.6, 1.0, 0.6, 0.7) if ok else Color(1.0, 0.4, 0.4, 0.6)


func _try_build(c: Vector2i) -> void:
	if build_kind == "":
		return
	var cost: Dictionary = Res.BUILD[build_kind]["cost"]
	if not player.has_cost(cost):
		hud.show_message(Lang.t("not_enough"), 1.2, Color(1, 0.6, 0.5))
		Audio.play("error", -6.0)
		return
	if not _cell_ok(c):
		hud.show_message(Lang.t("cant_build"), 1.0, Color(1, 0.6, 0.5))
		Audio.play("error", -6.0)
		return
	player.pay(cost)
	world.add_structure(build_kind, c)
	Audio.play("build", -2.0, 0.1)
	Fx.burst(world, world.cell_center(c) + Vector2(0, 4), Color(0.8, 0.7, 0.5), 6, 30.0)
	if not player.has_cost(cost):
		_toggle_build(build_kind)


func _on_inventory() -> void:
	hud.set_inventory(player.inv)
	hud.update_affordable(player)


# ------------------------------------------------------------------ interaction

func _nearest_interactable():
	var best = null
	var bd := 22.0
	var p := player.global_position
	for e in world.entities.get_children():
		if e is Prop and e.can_search():
			var d: float = e.interact_point().distance_to(p)
			var reach := 30.0 if e.def.get("house", false) else bd
			if d < reach and d < bd + 8.0:
				bd = d
				best = e
		elif e is Structure and e.kind == "turret" and e.ammo < Structure.TURRET_MAX_AMMO:
			var d2: float = e.global_position.distance_to(p)
			if d2 < bd:
				bd = d2
				best = e
	return best


func _update_prompt() -> void:
	var it = _nearest_interactable()
	var txt := ""
	if it is Prop:
		txt = Lang.t("search")
	elif it is Structure:
		txt = Lang.t("refill")
	hud.prompt_label.text = "" if hud.touch.visible else txt
	hud.touch.refresh(it != null, build_kind != "")


func _interact() -> void:
	var it = _nearest_interactable()
	if it == null:
		return
	if it is Prop:
		var loot: Dictionary = it.search()
		if loot.is_empty():
			Fx.text(world, it.interact_point() + Vector2(0, -10), Lang.t("empty"), Color(0.8, 0.8, 0.8))
		for k in loot:
			Pickup.spawn(world, k, loot[k], it.interact_point() + Vector2(0, -4))
	elif it is Structure:
		var used: int = it.refill(mini(player.inv["ammo"], 20))
		if used > 0:
			player.inv["ammo"] -= used
			player.inventory_changed.emit()
			Audio.play("reload", -3.0)
			Fx.text(world, it.global_position + Vector2(0, -20), Lang.t("reloaded"), Color(1, 0.9, 0.5))
		else:
			player.message.emit(Lang.t("no_ammo"))


# ------------------------------------------------------------------ tutorial

const HINTS_NL := [
	"Hak bomen met je bijl voor HOUT (klik / spatie)",
	"Sla op rotsen voor STEEN",
	"Doorzoek huizen en kratten met E",
	"Kies 1-5 om te bouwen: zet barricades op de wegen!",
	"Rechts klikken / F = schieten (kost kogels)",
]
const HINTS_EN := [
	"Chop trees with your axe for WOOD (click / space)",
	"Hit rocks for STONE",
	"Search houses and crates with E",
	"Press 1-5 to build: block the roads with barricades!",
	"Right click / F = shoot (uses ammo)",
]
const HINTS_TOUCH_NL := [
	"Hak bomen met de bijl-knop voor HOUT",
	"Sla op rotsen voor STEEN",
	"Loop naar een huis en tik E om te doorzoeken",
	"Tik onderaan een gebouw en dan BOUW",
	"De pistool-knop schiet automatisch op zombies",
]
const HINTS_TOUCH_EN := [
	"Chop trees with the axe button for WOOD",
	"Hit rocks for STONE",
	"Walk to a house and tap E to search it",
	"Tap a building at the bottom, then BUILD",
	"The pistol button auto-aims at zombies",
]

func _tutorial(delta: float) -> void:
	if day_num > 1 or is_night or _hint_i >= 5:
		return
	_hint_timer -= delta
	if _hint_timer <= 0.0:
		_hint_timer = 8.0
		var list: Array
		if hud.touch.visible:
			list = HINTS_TOUCH_NL if Lang.lang == "nl" else HINTS_TOUCH_EN
		else:
			list = HINTS_NL if Lang.lang == "nl" else HINTS_EN
		hud.show_message(list[_hint_i], 5.0, Color(0.85, 0.95, 1.0))
		_hint_i += 1
		if _hint_i >= 5:
			Save.tutorial_done = true
			Save.write()
