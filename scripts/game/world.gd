class_name World
extends Node2D
## Builds the village map, owns the pathfinding grid and keeps track of
## everything that occupies a tile (props and player-built structures).

const T := 16
const W := 72
const H := 56

enum G { GRASS, DIRT, WATER, COBBLE, SOIL }

const ROAD_Y := 27      # horizontal road rows ROAD_Y-1 .. ROAD_Y+1
const ROAD_X := 36      # vertical road cols ROAD_X-1 .. ROAD_X+1
const FOREST := 4       # thickness of the forest band around the map

var ground := PackedInt32Array()
var ground_var := PackedInt32Array()
var astar := AStarGrid2D.new()
var occupied := {}       # Vector2i -> Prop (static obstacles)
var structures := {}     # Vector2i -> Structure
var reserved := {}       # cells that must stay free during generation
var spawn_cells: Array[Vector2i] = []
var player_start := Vector2.ZERO
var rng := RandomNumberGenerator.new()

var player                # Player
var zombies: Array = []   # living + dying Zombie nodes
var allies: Array = []    # Survivor nodes that joined the player (shared with main)
var waiting: Array = []   # Survivor nodes in this area still waiting for help
var is_night := false
var entities: Node2D     # y-sorted container for everything that stands on the ground
var decals: Node2D       # blood splats etc. drawn on the ground
var ground_sprite: Sprite2D
var day := 1
var area := 0
var info: Dictionary = {}
var van: Prop
var shop: Prop


func generate(seed_value: int, area_index := 0) -> void:
	rng.seed = seed_value
	area = area_index
	info = Res.area_info(area)
	ground.resize(W * H)
	ground_var.resize(W * H)
	ground.fill(G.GRASS)
	for i in W * H:
		ground_var[i] = rng.randi() & 0x7fffffff

	astar.region = Rect2i(0, 0, W, H)
	astar.cell_size = Vector2(T, T)
	astar.offset = Vector2(T / 2.0, T / 2.0)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()

	decals = Node2D.new()
	decals.z_index = -5
	add_child(decals)
	entities = Node2D.new()
	entities.y_sort_enabled = true
	add_child(entities)

	_layout_ground()
	_build_ground_texture()
	_build_water_collision()
	_build_borders()
	_place_village()
	_place_forest()
	_scatter()
	player_start = cell_center(Vector2i(ROAD_X, ROAD_Y + 4))


# ------------------------------------------------------------------ helpers

func idx(c: Vector2i) -> int:
	return c.y * W + c.x

func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < W and c.y < H

func g_at(c: Vector2i) -> int:
	if not in_bounds(c):
		return G.GRASS
	return ground[idx(c)]

func set_g(c: Vector2i, v: int) -> void:
	if in_bounds(c):
		ground[idx(c)] = v

func to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / T), floori(p.y / T))

func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * T + T / 2.0, c.y * T + T / 2.0)

func is_road(c: Vector2i) -> bool:
	return abs(c.y - ROAD_Y) <= 1 or abs(c.x - ROAD_X) <= 1

func is_free(c: Vector2i) -> bool:
	return in_bounds(c) and not occupied.has(c) and not structures.has(c) \
		and g_at(c) != G.WATER and not astar.is_point_solid(c)

func map_size() -> Vector2:
	return Vector2(W * T, H * T)

func set_solid(c: Vector2i, solid: bool) -> void:
	if in_bounds(c):
		astar.set_point_solid(c, solid)

## Nearest walkable cell (used when the player stands half inside an obstacle).
func nearest_walkable(c: Vector2i) -> Vector2i:
	if in_bounds(c) and not astar.is_point_solid(c):
		return c
	for r in range(1, 4):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var n := c + Vector2i(dx, dy)
				if in_bounds(n) and not astar.is_point_solid(n):
					return n
	return c

func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := nearest_walkable(to_cell(from))
	var b := nearest_walkable(to_cell(to))
	if a == b:
		return PackedVector2Array()
	var ids := astar.get_id_path(a, b)
	var pts := PackedVector2Array()
	for i in range(1, ids.size()):
		pts.append(cell_center(ids[i]))
	return pts


# ------------------------------------------------------------------ ground

func _layout_ground() -> void:
	# Roads (dirt) with slightly wobbly edges.
	for x in W:
		var wob := 1 if rng.randf() < 0.25 else 0
		for y in range(ROAD_Y - 1 - wob, ROAD_Y + 2):
			set_g(Vector2i(x, y), G.DIRT)
	for y in H:
		var wob := 1 if rng.randf() < 0.25 else 0
		for x in range(ROAD_X - 1, ROAD_X + 2 + wob):
			set_g(Vector2i(x, y), G.DIRT)
	# Village square (cobblestones).
	for y in range(ROAD_Y - 4, ROAD_Y + 5):
		for x in range(ROAD_X - 5, ROAD_X + 6):
			var corner: bool = abs(y - ROAD_Y) == 4 and abs(x - ROAD_X) == 5
			if not corner:
				set_g(Vector2i(x, y), G.COBBLE)
	# Small dirt paths to the house doors are added in _place_village.
	# Pond in the south-west.
	if info.get("pond", true):
		var pc := Vector2(15, 44)
		for y in range(36, 53):
			for x in range(5, 27):
				var d := Vector2((x - pc.x) / 7.5, (y - pc.y) / 4.8)
				var wob := sin(x * 1.3) * 0.06 + cos(y * 1.7) * 0.06
				if d.length() < 1.0 + wob:
					set_g(Vector2i(x, y), G.WATER)
	# Farm field in the south-east.
	if info.get("farm", true):
		for y in range(39, 47):
			for x in range(46, 58):
				set_g(Vector2i(x, y), G.SOIL)
		for y in range(37, 49):
			for x in range(44, 60):
				if g_at(Vector2i(x, y)) != G.SOIL:
					reserved[Vector2i(x, y)] = true
	# Keep roads and square free of props.
	for y in H:
		for x in W:
			var c := Vector2i(x, y)
			if g_at(c) != G.GRASS:
				reserved[c] = true
			if g_at(c) == G.WATER:
				astar.set_point_solid(c, true)


func _grass_like(c: Vector2i) -> bool:
	return g_at(c) == G.GRASS

func _build_ground_texture() -> void:
	var tiles := Res.TILES.get_image()
	var edges := Res.EDGES.get_image()
	tiles.convert(Image.FORMAT_RGBA8)
	edges.convert(Image.FORMAT_RGBA8)
	var img := Image.create(W * T, H * T, false, Image.FORMAT_RGBA8)
	var rect := Rect2i(0, 0, T, T)
	for y in H:
		for x in W:
			var c := Vector2i(x, y)
			var v := ground_var[idx(c)]
			var t := 0
			match g_at(c):
				G.GRASS:
					var r := v % 100
					if r < 6:
						t = 4 + (v / 100) % 2
					elif r < 12:
						t = 14
					else:
						t = (v / 100) % 4
				G.DIRT:
					t = 6 + (v / 100) % 3
				G.WATER:
					t = 11 if v % 100 < 7 else 9 + (v / 100) % 2
				G.COBBLE:
					t = 12 + 3 * ((v / 100) % 2)
				G.SOIL:
					t = 13
			var dst := Vector2i(x * T, y * T)
			img.blit_rect(tiles, Rect2i(t * T, 0, T, T), dst)
			if g_at(c) != G.GRASS:
				_blend_edges(img, edges, c, dst)
	ground_sprite = Sprite2D.new()
	ground_sprite.texture = ImageTexture.create_from_image(img)
	ground_sprite.centered = false
	ground_sprite.z_index = -10
	add_child(ground_sprite)
	move_child(ground_sprite, 0)


func _blend_edges(img: Image, edges: Image, c: Vector2i, dst: Vector2i) -> void:
	var water := g_at(c) == G.WATER
	var row := 16 if water else 0
	var other := func(o: Vector2i) -> bool:
		if water:
			return g_at(o) != G.WATER
		return _grass_like(o)
	var n: bool = other.call(c + Vector2i(0, -1))
	var s: bool = other.call(c + Vector2i(0, 1))
	var e: bool = other.call(c + Vector2i(1, 0))
	var w: bool = other.call(c + Vector2i(-1, 0))
	var sides := [[n, 0], [s, 1], [e, 2], [w, 3]]
	for sd in sides:
		if sd[0]:
			img.blend_rect(edges, Rect2i(sd[1] * T, row, T, T), dst)
	var corners := [
		[Vector2i(1, -1), not n and not e, 4],
		[Vector2i(-1, -1), not n and not w, 5],
		[Vector2i(1, 1), not s and not e, 6],
		[Vector2i(-1, 1), not s and not w, 7],
	]
	for cr in corners:
		if cr[1] and other.call(c + cr[0]):
			img.blend_rect(edges, Rect2i(cr[2] * T, row, T, T), dst)


func _build_water_collision() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for y in H:
		var x := 0
		while x < W:
			if g_at(Vector2i(x, y)) == G.WATER:
				var start := x
				while x < W and g_at(Vector2i(x, y)) == G.WATER:
					x += 1
				var shape := CollisionShape2D.new()
				var rs := RectangleShape2D.new()
				rs.size = Vector2((x - start) * T - 4, T - 4)
				shape.shape = rs
				shape.position = Vector2((start + x) * T / 2.0, y * T + T / 2.0)
				body.add_child(shape)
			else:
				x += 1


func _build_borders() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	add_child(body)
	var size := map_size()
	var rects := [
		Rect2(-16, -16, size.x + 32, 16), Rect2(-16, size.y, size.x + 32, 16),
		Rect2(-16, 0, 16, size.y), Rect2(size.x, 0, 16, size.y),
	]
	for r in rects:
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = r.size
		cs.shape = rs
		cs.position = r.position + r.size / 2.0
		body.add_child(cs)


# ------------------------------------------------------------------ props

func add_prop(kind: String, c: Vector2i, extra := {}) -> Prop:
	var p := Prop.new()
	p.setup(self, kind, c, extra)
	entities.add_child(p)
	return p

func can_place_prop(c: Vector2i, footprint: Array) -> bool:
	for f in footprint:
		var cc: Vector2i = c + f
		if not in_bounds(cc) or occupied.has(cc) or reserved.has(cc) or g_at(cc) != G.GRASS:
			return false
	return true


func _place_village() -> void:
	# Houses: top-left cell of the 4x4 sprite area. Doors face south.
	var houses := [
		[Vector2i(24, 18), "house_red"], [Vector2i(42, 18), "house_blue"],
		[Vector2i(24, 32), "house_tan"], [Vector2i(42, 32), "house_white"],
		[Vector2i(17, 18), "house_tan"], [Vector2i(49, 18), "house_red"],
		[Vector2i(49, 32), "house_blue"],
	]
	houses.resize(mini(houses.size(), info.get("houses", 7)))
	# The weapon shop stands next to the village square in every area.
	houses.append([Vector2i(29, 32), "shop"])
	for h in houses:
		var c: Vector2i = h[0]
		var house := add_prop(h[1], c + Vector2i(0, 3))
		if h[1] == "shop":
			shop = house
			_add_shopkeeper(house.global_position + Vector2(-22, 6))
		# a small dirt path from the door down to the road / grass
		for y in range(c.y + 4, c.y + 6):
			var pc := Vector2i(c.x + 1, y)
			if g_at(pc) == G.GRASS:
				reserved[pc] = true
	add_prop("well", Vector2i(ROAD_X + 3, ROAD_Y - 3))
	add_prop("sign", Vector2i(ROAD_X - 3, 6), {"solid": false})
	add_prop("sign", Vector2i(8, ROAD_Y - 3), {"solid": false})
	# Fences around the farm field.
	if info.get("farm", true):
		for x in range(45, 59):
			if x != 51 and x != 52:
				add_prop("fence", Vector2i(x, 38))
	# The broken van: fix it to drive to the next area.
	van = add_prop("van", Vector2i(ROAD_X + 6, ROAD_Y + 1))
	# Wrecked cars on the roads give scrap.
	add_prop("car", Vector2i(ROAD_X - 1, 12))
	add_prop("car", Vector2i(60, ROAD_Y))
	# Crates and barrels around the square.
	for c in [Vector2i(ROAD_X - 5, ROAD_Y - 5), Vector2i(ROAD_X + 5, ROAD_Y + 5), Vector2i(29, 23), Vector2i(47, 23)]:
		if can_place_prop(c, [Vector2i.ZERO]):
			add_prop("crate", c)
	for c in [Vector2i(34, 38), Vector2i(41, 37), Vector2i(23, 23)]:
		if can_place_prop(c, [Vector2i.ZERO]):
			add_prop("barrel", c)


func _place_forest() -> void:
	# Openings where the roads leave the map + a few random gaps.
	var gaps: Array[Rect2i] = []
	for i in 3:
		var side := rng.randi_range(0, 3)
		var pos := rng.randi_range(10, 40)
		match side:
			0: gaps.append(Rect2i(pos, 0, 2, FOREST + 1))
			1: gaps.append(Rect2i(pos + 10, H - FOREST - 1, 2, FOREST + 1))
			2: gaps.append(Rect2i(0, pos % (H - 20) + 6, FOREST + 1, 2))
			3: gaps.append(Rect2i(W - FOREST - 1, pos % (H - 20) + 6, FOREST + 1, 2))
	for g in gaps:
		for y in range(g.position.y, g.end.y):
			for x in range(g.position.x, g.end.x):
				reserved[Vector2i(x, y)] = true
	# Spawn cells: road ends and gaps (just inside the map).
	for y in range(ROAD_Y - 1, ROAD_Y + 2):
		spawn_cells.append(Vector2i(0, y))
		spawn_cells.append(Vector2i(W - 1, y))
	for x in range(ROAD_X - 1, ROAD_X + 2):
		spawn_cells.append(Vector2i(x, 0))
		spawn_cells.append(Vector2i(x, H - 1))
	for g in gaps:
		var c := g.position + g.size / 2
		c.x = clampi(c.x, 0, W - 1)
		c.y = clampi(c.y, 0, H - 1)
		if c.x <= FOREST:
			c.x = 0
		elif c.x >= W - FOREST - 1:
			c.x = W - 1
		if c.y <= FOREST:
			c.y = 0
		elif c.y >= H - FOREST - 1:
			c.y = H - 1
		spawn_cells.append(c)

	for y in H:
		for x in W:
			var band := mini(mini(x, y), mini(W - 1 - x, H - 1 - y))
			if band >= FOREST:
				continue
			var c := Vector2i(x, y)
			if reserved.has(c) or occupied.has(c) or g_at(c) != G.GRASS:
				continue
			var dense: float = info.get("trees", 1.0)
			var chance := (0.75 if band <= 1 else 0.45) * clampf(dense, 0.8, 1.3)
			if (x + y) % 2 == 0 and rng.randf() < chance:
				var kind: String = ["tree_round", "tree_round2", "tree_pine", "tree_pine"][rng.randi() % 4]
				add_prop(kind, c)
			elif rng.randf() < 0.12:
				add_prop("bush", c)


func _scatter() -> void:
	var table := [
		["tree_round", 16], ["tree_round2", 12], ["tree_fruit", 6], ["tree_pine", 10],
		["rock", 22], ["rock_big", 8], ["bush", 18], ["bush_berry", 10],
		["log", 9], ["stump", 6], ["crate", 9], ["barrel", 5],
	]
	for entry in table:
		var kind: String = entry[0]
		var target: int = entry[1]
		if kind.begins_with("tree") or kind.begins_with("bush") or kind == "log" or kind == "stump":
			target = int(target * info.get("trees", 1.0))
		elif kind.begins_with("rock"):
			target = int(target * info.get("rocks", 1.0))
		var placed := 0
		var tries := 0
		while placed < target and tries < 600:
			tries += 1
			var c := Vector2i(rng.randi_range(FOREST, W - FOREST - 1), rng.randi_range(FOREST, H - FOREST - 1))
			if c.distance_to(Vector2i(ROAD_X, ROAD_Y + 4)) < 5:
				continue
			var fp: Array = Prop.footprint_of(kind)
			if not can_place_prop(c, fp):
				continue
			# keep one free tile around trees and rocks so paths stay open
			var crowded := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if occupied.has(c + Vector2i(dx, dy)):
						crowded = true
			if crowded:
				continue
			add_prop(kind, c)
			placed += 1


# ------------------------------------------------------------------ structures

func can_build(c: Vector2i) -> bool:
	if not in_bounds(c) or occupied.has(c) or structures.has(c):
		return false
	if g_at(c) == G.WATER or astar.is_point_solid(c):
		return false
	return true

func add_structure(kind: String, c: Vector2i) -> Structure:
	var s := Structure.new()
	s.setup(self, kind, c)
	structures[c] = s
	var info: Dictionary = Res.BUILD[kind]
	astar.set_point_weight_scale(c, info["weight"])
	entities.add_child(s)
	return s

func remove_structure(s: Structure) -> void:
	if structures.get(s.cell) == s:
		structures.erase(s.cell)
		astar.set_point_weight_scale(s.cell, 1.0)

func remove_prop_cells(p: Prop) -> void:
	for c in p.cells:
		if occupied.get(c) == p:
			occupied.erase(c)
			if p.solid:
				astar.set_point_solid(c, false)

## A random free grass cell at least min_dist tiles away from `from` (for waiting survivors).
func far_free_cell(from: Vector2i, min_dist: float) -> Vector2i:
	for i in 400:
		var c := Vector2i(rng.randi_range(FOREST + 1, W - FOREST - 2), rng.randi_range(FOREST + 1, H - FOREST - 2))
		if c.distance_to(from) < min_dist or g_at(c) == G.WATER or occupied.has(c) or astar.is_point_solid(c):
			continue
		var crowded := false
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if occupied.has(c + Vector2i(dx, dy)):
					crowded = true
		if not crowded:
			return c
	return from + Vector2i(6, 6)


func _add_shopkeeper(pos: Vector2) -> void:
	var npc := Node2D.new()
	npc.position = pos
	var sh := Sprite2D.new()
	sh.texture = Res.SHADOW
	sh.z_index = -1
	npc.add_child(sh)
	var spr := Sprite2D.new()
	spr.texture = Res.SHOPKEEPER
	spr.hframes = 6
	spr.vframes = 3
	spr.offset = Vector2(0, -11)
	npc.add_child(spr)
	entities.add_child(npc)
	# idle: look around now and then
	var tw := npc.create_tween().set_loops()
	tw.tween_callback(func(): spr.frame = 0).set_delay(2.0)
	tw.tween_callback(func():
		spr.frame = 12
		spr.flip_h = false).set_delay(1.5)
	tw.tween_callback(func(): spr.frame = 0).set_delay(1.0)
	tw.tween_callback(func():
		spr.frame = 12
		spr.flip_h = true).set_delay(1.8)


func new_day(n: int) -> void:
	day = n
	for e in entities.get_children():
		if e is Prop:
			e.searched = false

func add_splat(pos: Vector2, green := false) -> void:
	var s := Sprite2D.new()
	s.texture = Res.SPLAT
	s.hframes = 4
	s.frame = randi() % 4
	s.position = pos
	s.rotation = randf() * TAU
	if green:
		s.modulate = Color(0.6, 1.0, 0.6)
	decals.add_child(s)
	if decals.get_child_count() > 80:
		decals.get_child(0).queue_free()
	var tw := s.create_tween()
	tw.tween_interval(25.0)
	tw.tween_property(s, "modulate:a", 0.0, 4.0)
	tw.tween_callback(s.queue_free)
