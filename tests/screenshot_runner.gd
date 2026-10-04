extends Node
## Dev tool: plays the game automatically and saves screenshots.
## Run: godot --path . res://tests/screenshot_runner.tscn -- <out_dir>

var main
var out := "user://shots"
var t := 0.0
var step := 0
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


func _process(delta: float) -> void:
	t += delta
	match step:
		0:
			if t > 0.8 and not taken.has("01_menu"):
				shot("01_menu")
				main.menus.hide_all()
				main.menus.help_box.visible = true
				main.menus.dim.visible = true
			if t > 1.2:
				shot("01b_help")
				main._start_game()
				step = 1
		1:
			if t > 2.5:
				shot("02_day")
				var p = main.player
				p.inv = {"wood": 60, "stone": 40, "scrap": 40, "ammo": 80, "food": 3, "coins": 300}
				p.inventory_changed.emit()
				var c: Vector2i = main.world.to_cell(p.global_position)
				var kinds := ["barricade", "wall", "spikes", "turret", "campfire"]
				for i in kinds.size():
					main.build_kind = kinds[i]
					main._try_build(c + Vector2i(i - 2, -2))
				main.build_kind = ""
				# walk to the shop door
				p.global_position = main.world.shop.interact_point() + Vector2(0, 10)
				step = 2
		2:
			if t > 3.5:
				shot("03_at_shop")
				main._interact()
				step = 3
		3:
			if t > 4.5:
				shot("04_shop_open")
				for item in Res.SHOP:
					if item["id"] in ["machete", "shotgun", "ammo_pack"]:
						main.shop_ui._buy(item)
				shot("04b_shop_bought")
				main.shop_ui.close_shop()
				print("owned: ", main.player.owned, " coins: ", main.player.inv["coins"], " state: ", main.state)
				step = 4
		4:
			if t > 5.5:
				var p = main.player
				p.global_position = main.world.van.interact_point() + Vector2(0, 12)
				step = 5
		5:
			if t > 6.5:
				shot("05_van_broken")
				main._interact()
				print("van repaired: ", main.world.van.repaired)
				step = 6
		6:
			if t > 7.5:
				shot("06_van_fixed")
				main._interact()
				step = 7
		7:
			if t > 9.0:
				shot("07_travel")
				step = 8
		8:
			if t > 13.0:
				shot("08_new_area")
				print("area: ", main.area, " state: ", main.state, " score: ", main._score())
				main.phase_time = main.phase_len - 0.1
				step = 9
		9:
			if t > 24.0:
				_fight()
				shot("09_night_area2")
			if t > 30.0:
				shot("10_fight_shotgun")
				step = 10
			else:
				_fight()
		10:
			if t > 31.0 and main.player.alive:
				main.player._invuln = 0.0
				main.player.take_damage(999.0, Vector2.DOWN)
			if t > 34.0:
				shot("11_gameover")
				print("kills: ", main.kills, " state: ", main.state)
				var cam := Camera2D.new()
				main.add_child(cam)
				cam.make_current()
				main.state = main.State.OVER
				cam.zoom = Vector2(270.0 / 896.0, 270.0 / 896.0)
				cam.position = main.world.map_size() / 2.0
				main.hud.visible = false
				main.menus.visible = false
				main.canvas_mod.color = main.area_tint
				step = 11
		11:
			if t > 35.0:
				shot("12_map_area2")
				get_tree().quit()
