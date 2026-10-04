extends Node
## Dev tool: plays the game automatically and saves screenshots.
## Run: godot --path . res://tests/screenshot_runner.tscn -- <out_dir>

var main
var out := "user://shots"
var t := 0.0
var step := 0
var got_close := false

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

func _process(delta: float) -> void:
	t += delta
	match step:
		0:
			if t > 1.0:
				shot("01_menu")
				main._start_game()
				step = 1
		1:
			if t > 2.5:
				shot("02_day")
				var p = main.player
				p.inv = {"wood": 40, "stone": 30, "scrap": 30, "ammo": 50, "food": 3}
				p.inventory_changed.emit()
				var c: Vector2i = main.world.to_cell(p.global_position)
				var kinds := ["barricade", "wall", "spikes", "turret", "campfire"]
				for i in kinds.size():
					main.build_kind = kinds[i]
					main._try_build(c + Vector2i(i - 2, -2))
				main._toggle_build("barricade")
				main.build_kind = "barricade"
				step = 2
		2:
			if t > 3.5:
				shot("03_built")
				main._toggle_build("barricade")
				main.phase_time = main.phase_len - 0.1
				step = 3
		3:
			if t > 6.0:
				shot("04_dusk")
				step = 4
		4:
			if t > 13.0 and not got_close:
				got_close = true
				var c: Vector2i = main.world.to_cell(main.player.global_position)
				main._spawn_zombie("brute", c + Vector2i(-4, 3))
				main._spawn_zombie("runner", c + Vector2i(4, 3))
				main._spawn_zombie("walker", c + Vector2i(-2, 4))
				main._spawn_zombie("walker", c + Vector2i(2, 4))
				main._spawn_zombie("walker", c + Vector2i(0, 5))
			if t > 14.2:
				shot("05b_close")
			if t > 16.0:
				shot("05_night")
				# walk towards the nearest zombie and fight
				step = 5
		5:
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
			if t > 24.0:
				shot("06_fight")
				main._pause()
				step = 6
		6:
			if t > 25.0 and main.state == main.State.PAUSE:
				shot("06b_pause")
				main._resume()
				main.hud.touch.visible = true
			if t > 26.0 and not taken.has("06c_touch"):
				print("touch: ", main.hud.touch.visible, " ", main.hud.touch.size, " ", main.hud.touch.is_visible_in_tree(), " ", main.player.touch_mode)
				shot("06c_touch")
				main.hud.touch.visible = false
			if t > 30.0 and main.player.alive:
				main.player._invuln = 0.0
				main.player.take_damage(999.0, Vector2.DOWN)
			if t > 40.0:
				shot("07_later")
				print("zombies alive: ", main._alive_zombies(), " kills: ", main.kills, " hp: ", main.player.hp, " state: ", main.state)
				var cam := Camera2D.new()
				main.add_child(cam)
				cam.make_current()
				main.state = main.State.OVER
				cam.zoom = Vector2(270.0 / 896.0, 270.0 / 896.0)
				cam.position = main.world.map_size() / 2.0
				main.hud.visible = false
				main.canvas_mod.color = Color.WHITE
				step = 7
		7:
			if t > 41.0:
				shot("08_map")
				get_tree().quit()
