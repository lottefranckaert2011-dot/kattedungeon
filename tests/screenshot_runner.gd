extends Node
## Dev tool: plays the game automatically and saves screenshots.
## Run: godot --path . res://tests/screenshot_runner.tscn -- <out_dir>

var main
var out := "user://shots"
var t := 0.0
var step := 0
var step_t := 0.0
var taken := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)


func shot(name: String) -> void:
	if taken.has(name):
		return
	taken[name] = true
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("shot ", name, " ", img.get_size())


func next(after: float) -> bool:
	return t - step_t > after


func go() -> void:
	step += 1
	step_t = t


func _fight() -> void:
	var p = main.player
	var best = null
	var bd := 9999.0
	for z in main.world.zombies:
		if not z.dead and z.global_position.distance_to(p.global_position) < bd:
			bd = z.global_position.distance_to(p.global_position)
			best = z
	if best:
		p.aim = (best.global_position - p.global_position).normalized()
		if bd < 30:
			p.attack()
		elif bd < 150:
			p.shoot()


func _rescue_nearest() -> void:
	var p = main.player
	if main.world.waiting.is_empty():
		print("no waiting survivors")
		return
	var sv = main.world.waiting[0]
	p.global_position = sv.global_position + Vector2(0, 14)


func _process(delta: float) -> void:
	t += delta
	match step:
		0:
			if next(0.8):
				shot("01_menu")
				main._start_game()
				go()
		1:
			if next(1.2):
				shot("02_day_pointer")
				var p = main.player
				p.inv = {"wood": 60, "stone": 40, "scrap": 40, "ammo": 80, "food": 3, "coins": 300}
				p.inventory_changed.emit()
				var c: Vector2i = main.world.to_cell(p.global_position)
				var kinds := ["barricade", "wall", "spikes", "turret", "campfire"]
				for i in kinds.size():
					main.build_kind = kinds[i]
					main._try_build(c + Vector2i(i - 2, -2))
				main.build_kind = ""
				_rescue_nearest()
				go()
		2:
			if next(0.6):
				shot("03_survivor_waiting")
				main._interact()
				print("allies: ", main.allies.size(), " waiting: ", main.world.waiting.size())
				go()
		3:
			if next(1.5):
				shot("04_survivor_follows")
				main.player.global_position = main.world.shop.interact_point() + Vector2(0, 10)
				go()
		4:
			if next(1.0):
				main._interact()
				go()
		5:
			if next(0.6):
				shot("05_shop")
				for item in Res.SHOP:
					if item["id"] in ["machete", "shotgun"]:
						main.shop_ui._buy(item)
				main.shop_ui.close_shop()
				main.player.global_position = main.world.van.interact_point() + Vector2(0, 12)
				go()
		6:
			if next(1.0):
				main._interact()   # repair
				go()
		7:
			if next(0.8):
				shot("06_van_fixed")
				main._interact()   # drive
				go()
		8:
			if next(1.5):
				shot("07_travel")
			if next(4.5):
				shot("08_area2_with_team")
				print("area: ", main.area, " van repaired: ", main.world.van.repaired, " allies: ", main.allies.size(), " waiting: ", main.world.waiting.size())
				_rescue_nearest()
				go()
		9:
			if next(0.6):
				main._interact()
				print("allies after 2nd rescue: ", main.allies.size())
				go()
		10:
			if next(2.0):
				shot("09_team_of_three")
				main.player.global_position = main.world.player_start
				for a in main.allies:
					a.place_near(main.player.position)
				main.phase_time = main.phase_len - 0.1
				go()
		11:
			_fight()
			if next(11.0):
				shot("10_night_team")
			if next(18.0):
				shot("11_night_later")
				print("kills: ", main.kills, " hp: ", main.player.hp, " allies hp: ", main.allies.map(func(a): return int(a.hp)))
				go()
		12:
			if main.player.alive:
				main.player._invuln = 0.0
				main.player.take_damage(999.0, Vector2.DOWN)
			if next(3.0):
				shot("12_gameover")
				get_tree().quit()
