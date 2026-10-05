extends Node
## Dev tool: hunger, the Estate area and the manor house with three floors.
## Run: godot --path . res://tests/manor_runner.tscn -- <out_dir>

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
	print("shot ", name)


func next(after: float) -> bool:
	return t - step_t > after


func go() -> void:
	step += 1
	step_t = t


func _use_stairs(kind: String) -> void:
	var room: Interior = main.world.inside_room
	for s in room.stairs:
		if s.kind == kind:
			main.player.global_position = s.global_position + (Vector2(0, 4) if kind == "stairs_up" else Vector2(0, -6))
			main._interact()
			return
	print("no ", kind, " on floor ", room.floor_i)


func _search_all() -> void:
	var room: Interior = main.world.inside_room
	for c in room.containers:
		if not c.searched:
			main._search_furniture(c)


func _process(delta: float) -> void:
	t += delta
	var p = main.player
	match step:
		0:
			if next(0.5):
				main._start_game()
				p.hunger = 20.0
				go()
		1:
			if next(1.0):
				shot("01_hungry")
				p.hunger = 0.0
				p.inv["food"] = 3
				go()
		2:
			if next(4.5):
				print("hp while starving: ", p.hp)
				p.eat()
				go()
		3:
			if next(0.4):
				shot("02_eating")
				print("hunger after eating: ", p.hunger, " hp ", p.hp)
				main.van_repaired = true
				main.world.van.repair(false)
				main._travel()
				go()
		4:
			if next(5.0):
				shot("03_estate_arrival")
				print("area: ", main.area, " home kind: ", main.world.home.kind)
				var cam := Camera2D.new()
				cam.name = "Overview"
				main.add_child(cam)
				cam.zoom = Vector2(270.0 / 896.0, 270.0 / 896.0)
				cam.position = main.world.map_size() / 2.0
				cam.make_current()
				main.hud.visible = false
				go()
		5:
			if next(0.5):
				shot("04_estate_map")
				main.get_node("Overview").queue_free()
				main.camera.make_current()
				main.hud.visible = true
				p.global_position = main.world.home.interact_point() + Vector2(0, 12)
				go()
		6:
			if next(0.5):
				main._interact()
				go()
		7:
			if next(1.0):
				shot("05_manor_ground_floor")
				_use_stairs("stairs_up")
				go()
		8:
			if next(1.0):
				shot("06_manor_first_floor")
				print("floor: ", main.world.inside_room.floor_i, " containers: ", main.world.inside_room.containers.size())
				_search_all()
				_use_stairs("stairs_up")
				go()
		9:
			if next(1.0):
				shot("07_manor_attic")
				print("floor: ", main.world.inside_room.floor_i)
				_search_all()
				print("owned after treasure: ", p.owned)
				go()
		10:
			if next(1.0):
				shot("08_attic_searched")
				_use_stairs("stairs_down")
				go()
		11:
			if next(1.0):
				_use_stairs("stairs_down")
				go()
		12:
			if next(1.0):
				print("back on floor: ", main.world.inside_room.floor_i)
				p.global_position = main.world.inside_room.exit_pos
				go()
		13:
			if next(1.0):
				print("outside: ", main.world.inside == null)
				shot("09_outside_again")
				get_tree().quit()
