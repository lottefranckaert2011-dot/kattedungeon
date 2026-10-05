class_name World
extends Node2D
## Builds the village map, owns the pathfinding grid and keeps track of
## everything that occupies a tile (props and player-built structures).

const T := 16
const W := 72
const H := 56

enum G { GRASS, DIRT, WATER, COBBLE, SOIL }

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
var home: Prop
var houses: Array = []
var biome := "summer"
var plaza := Vector2i(36, 28)
var plaza_rect := Rect2i()
var farm_rect := Rect2i()
var inside = null          # the house Prop the player is in (or null)
var interiors := {}        # house Prop -> Interior (ground floor)
var inside_room = null     # the Interior (floor) the player is in
var _room_count := 0


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

	y_sort_enabled = true
	decals = Node2D.new()
	decals.z_index = -5
	add_child(decals)
	entities = Node2D.new()
	entities.y_sort_enabled = true
	add_child(entities)

	biome = info.get("biome", "summer")
	_layout_ground()
	_place_village()
	_build_ground_texture()
	_build_water_collision()
	_build_borders()
	_place_forest()
	_scatter()


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
	return g_at(c) == G.DIRT

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
	if not in_bounds(a) or not in_bounds(b):
		return PackedVector2Array()
	if a == b:
		return PackedVector2Array()
	var ids := astar.get_id_path(a, b)
	var pts := PackedVector2Array()
	for i in range(1, ids.size()):
		pts.append(cell_center(ids[i]))
	return pts


# ------------------------------------------------------------------ ground

## Every area gets its own layout: where the square is, which roads leave it,
## a pond and a farm field in random spots.
func _layout_ground() -> void:
	var pw := rng.randi_range(9, 13)
	var ph := rng.randi_range(7, 9)
	if area == 0:
		plaza = Vector2i(36, 28)
	else:
		plaza = Vector2i(rng.randi_range(22, W - 22), rng.randi_range(17, H - 17))
	plaza_rect = Rect2i(plaza.x - pw / 2, plaza.y - ph / 2, pw, ph)

	var dirs: Array = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	if area > 0:
		dirs.shuffle()
		dirs = dirs.slice(0, rng.randi_range(2, 4))
	for d in dirs:
		_carve_road(plaza, d)
	# sometimes a side road branches off towards another edge
	if area > 0 and rng.randf() < 0.6:
		var d0: Vector2i = dirs[0]
		var start := plaza + d0 * rng.randi_range(8, 12)
		var side := Vector2i(d0.y, d0.x) * (1 if rng.randf() < 0.5 else -1)
		_carve_road(start, side)

	for y in range(plaza_rect.position.y, plaza_rect.end.y):
		for x in range(plaza_rect.position.x, plaza_rect.end.x):
			var corner := (x == plaza_rect.position.x or x == plaza_rect.end.x - 1) \
				and (y == plaza_rect.position.y or y == plaza_rect.end.y - 1)
			if not corner:
				set_g(Vector2i(x, y), G.COBBLE)

	if info.get("pond", true):
		_make_pond()
	if info.get("farm", true):
		_make_farm()

	# Keep roads and square free of props.
	for y in H:
		for x in W:
			var c := Vector2i(x, y)
			if g_at(c) != G.GRASS:
				reserved[c] = true
			if g_at(c) == G.WATER:
				astar.set_point_solid(c, true)


## A 3-wide dirt road from `from` in direction `dir` to the edge of the map, with gentle bends.
func _carve_road(from: Vector2i, dir: Vector2i) -> void:
	var p := from
	var side := Vector2i(dir.y, dir.x)
	var steps := 0
	while in_bounds(p):
		for o in range(-1, 2):
			var c := p + side * o
			if g_at(c) != G.COBBLE:
				set_g(c, G.DIRT)
		if rng.randf() < 0.22:
			var w := p + side * (2 if rng.randf() < 0.5 else -2)
			if g_at(w) == G.GRASS:
				set_g(w, G.DIRT)
		p += dir
		steps += 1
		# bend a little once we are away from the square (not too close to the edge)
		var edge_dist := mini(mini(p.x, p.y), mini(W - 1 - p.x, H - 1 - p.y))
		if steps > 7 and edge_dist > FOREST + 2 and rng.randf() < 0.12:
			var np := p + side * (1 if rng.randf() < 0.5 else -1)
			var pd := mini(mini(np.x, np.y), mini(W - 1 - np.x, H - 1 - np.y))
			if pd > FOREST + 2:
				for o in range(-1, 2):
					set_g(p + side * o, G.DIRT)
				p = np


func _make_pond() -> void:
	for attempt in 40:
		var rx := rng.randf_range(5.0, 8.5)
		var ry := rng.randf_range(3.5, 5.5)
		var c := Vector2(rng.randi_range(FOREST + 8, W - FOREST - 9), rng.randi_range(FOREST + 6, H - FOREST - 7))
		if c.distance_to(Vector2(plaza)) < 16.0:
			continue
		var cells: Array[Vector2i] = []
		var ok := true
		for y in range(int(c.y - ry - 1), int(c.y + ry + 2)):
			for x in range(int(c.x - rx - 1), int(c.x + rx + 2)):
				var d := Vector2((x - c.x) / rx, (y - c.y) / ry)
				var wob := sin(x * 1.3) * 0.06 + cos(y * 1.7) * 0.06
				if d.length() < 1.0 + wob:
					var cc := Vector2i(x, y)
					# keep two tiles of grass between the pond and any road
					for dy in range(-2, 3):
						for dx in range(-2, 3):
							if g_at(cc + Vector2i(dx, dy)) != G.GRASS:
								ok = false
					cells.append(cc)
		if ok and cells.size() > 20:
			for cc in cells:
				set_g(cc, G.WATER)
			return


func _make_farm() -> void:
	for attempt in 60:
		var fw := rng.randi_range(9, 13)
		var fh := rng.randi_range(6, 8)
		var r := Rect2i(rng.randi_range(FOREST + 3, W - FOREST - fw - 3), rng.randi_range(FOREST + 4, H - FOREST - fh - 3), fw, fh)
		if Vector2(r.get_center()).distance_to(Vector2(plaza)) < 13.0:
			continue
		var ok := true
		for y in range(r.position.y - 2, r.end.y + 2):
			for x in range(r.position.x - 2, r.end.x + 2):
				if g_at(Vector2i(x, y)) != G.GRASS:
					ok = false
		if not ok:
			continue
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				set_g(Vector2i(x, y), G.SOIL)
		for y in range(r.position.y - 2, r.end.y + 2):
			for x in range(r.position.x - 2, r.end.x + 2):
				if g_at(Vector2i(x, y)) != G.SOIL:
					reserved[Vector2i(x, y)] = true
		farm_rect = r
		return


func _grass_like(c: Vector2i) -> bool:
	return g_at(c) == G.GRASS

func _build_ground_texture() -> void:
	var tiles: Image = Res.season_tiles(biome).get_image()
	var edges: Image = Res.season_edges(biome).get_image()
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
					t = 11 if v % 100 < 7 and biome != "winter" else 9 + (v / 100) % 2
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
	# Houses stand around the square in different spots every time.
	var kinds: Array = ["shop", "mansion" if info.get("mansion", false) else "home"]
	var pool := ["house_red", "house_blue", "house_tan", "house_white"]
	for i in int(info.get("houses", 7)):
		kinds.append(pool[rng.randi() % pool.size()])
	for k in kinds:
		var best = null
		var best_d := INF
		var hs := Prop.house_size(k)
		for i in 200:
			var tl := Vector2i(rng.randi_range(FOREST + 2, W - FOREST - hs.x - 2), rng.randi_range(FOREST + 3, H - FOREST - hs.y - 3))
			if not _house_lot_ok(tl, hs):
				continue
			var d := Vector2(tl + Vector2i(hs.x / 2, hs.y)).distance_to(Vector2(plaza)) + rng.randf() * 8.0
			if d < best_d:
				best_d = d
				best = tl
		if best == null:
			continue
		var tl: Vector2i = best
		var house := add_prop(k, tl + Vector2i(0, hs.y - 1))
		houses.append(house)
		if k == "shop":
			shop = house
			_add_shopkeeper(house.position + Vector2(-22, 6))
		elif k == "home" or k == "mansion":
			home = house
		# little dirt patch in front of the door
		for x in range(tl.x + hs.x / 2 - 1, tl.x + hs.x / 2 + 1):
			set_g(Vector2i(x, tl.y + hs.y), G.DIRT)
			reserved[Vector2i(x, tl.y + hs.y)] = true
			reserved[Vector2i(x, tl.y + hs.y + 1)] = true
		if rng.randf() < 0.5 and can_place_prop(tl + Vector2i(-1, hs.y - 1), [Vector2i.ZERO]):
			add_prop("crate" if rng.randf() < 0.5 else "barrel", tl + Vector2i(-1, hs.y - 1))

	# Square: your van and a well.
	van = add_prop("van", Vector2i(plaza_rect.position.x + 1, plaza_rect.position.y + 1))
	add_prop("well", Vector2i(plaza_rect.end.x - 3, plaza_rect.position.y + 1))
	if home:
		player_start = home.interact_point() + Vector2(0, 12)
	else:
		player_start = cell_center(plaza)

	# Fences along the farm field.
	if farm_rect.size != Vector2i.ZERO:
		var gap := farm_rect.position.x + farm_rect.size.x / 2
		for x in range(farm_rect.position.x - 1, farm_rect.end.x + 1):
			if abs(x - gap) > 1:
				add_prop("fence", Vector2i(x, farm_rect.position.y - 1))

	# Wrecked cars on the roads give scrap.
	var placed := 0
	for i in 200:
		if placed >= 2:
			break
		var c := Vector2i(rng.randi_range(2, W - 5), rng.randi_range(2, H - 3))
		if Vector2(c).distance_to(Vector2(plaza)) < 9.0:
			continue
		var ok := true
		for dx in 3:
			var cc := c + Vector2i(dx, 0)
			if g_at(cc) != G.DIRT or occupied.has(cc):
				ok = false
		if ok:
			add_prop("car", c)
			placed += 1


func _house_lot_ok(tl: Vector2i, hs := Vector2i(4, 4)) -> bool:
	for y in range(tl.y - 1, tl.y + hs.y + 2):
		for x in range(tl.x - 1, tl.x + hs.x + 1):
			var c := Vector2i(x, y)
			if not in_bounds(c) or g_at(c) != G.GRASS or reserved.has(c) or occupied.has(c):
				return false
	return true


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
	# Spawn cells: where the roads leave the map, plus the gaps (just inside the map).
	for x in W:
		for y in [0, H - 1]:
			if g_at(Vector2i(x, y)) == G.DIRT:
				spawn_cells.append(Vector2i(x, y))
	for y in H:
		for x in [0, W - 1]:
			if g_at(Vector2i(x, y)) == G.DIRT:
				spawn_cells.append(Vector2i(x, y))
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
			if Vector2(c).distance_to(player_start / T) < 5.0:
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


## The room behind a house door (built the first time you go in).
func get_interior(h) -> Interior:
	if not interiors.has(h):
		var floors: Array = []
		for f in int(h.def.get("floors", 1)):
			var it := Interior.new()
			it.y_sort_enabled = true
			add_child(it)
			it.setup(self, h, _room_count, f, floors)
			_room_count += 1
			floors.append(it)
		interiors[h] = floors[0]
	return interiors[h]


func new_day(n: int) -> void:
	for h in houses:
		if h.door:
			h.door.repair()
	for h in interiors:
		for room in interiors[h].floors:
			room.refill()
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
