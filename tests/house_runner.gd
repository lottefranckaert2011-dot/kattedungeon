extends Node
## Dev tool: houses you can enter, your safe home, sunrise and different villages.
## Run: godot --path . res://tests/house_runner.tscn -- <out_dir>

var main
var out := "user://shots"
var t := 0.0
var step := 0
var step_t := 0.0
var taken := {}
var house
var trips := 0
var overview: Camera2D


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
	print("shot ", name)


func next(after: float) -> bool:
	return t - step_t > after


func go() -> void:
	step += 1
	step_t = t


func _map_view(on: bool) -> void:
	if on:
		overview = Camera2D.new()
		main.add_child(overview)
		overview.zoom = Vector2(270.0 / 896.0, 270.0 / 896.0)
		overview.position = main.world.map_size() / 2.0
		overview.make_current()
		main.hud.visible = false
		main.canvas_mod.color = Color.WHITE
	else:
		overview.queue_free()
		main.camera.make_current()
		main.hud.visible = true


func _process(delta: float) -> void:
	t += delta
	var p = main.player
	match step:
		0:
			if next(0.5):
				main._start_game()
				go()
		1:
			if next(0.8):
				shot("01_start_at_home")
				for h in main.world.houses:
					if h.def.get("enter", false) and not h.def.get("home", false):
						house = h
						break
				p.global_position = house.interact_point() + Vector2(0, 12)
				go()
		2:
			if next(0.4):
				main._interact()
				go()
		3:
			if next(1.0):
				shot("02_inside_house")
				var room: Interior = main.world.get_interior(house)
				print("containers: ", room.containers.size(), " inside: ", main.world.inside != null)
				for c in room.containers:
					p.global_position = c.global_position + Vector2(0, 10)
					main._search_furniture(c)
				p.global_position = room.spawn_pos + Vector2(0, -30)
				print("inv after search: ", p.inv, " owned: ", p.owned)
				go()
		4:
			if next(1.2):
				shot("03_searched")
				var room: Interior = main.world.get_interior(house)
				p.global_position = room.exit_pos
				go()
		5:
			if next(1.0):
				print("outside again: ", main.world.inside == null)
				# take a survivor along, then go home
				if not main.world.waiting.is_empty():
					var sv = main.world.waiting[0]
					p.global_position = sv.global_position + Vector2(0, 14)
					main._interact()
				p.global_position = main.world.home.interact_point() + Vector2(0, 12)
				for a in main.allies:
					a.place_near(p.global_position)
				go()
		6:
			if next(0.6):
				main._interact()
				go()
		7:
			if next(1.0):
				shot("04_home_with_team")
				main.phase_time = main.phase_len - 0.1
				go()
		8:
			if next(1.0) and not taken.has("short"):
				taken["short"] = true
				main.night_len = 26.0
				main.wave_total = 8
				var dc: Vector2i = main.world.to_cell(main.world.home.door.global_position)
				for i in 3:
					main._spawn_zombie("walker", dc + Vector2i(i - 1, 3))
			if next(16.0) and not taken.has("05_home_night_door"):
				shot("05_home_night_door")
				print("door hp: ", main.world.home.door.hp, " / ", main.world.home.door.max_hp, " inside: ", main.world.inside != null)
			if next(30.0):
				shot("06_sunrise")
				print("night over: ", not main.is_night, " day: ", main.day_num)
				main.van_repaired = true
				main.world.van.repair(false)
				go()
		9:
			if next(0.5):
				if main.world.inside != null:
					main._exit_house()
				go()
		10:
			if next(1.0):
				_map_view(true)
				go()
		11:
			if next(0.5):
				shot("07_map_area%d" % (main.area + 1))
				_map_view(false)
				if trips >= 4:
					get_tree().quit()
					return
				trips += 1
				main._travel()
				go()
		12:
			if next(5.0):
				shot("08_arrive_area%d" % (main.area + 1))
				step = 10
				step_t = t
