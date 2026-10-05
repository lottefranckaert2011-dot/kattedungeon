extends Node2D
## Game controller: menus, day/night cycle, zombie waves, building and score.

enum State { MENU, PLAY, PAUSE, OVER, SHOP, TRAVEL }

const FIRST_DAY := 110.0
const DAY_LENGTH := 80.0
const AREA_BONUS := 500
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
var shop_ui: Shop
var ghost: Sprite2D
var area := 0
var areas_done := 0
var area_tint := Color.WHITE
var van_repaired := false          # once fixed, the van stays fixed in every area
var allies: Array = []             # survivors travelling with the player
var rescued_kinds: Array = []
var weather: Weather
var force_weather := ""            # for tests: "rain" / "fog" / "clear"
var _seen_types := {}
var night_len := 90.0
var _heal_t := 0.0
var _fading := false

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
	player = Player.new()
	player.main = self
	ghost = Sprite2D.new()
	ghost.centered = false
	ghost.visible = false
	ghost.z_index = 30
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	add_child(camera)
	_build_world(0)
	player.hp_changed.connect(func(hp, mx): hud.set_hp(hp, mx))
	player.inventory_changed.connect(_on_inventory)
	player.died.connect(_on_player_died)
	player.message.connect(func(t): hud.show_message(t, 1.2, Color(1, 0.6, 0.5)))

	player.weapons_changed.connect(_on_weapons_changed)

	canvas_mod = CanvasModulate.new()
	canvas_mod.color = DAY_COLOR
	add_child(canvas_mod)

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
	hud.set_weapons(player.melee, player.gun)
	hud.set_area("")

	weather = Weather.new()
	weather.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(weather)
	hud.minimap.set_world(world)

	shop_ui = Shop.new()
	add_child(shop_ui)
	shop_ui.closed.connect(_on_shop_closed)

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
		"switch_gun": [KEY_TAB],
		"build_1": [KEY_1], "build_2": [KEY_2], "build_3": [KEY_3], "build_4": [KEY_4], "build_5": [KEY_5], "build_6": [KEY_6],
	}
	for action in map:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


## (Re)builds the map for an area and puts the player in it.
func _build_world(area_index: int) -> void:
	if world:
		for a in allies:
			if a.get_parent():
				a.get_parent().remove_child(a)
		if player.get_parent():
			player.get_parent().remove_child(player)
		if ghost.get_parent():
			ghost.get_parent().remove_child(ghost)
		world.queue_free()
	area = area_index
	area_tint = Res.area_info(area)["tint"]
	world = World.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	move_child(world, 0)
	world.generate(randi(), area)
	world.day = day_num
	player.world = world
	player.position = world.player_start
	player.velocity = Vector2.ZERO
	world.entities.add_child(player)
	world.player = player
	world.add_child(ghost)
	world.allies = allies
	world.is_night = is_night
	for a in allies:
		a.world = world
		world.entities.add_child(a)
		a.place_near(player.position)
	if van_repaired:
		world.van.repair(false)
	_spawn_waiting_survivors()
	if hud:
		hud.minimap.set_world(world)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(world.map_size().x)
	camera.limit_bottom = int(world.map_size().y)
	camera.position = player.position
	camera.reset_smoothing()


func _spawn_waiting_survivors() -> void:
	var free := Res.MAX_ALLIES - allies.size()
	var count := mini(1 if area == 0 else 2, free)
	var start := world.to_cell(world.player_start)
	for k in Res.SURVIVOR_ORDER:
		if count <= 0:
			break
		if k in rescued_kinds:
			continue
		var sv := Survivor.new()
		sv.setup(world, k)
		sv.position = world.cell_center(world.far_free_cell(start, 16.0)) + Vector2(0, 4)
		world.entities.add_child(sv)
		world.waiting.append(sv)
		count -= 1


func _rescue(sv: Survivor) -> void:
	world.waiting.erase(sv)
	allies.append(sv)
	rescued_kinds.append(sv.kind)
	sv.join(allies.size() - 1)
	sv.downed_changed.connect(_on_ally_downed)
	Audio.play("highscore", -4.0)
	hud.show_message("%s (%s) %s" % [sv.display_name, sv.role_text(), Lang.t("joined")], 2.5, Color(0.7, 1.0, 0.6))
	hud.set_score(_score())


func _on_ally_downed(sv: Survivor) -> void:
	if sv.downed:
		hud.show_message("%s %s" % [sv.display_name, Lang.t("downed")], 2.0, Color(1, 0.6, 0.5))


func _revive_allies() -> void:
	for a in allies:
		a.revive()


func _area_title() -> String:
	return "%s %d: %s" % [Lang.t("area"), area + 1, Res.area_name(area)]


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
	hud.set_area(_area_title())
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
	get_tree().paused = state == State.PAUSE or state == State.SHOP


func _on_player_died() -> void:
	state = State.OVER
	weather.set_mode("clear")
	build_kind = ""
	ghost.visible = false
	CrazySDK.gameplay_stop()
	var score := _score()
	var best := Save.submit(score, nights_survived)
	Save.best_area = maxi(Save.best_area, area + 1)
	Save.write()
	Audio.play_music("gameover", 0.6)
	if best and score > 0:
		Audio.play("highscore", -2.0)
		CrazySDK.happytime()
	await get_tree().create_timer(1.4).timeout
	hud.visible = false
	menus.show_over(nights_survived, kills, score, best and score > 0, area + 1, rescued_kinds.size())


func _score() -> int:
	return kill_score + nights_survived * 250 + areas_done * AREA_BONUS + rescued_kinds.size() * 150


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
	_update_inside(delta)
	_update_build_ghost()
	_update_prompt()
	_update_pointer()
	hud.update_allies(allies)
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
	if state == State.SHOP or state == State.TRAVEL:
		return
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
	if event.is_action_pressed("switch_gun"):
		player.switch_gun()
	if event is InputEventMouseButton and event.pressed and build_kind == "" \
			and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		player.switch_gun()
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
		"swap":
			player.switch_gun()


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
	world.is_night = true
	night_num += 1
	phase_time = 0.0
	wave_total = 6 + night_num * 5
	night_len = minf(80.0 + night_num * 6.0, 150.0)
	wave_spawned = 0
	spawn_timer = 2.0
	Audio.play("bell", 0.0, 0.0)
	Audio.play_music("night" if night_num % 2 == 1 else "night2")
	var w := _pick_weather()
	weather.set_mode(w)
	var msg := Lang.t("night_comes") + "\n" + Lang.t("night_harder") % [night_num, wave_total]
	if w != "clear":
		msg += "\n" + Lang.t("weather_" + w)
	hud.show_message(msg, 3.5, Color(1.0, 0.5, 0.45))
	shake(2.0)


func _night_process(delta: float) -> void:
	spawn_timer -= delta
	var max_alive := mini(30 + night_num * 2, 50)
	if wave_spawned < wave_total and spawn_timer <= 0.0 and _alive_zombies() < max_alive:
		spawn_timer = maxf(0.3, minf(1.7 - night_num * 0.12, night_len * 0.55 / wave_total))
		var group := mini(randi_range(1, 2 + night_num / 3), wave_total - wave_spawned)
		var cell: Vector2i = world.spawn_cells.pick_random()
		for i in group:
			_spawn_zombie(_pick_type(), cell)
			wave_spawned += 1
	if wave_spawned >= wave_total and _alive_zombies() == 0:
		_end_night()
	elif phase_time >= night_len:
		_sunrise_burn()
		_end_night()


## The sun comes up: zombies still walking around burn away (no points for those).
func _sunrise_burn() -> void:
	var burnt := 0
	for z in world.zombies.duplicate():
		if z.dead:
			continue
		burnt += 1
		Fx.burst(world, z.global_position + Vector2(0, -8), Color(1.0, 0.6, 0.2), 8, 40.0)
		z.dead = true
		z.collision_layer = 0
		z.collision_mask = 0
		world.zombies.erase(z)
		var tw: Tween = z.create_tween()
		tw.tween_property(z, "modulate", Color(1.0, 0.4, 0.1, 0.0), 0.8)
		tw.tween_callback(z.queue_free)
	wave_spawned = wave_total
	if burnt > 0:
		Audio.play("break", -6.0, 0.1)
		hud.show_message(Lang.t("sunrise"), 3.0, Color(1.0, 0.8, 0.4))


func _pick_weather() -> String:
	if force_weather != "":
		return force_weather
	if night_num < 2:
		return "clear"
	var r := randf()
	if r < 0.35:
		return "rain"
	if r < 0.65:
		return "fog"
	return "clear"


## Which zombie to spawn: more and nastier types as the nights go on.
func _pick_type() -> String:
	var n := night_num
	var shares := {
		"brute": 0.0 if n < 3 else minf(0.05 * (n - 2), 0.2),
		"runner": 0.0 if n < 2 else minf(0.1 + 0.02 * n, 0.25),
		"dog": 0.0 if n < 2 else minf(0.1 + 0.02 * n, 0.22),
		"spitter": 0.0 if n < 3 else minf(0.06 + 0.02 * (n - 3), 0.15),
		"bloater": 0.0 if n < 3 else minf(0.05 + 0.015 * (n - 3), 0.12),
	}
	var r := randf()
	for t in shares:
		if r < shares[t]:
			return t
		r -= shares[t]
	return "walker"


func _end_night() -> void:
	is_night = false
	world.is_night = false
	weather.set_mode("clear")
	hud.minimap.set_world(world)
	_revive_allies()
	nights_survived = night_num
	day_num += 1
	phase_time = 0.0
	phase_len = DAY_LENGTH
	world.new_day(day_num)
	player.heal(20.0)
	var bonus := 10 + night_num * 5
	player.inv["coins"] += bonus
	player.inventory_changed.emit()
	Audio.play("day_start", -2.0, 0.0)
	Audio.play_music("day")
	hud.show_message("%s  +%d  (+%d %s)" % [Lang.t("day_comes"), 250, bonus, Lang.t("coins")], 3.0, Color(0.7, 1.0, 0.6))
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
	if type in ["dog", "bloater", "spitter", "brute"] and not _seen_types.has(type):
		_seen_types[type] = true
		hud.show_message(Lang.t("intro_" + type), 4.0, Color(1.0, 0.75, 0.4))
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
	if world.inside != null:
		c = Color(1.0, 0.95, 0.88) if not is_night else Color(0.86, 0.76, 0.64)
		canvas_mod.color = c
		player.light.energy = 0.0
		return
	canvas_mod.color = c * area_tint
	player.light.energy = light * 1.1


func _update_phase_ui() -> void:
	hud.set_danger(night_num if is_night else 0)
	if is_night:
		var left := wave_total - wave_spawned + _alive_zombies()
		var tl := maxf(0.0, night_len - phase_time)
		hud.set_phase(true, night_num, "%d:%02d  Z:%d" % [int(tl) / 60, int(tl) % 60, left], tl / night_len)
		hud.night_btn.visible = false
	else:
		var left := maxf(0.0, phase_len - phase_time)
		hud.set_phase(false, day_num, "%d:%02d" % [int(left) / 60, int(left) % 60], left / phase_len)
		hud.night_btn.visible = left > DUSK and world.inside == null
		hud.night_btn.text = "N: " + Lang.t("night") + " >>"


# ------------------------------------------------------------------ building

func _toggle_build(kind: String) -> void:
	if state != State.PLAY or world.inside != null:
		return
	build_kind = "" if build_kind == kind else kind
	hud.set_selected(build_kind, player)
	if build_kind != "":
		var tex: Texture2D = Res.struct_icon(build_kind)
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
	if world.inside != null:
		var room: Interior = world.get_interior(world.inside)
		if p.distance_to(room.exit_pos) < 24.0:
			return room
		return room.nearest_container(p, 22.0)
	for sv in world.waiting:
		var ds: float = sv.global_position.distance_to(p)
		if ds < 26.0 and allies.size() < Res.MAX_ALLIES:
			return sv
	for e in world.entities.get_children():
		if e is Prop and (e.def.get("shop", false) or e.def.get("van", false)):
			var dv: float = e.interact_point().distance_to(p)
			if dv < 30.0 and dv < bd + 8.0:
				bd = dv
				best = e
		elif e is Prop and e.def.get("enter", false):
			var de: float = e.interact_point().distance_to(p)
			if de < 30.0 and de < bd + 8.0:
				bd = de
				best = e
		elif e is Prop and e.can_search():
			var d: float = e.interact_point().distance_to(p)
			var reach := 30.0 if e.def.get("house", false) else bd
			if d < reach and d < bd + 8.0:
				bd = d
				best = e
		elif e is Structure and e.kind == "barricade":
			var du: float = e.global_position.distance_to(p)
			if du < bd:
				bd = du
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
	if it is Interior:
		txt = Lang.t("go_out")
	elif it is Furniture:
		txt = Lang.t("search")
	elif it is Prop and it.def.get("home", false):
		txt = Lang.t("enter_home")
	elif it is Prop and it.def.get("enter", false):
		txt = Lang.t("enter_house")
	elif it is Survivor:
		txt = "%s (%s - %s)" % [Lang.t("rescue"), it.display_name, it.role_text()]
	elif it is Prop and it.def.get("shop", false):
		txt = Lang.t("shop")
	elif it is Prop and it.def.get("van", false):
		if it.repaired:
			txt = Lang.t("van_go")
		else:
			txt = "%s (%s)" % [Lang.t("van_repair"), Res.dict_text(Res.van_cost(area))]
	elif it is Prop:
		txt = Lang.t("search")
	elif it is Structure and it.kind == "barricade":
		txt = "%s (%s)" % [Lang.t("upgrade_iron"), Res.dict_text(Res.BUILD["barricade_iron"]["cost"])]
	elif it is Structure:
		txt = Lang.t("refill")
	hud.prompt_label.text = "" if hud.touch.visible else txt
	hud.touch.refresh(it != null, build_kind != "")
	hud.touch.can_swap = player.gun_count() > 1


func _interact() -> void:
	var it = _nearest_interactable()
	if it == null or _fading:
		return
	if it is Interior:
		_exit_house()
	elif it is Furniture:
		_search_furniture(it)
	elif it is Prop and it.def.get("enter", false):
		_enter_house(it)
	elif it is Survivor:
		_rescue(it)
	elif it is Prop and it.def.get("shop", false):
		_open_shop()
	elif it is Prop and it.def.get("van", false):
		_use_van(it)
	elif it is Prop:
		var loot: Dictionary = it.search()
		if loot.is_empty():
			Fx.text(world, it.interact_point() + Vector2(0, -10), Lang.t("empty"), Color(0.8, 0.8, 0.8))
		for k in loot:
			Pickup.spawn(world, k, loot[k], it.interact_point() + Vector2(0, -4))
	elif it is Structure and it.kind == "barricade":
		var cost: Dictionary = Res.BUILD["barricade_iron"]["cost"]
		if not player.has_cost(cost):
			hud.show_message("%s: %s" % [Lang.t("not_enough"), Res.dict_text(cost)], 1.6, Color(1, 0.6, 0.5))
			Audio.play("error", -6.0)
			return
		player.pay(cost)
		it.upgrade("barricade_iron")
		Audio.play("reload", -2.0)
		Audio.play("build", -4.0, 0.1, null, 0.8)
		Fx.text(world, it.global_position + Vector2(0, -22), Lang.t("iron_done"), Color(0.85, 0.9, 1.0))
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
	"Iemand roept HELP! Volg de gele pijl en neem ze mee met E",
	"Doorzoek huizen en kratten met E",
	"Kies 1-6 om te bouwen: zet barricades op de wegen!",
	"Rechts klikken / F = schieten (kost kogels)",
	"Zombies laten MUNTEN vallen: koop wapens in de paarse winkel",
	"Maak de kapotte blauwe bus en rijd naar een nieuw gebied!",
]
const HINTS_EN := [
	"Chop trees with your axe for WOOD (click / space)",
	"Hit rocks for STONE",
	"Someone shouts HELP! Follow the yellow arrow and take them along with E",
	"Search houses and crates with E",
	"Press 1-6 to build: block the roads with barricades!",
	"Right click / F = shoot (uses ammo)",
	"Zombies drop COINS: buy weapons in the purple shop",
	"Fix the broken blue van and drive to a new area!",
]
const HINTS_TOUCH_NL := [
	"Hak bomen met de bijl-knop voor HOUT",
	"Sla op rotsen voor STEEN",
	"Iemand roept HELP! Volg de gele pijl en tik E om ze mee te nemen",
	"Loop naar een huis en tik E om te doorzoeken",
	"Tik onderaan een gebouw en dan BOUW",
	"De pistool-knop schiet automatisch op zombies",
	"Zombies laten MUNTEN vallen: koop wapens in de paarse winkel",
	"Maak de kapotte blauwe bus en rijd naar een nieuw gebied!",
]
const HINTS_TOUCH_EN := [
	"Chop trees with the axe button for WOOD",
	"Hit rocks for STONE",
	"Someone shouts HELP! Follow the yellow arrow and tap E to take them along",
	"Walk to a house and tap E to search it",
	"Tap a building at the bottom, then BUILD",
	"The pistol button auto-aims at zombies",
	"Zombies drop COINS: buy weapons in the purple shop",
	"Fix the broken blue van and drive to a new area!",
]

func _tutorial(delta: float) -> void:
	if day_num > 1 or is_night or _hint_i >= HINTS_NL.size():
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
		if _hint_i >= HINTS_NL.size():
			Save.tutorial_done = true
			Save.write()


# ------------------------------------------------------------------ shop

func _open_shop() -> void:
	if is_night:
		hud.show_message(Lang.t("shop_closed"), 1.6, Color(1, 0.6, 0.5))
		Audio.play("error", -6.0)
		return
	if build_kind != "":
		_toggle_build(build_kind)
	state = State.SHOP
	get_tree().paused = true
	shop_ui.open_shop.call_deferred(player)


func _on_shop_closed() -> void:
	if state != State.SHOP:
		return
	state = State.PLAY
	get_tree().paused = false


func _on_weapons_changed() -> void:
	hud.set_weapons(player.melee, player.gun)


# ------------------------------------------------------------------ van / travel

func _use_van(v: Prop) -> void:
	if not v.repaired:
		var cost := Res.van_cost(area)
		if not player.has_cost(cost):
			hud.show_message("%s: %s" % [Lang.t("van_need"), Res.dict_text(cost)], 2.0, Color(1, 0.6, 0.5))
			Audio.play("error", -6.0)
			return
		player.pay(cost)
		v.repair()
		van_repaired = true
		Audio.play("build", 0.0, 0.0)
		Audio.play("reload", -2.0)
		hud.show_message(Lang.t("van_fixed"), 2.0, Color(0.7, 1.0, 0.6))
		return
	if is_night:
		hud.show_message(Lang.t("van_night"), 1.6, Color(1, 0.6, 0.5))
		Audio.play("error", -6.0)
		return
	_travel()


func _travel() -> void:
	state = State.TRAVEL
	world.inside = null
	weather.visible = true
	weather.set_mode("clear")
	if build_kind != "":
		_toggle_build(build_kind)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var next := area + 1
	var layer := CanvasLayer.new()
	layer.layer = 25
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.09, 0.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var size := get_viewport().get_visible_rect().size
	var label := UITheme.label("%s\n%s %d: %s" % [Lang.t("travel_to"), Lang.t("area"), next + 1, Res.area_name(next)], 16, Color(1.0, 0.9, 0.6))
	label.add_theme_font_override("font", UITheme.font())
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(size.x, 40)
	label.position = Vector2(0, size.y / 2.0 - 50)
	label.modulate.a = 0.0
	layer.add_child(label)
	var road := ColorRect.new()
	road.color = Color(0.45, 0.32, 0.22)
	road.size = Vector2(size.x, 6)
	road.position = Vector2(0, size.y / 2.0 + 22)
	road.modulate.a = 0.0
	layer.add_child(road)
	var car := TextureRect.new()
	car.texture = Res.VAN_FIXED
	car.position = Vector2(-50, size.y / 2.0 - 4)
	layer.add_child(car)

	Audio.play("reload", 0.0)
	var tw := create_tween()
	tw.tween_property(bg, "color:a", 1.0, 0.6)
	tw.parallel().tween_property(label, "modulate:a", 1.0, 0.6)
	tw.parallel().tween_property(road, "modulate:a", 1.0, 0.6)
	tw.tween_property(car, "position:x", size.x + 10.0, 2.4).set_trans(Tween.TRANS_SINE)
	await tw.finished

	# Build the new area while the screen is black.
	areas_done += 1
	world.zombies.clear()
	is_night = false
	_build_world(next)
	_revive_allies()
	day_num += 1
	world.day = day_num
	phase_time = 0.0
	phase_len = DAY_LENGTH + 10.0
	player.heal(30.0)
	hud.set_area(_area_title())
	hud.set_score(_score())
	_update_lighting()
	_update_phase_ui()
	CrazySDK.request_midgame()

	var tw2 := create_tween()
	tw2.tween_property(bg, "color:a", 0.0, 0.8)
	tw2.parallel().tween_property(label, "modulate:a", 0.0, 0.5)
	tw2.parallel().tween_property(road, "modulate:a", 0.0, 0.5)
	tw2.parallel().tween_property(car, "modulate:a", 0.0, 0.3)
	await tw2.finished
	layer.queue_free()
	state = State.PLAY
	Audio.play("day_start", -2.0, 0.0)
	hud.show_message("%s  +%d" % [_area_title(), AREA_BONUS], 3.0, Color(0.7, 1.0, 0.6))


## Arrow at the screen edge pointing to the nearest survivor waiting for help.
func _update_pointer() -> void:
	if world.inside != null:
		hud.set_pointer(false, Vector2.ZERO, Vector2.ZERO)
		return
	var best = null
	var bd := INF
	for sv in world.waiting:
		var d: float = sv.global_position.distance_to(player.global_position)
		if d < bd:
			bd = d
			best = sv
	if best == null or allies.size() >= Res.MAX_ALLIES:
		hud.set_pointer(false, Vector2.ZERO, Vector2.ZERO)
		return
	var vp := get_viewport().get_visible_rect().size
	var rel: Vector2 = best.global_position + Vector2(0, -10) - camera.get_screen_center_position()
	var screen := rel + vp / 2.0
	var margin := 14.0
	if Rect2(Vector2(margin, margin), vp - Vector2(margin, margin) * 2.0).has_point(screen):
		hud.set_pointer(false, Vector2.ZERO, Vector2.ZERO)
		return
	var dir := rel.normalized()
	var half := vp / 2.0 - Vector2(margin, margin)
	var t := minf(half.x / maxf(absf(dir.x), 0.001), half.y / maxf(absf(dir.y), 0.001))
	hud.set_pointer(true, vp / 2.0 + dir * t, dir)


# ------------------------------------------------------------------ houses

func _fade(mid: Callable) -> void:
	_fading = true
	var layer := CanvasLayer.new()
	layer.layer = 15
	add_child(layer)
	var rect := ColorRect.new()
	rect.color = Color(0.04, 0.03, 0.05, 0.0)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	var tw := create_tween()
	tw.tween_property(rect, "color:a", 1.0, 0.18)
	tw.tween_callback(mid)
	tw.tween_property(rect, "color:a", 0.0, 0.22)
	tw.tween_callback(func():
		layer.queue_free()
		_fading = false)


func _enter_house(house: Prop) -> void:
	if house.door and house.door.hp <= 0.0:
		hud.show_message(Lang.t("door_broken"), 1.6, Color(1, 0.6, 0.5))
		Audio.play("error", -6.0)
		return
	if build_kind != "":
		_toggle_build(build_kind)
	Audio.play("search_house", -4.0)
	var room: Interior = world.get_interior(house)
	_fade(func():
		world.inside = house
		player.position = room.spawn_pos
		player.velocity = Vector2.ZERO
		for a in allies:
			a.place_near(room.spawn_pos + Vector2(0, -24))
		_camera_to_room(room)
		weather.visible = false
		if house.def.get("home", false):
			hud.show_message(Lang.t("home_safe"), 2.5, Color(0.7, 1.0, 0.6))
		elif not room.containers.is_empty():
			hud.show_message(Lang.t("house_search_hint"), 2.0, Color(0.85, 0.95, 1.0)))


func _exit_house(kicked := false) -> void:
	var house = world.inside
	if house == null:
		return
	var out: Vector2 = house.interact_point() + Vector2(0, 14)
	var go_out := func():
		world.inside = null
		player.position = out
		player.velocity = Vector2.ZERO
		for a in allies:
			a.place_near(out)
		_camera_to_map()
		weather.visible = true
	if kicked:
		go_out.call()
		hud.show_message(Lang.t("door_broken_out"), 3.0, Color(1, 0.5, 0.45))
		shake(4.0)
	else:
		Audio.play("search_house", -6.0, 0.1, null, 0.9)
		_fade(go_out)


func _camera_to_room(room: Interior) -> void:
	var vp := get_viewport().get_visible_rect().size
	camera.limit_left = int(room.center.x - vp.x / 2.0)
	camera.limit_right = int(room.center.x + vp.x / 2.0)
	camera.limit_top = int(room.center.y - vp.y / 2.0)
	camera.limit_bottom = int(room.center.y + vp.y / 2.0)
	camera.position = room.center
	camera.reset_smoothing()


func _camera_to_map() -> void:
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(world.map_size().x)
	camera.limit_bottom = int(world.map_size().y)
	camera.position = player.position
	camera.reset_smoothing()


func _update_inside(delta: float) -> void:
	var house = world.inside
	if house == null:
		hud.set_door(false, 0.0)
		return
	var room: Interior = world.get_interior(house)
	if room.at_exit(player.global_position):
		_exit_house()
		return
	var door: HouseDoor = house.door
	hud.set_door(is_night or door.hp < door.max_hp, door.hp / door.max_hp)
	if door.hp <= 0.0:
		_exit_house(true)
		return
	if door.hp < door.max_hp and is_night and door.should_warn():
		hud.show_message(Lang.t("door_hit"), 2.0, Color(1, 0.6, 0.5))
	# Home sweet home: everybody rests and heals.
	if house.def.get("home", false):
		_heal_t -= delta
		if _heal_t <= 0.0:
			_heal_t = 1.0
			player.heal(3.0, false)
			for a in allies:
				a.heal(3.0, false)


func _search_furniture(f: Furniture) -> void:
	f.set_searched(true)
	Audio.play("search_crate", -3.0)
	var loot := Interior.roll_loot(day_num)
	var at := f.global_position + Vector2(0, 6)
	for k in loot:
		if k == "weapon":
			var options: Array = []
			for item in Res.SHOP:
				if Res.WEAPONS.has(item["id"]) and not item["id"] in player.owned:
					options.append(item["id"])
			if options.is_empty():
				Pickup.spawn(world, "coins", 15, at)
				continue
			var id: String = options.pick_random()
			player.give_weapon(id)
			Audio.play("highscore", -4.0)
			hud.show_message(Lang.t("found_weapon") % Lang.t("w_" + id), 2.5, Color(1.0, 0.9, 0.4))
		else:
			Pickup.spawn(world, k, loot[k], at)
