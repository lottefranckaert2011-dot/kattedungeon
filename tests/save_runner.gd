extends Node
## Dev tool: save in the morning, "continue" from the menu, and the save is gone after dying.
## Run: godot --path . res://tests/save_runner.tscn -- <out_dir>

var main
var out := "user://shots"
var t := 0.0
var step := 0
var step_t := 0.0
var before := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	Save.clear_run()
	_spawn_main()


func _spawn_main() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)


func shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(out.path_join(name + ".png"))
	print("shot ", name)


func next(after: float) -> bool:
	return t - step_t > after


func go() -> void:
	step += 1
	step_t = t


func _process(delta: float) -> void:
	t += delta
	match step:
		0:
			if next(0.5):
				main._new_game()
				go()
		1:
			if next(0.5):
				var p = main.player
				p.inv = {"wood": 33, "stone": 22, "scrap": 11, "ammo": 44, "food": 5, "coins": 77}
				p.give_weapon("machete")
				p.hunger = 60.0
				var c: Vector2i = main.world.to_cell(p.global_position)
				main.build_kind = "barricade"
				main._try_build(c + Vector2i(2, 2))
				main.build_kind = "wall"
				main._try_build(c + Vector2i(3, 2))
				main.build_kind = ""
				if not main.world.waiting.is_empty():
					p.global_position = main.world.waiting[0].global_position + Vector2(0, 14)
					main._interact()
				main.day_num = 4
				main.night_num = 3
				main.van_repaired = true
				main._autosave()
				before = {"home": main.world.home.global_position, "inv": p.inv.duplicate(), "allies": main.allies.size(),
					"structures": main.world.structures.size(), "owned": p.owned.duplicate()}
				print("saved: ", Save.has_run(), " ", before)
				go()
		2:
			if next(0.5):
				# "close the game": throw the whole game away and start it again
				main.queue_free()
				go()
		3:
			if next(0.3):
				_spawn_main()
				go()
		4:
			if next(1.0):
				shot("01_menu_continue")
				print("continue button: ", main.menus.continue_btn.visible, " '", main.menus.continue_btn.text, "'")
				main._continue_game()
				go()
		5:
			if next(1.5):
				shot("02_continued")
				var p = main.player
				print("same village: ", main.world.home.global_position == before["home"])
				print("inv: ", p.inv, " owned: ", p.owned, " melee: ", p.melee, " hunger: ", int(p.hunger))
				print("allies: ", main.allies.size(), " structures: ", main.world.structures.size(),
					" day: ", main.day_num, " night: ", main.night_num, " van: ", main.world.van.repaired)
				p._invuln = 0.0
				p.take_damage(999.0, Vector2.DOWN)
				go()
		6:
			if next(0.5):
				print("save after death: ", Save.has_run())
				get_tree().quit()
