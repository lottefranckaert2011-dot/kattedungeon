extends Node
## Dev tool: checks new zombies, gate, iron barricade, weather and minimap.
## Run: godot --path . res://tests/feature_runner.tscn -- <out_dir>

var main
var out := "user://shots"
var t := 0.0
var step := 0
var step_t := 0.0
var taken := {}
var barricade
var gate_cell := Vector2i.ZERO


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


func _process(delta: float) -> void:
	t += delta
	var p = main.player
	match step:
		0:
			if next(0.5):
				main._start_game()
				go()
		1:
			if next(0.5):
				p.inv = {"wood": 60, "stone": 40, "scrap": 40, "ammo": 200, "food": 3, "coins": 0}
				p.inventory_changed.emit()
				var c: Vector2i = main.world.to_cell(p.global_position)
				main.build_kind = "barricade"
				main._try_build(c + Vector2i(-1, -3))
				main.build_kind = "gate"
				gate_cell = c + Vector2i(1, -3)
				main._try_build(gate_cell)
				main.build_kind = "barricade"
				main._try_build(c + Vector2i(3, -3))
				main.build_kind = ""
				barricade = main.world.structures.get(c + Vector2i(-1, -3))
				print("built: ", main.world.structures.size(), " gate layer: ", main.world.structures[gate_cell].collision_layer)
				# stand next to the first barricade and upgrade it
				p.global_position = barricade.global_position + Vector2(0, 12)
				go()
		2:
			if next(0.4):
				main._interact()
				print("upgraded: ", barricade.kind, " hp ", barricade.hp)
				go()
		3:
			if next(0.6):
				shot("01_iron_and_gate")
				p.global_position = main.world.cell_center(gate_cell) + Vector2(0, 8)
				go()
		4:
			if next(0.5):
				shot("02_gate_open")
				var c: Vector2i = main.world.to_cell(p.global_position)
				p.global_position = main.world.cell_center(c + Vector2i(0, 3))
				main._spawn_zombie("dog", c + Vector2i(-5, 6))
				main._spawn_zombie("bloater", c + Vector2i(0, 7))
				main._spawn_zombie("spitter", c + Vector2i(5, 6))
				go()
		5:
			if next(0.7):
				shot("03_new_zombies_day")
				for z in main.world.zombies:
					z.take_damage(999.0, Vector2.ZERO, false)
				main.night_num = 3
				main.force_weather = "rain"
				main.phase_time = main.phase_len - 0.1
				go()
		6:
			if next(5.0) and not taken.has("spawned"):
				taken["spawned"] = true
				var c: Vector2i = main.world.to_cell(p.global_position)
				main._spawn_zombie("bloater", c + Vector2i(-3, -5))
				main._spawn_zombie("spitter", c + Vector2i(4, 5))
				main._spawn_zombie("dog", c + Vector2i(-4, 4))
			if next(7.0):
				shot("04_rain_night")
			if next(10.0):
				shot("05_rain_later")
				print("structures: ", main.world.structures.size(), " player hp: ", p.hp, " kills: ", main.kills)
				for z in main.world.zombies:
					z.take_damage(999.0, Vector2.ZERO, false)
				main.wave_spawned = main.wave_total
				go()
		7:
			if next(0.5):
				p._invuln = 999.0
				main.weather.set_mode("fog")
				go()
		8:
			p.hp = 100.0
			if next(5.0):
				shot("06_fog_night")
				print("weather: ", main.weather.mode, " night: ", main.night_num)
				get_tree().quit()
