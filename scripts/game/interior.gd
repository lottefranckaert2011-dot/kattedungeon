class_name Interior
extends Node2D
## The inside of a house: a room with furniture. Cupboards, chests and
## bookshelves can be searched (scrap, ammo, coins, food and sometimes a weapon).
## Your own home is cosy: beds for your team and a fireplace, and you heal there.
##
## Rooms live in the same world, far below the map, so the player and the
## survivors simply walk around in them.

const RW := 16          # room size in tiles
const RH := 11
const T := 16

var world
var house
var is_home := false
var containers: Array = []
var spawn_pos := Vector2.ZERO
var exit_pos := Vector2.ZERO
var center := Vector2.ZERO
var furniture: Node2D
var floor_i := 0              # 0 = ground floor
var floors: Array = []      # all floors of this house (shared array)
var stairs: Array = []

# Furniture layouts in tile coordinates (x, y = bottom of the piece).
const LAYOUTS := [
	[["bed", 1.5, 4.6], ["cupboard", 4.0, 4.6], ["shelf", 13.0, 4.6], ["table", 8.0, 7.2], ["chair", 6.2, 7.0],
	 ["chair", 9.8, 7.0], ["chest", 13.6, 9.6], ["plant", 1.0, 9.8], ["rug", 8.0, 9.4]],
	[["fireplace", 8.0, 4.6], ["shelf", 2.0, 4.6], ["cupboard", 14.0, 4.6], ["bed_blue", 13.5, 8.0],
	 ["chest", 2.2, 8.8], ["table", 6.0, 8.0], ["chair", 4.4, 7.8], ["plant", 10.5, 4.6]],
	[["bed", 1.4, 4.6], ["bed_blue", 2.6, 4.6], ["cupboard", 6.0, 4.6], ["shelf", 9.0, 4.6], ["chest", 14.0, 5.0],
	 ["table", 10.5, 8.2], ["chair", 12.3, 8.0], ["chest", 3.0, 9.4], ["rug", 6.0, 9.0]],
]
const HOME_LAYOUT := [
	["fireplace", 8.0, 4.6], ["bed", 1.4, 4.6], ["bed_blue", 2.6, 4.6], ["bed", 13.4, 4.6], ["bed_blue", 14.6, 4.6],
	["rug", 8.0, 8.6], ["table", 8.0, 7.6], ["chair", 6.2, 7.4], ["chair", 9.8, 7.4], ["plant", 1.0, 9.8],
	["plant", 15.0, 9.8], ["shelf", 5.0, 4.6],
]
## The big manor house: living room, bedrooms and the attic.
const MANOR_LAYOUTS := [
	[["fireplace", 8.0, 4.6], ["sofa", 8.0, 8.0], ["rug", 8.0, 9.8], ["table", 3.5, 8.0], ["chair", 1.8, 7.8],
	 ["chair", 5.2, 7.8], ["shelf", 11.0, 4.6], ["plant", 1.0, 4.6], ["plant", 15.0, 9.8], ["stairs_up", 14.0, 4.6]],
	[["bed", 1.4, 4.6], ["bed_blue", 2.6, 4.6], ["cupboard", 5.0, 4.6], ["shelf", 8.0, 4.6], ["bed", 10.4, 4.6],
	 ["bed_blue", 11.6, 4.6], ["chest", 2.5, 9.4], ["rug", 7.5, 8.8], ["cupboard", 6.2, 9.6], ["stairs_up", 14.4, 4.6],
	 ["stairs_down", 14.0, 8.4]],
	[["box", 1.2, 4.6], ["box", 2.3, 4.6], ["box", 1.6, 5.6], ["chest", 5.0, 4.8], ["treasure", 8.0, 5.2],
	 ["chest", 11.0, 4.8], ["box", 13.0, 9.6], ["cupboard", 4.0, 9.6], ["stairs_down", 14.0, 8.4]],
]
const FLOOR_LOOK := [["home", "_home"], ["c", ""], ["attic", "_attic"]]
const SEARCHABLE := ["cupboard", "chest", "shelf", "treasure"]


func setup(w, h, index: int, floor_index := 0, all_floors: Array = []) -> void:
	world = w
	house = h
	floor_i = floor_index
	floors = all_floors
	is_home = h.def.get("home", false)
	var manor: bool = h.def.get("floors", 1) > 1
	position = Vector2(index * (RW * T + 200), World.H * T + 400)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(h.position.x * 31 + h.position.y * 17) + world.area * 101

	var paper: String = "home" if is_home else ["a", "b", "c"][rng.randi() % 3]
	var floor_suffix := "_home" if is_home else ""
	if manor:
		paper = FLOOR_LOOK[floor_i][0]
		floor_suffix = FLOOR_LOOK[floor_i][1]
	_build_room(paper, floor_suffix, rng)
	_build_walls()

	furniture = Node2D.new()
	furniture.y_sort_enabled = true
	add_child(furniture)
	var layout: Array = HOME_LAYOUT if is_home else LAYOUTS[rng.randi() % LAYOUTS.size()]
	if manor:
		layout = MANOR_LAYOUTS[floor_i]
	for f in layout:
		_add_furniture(f[0], Vector2(f[1] * T, f[2] * T))

	exit_pos = global_position + Vector2(RW * T / 2.0, RH * T + 6)
	spawn_pos = global_position + Vector2(RW * T / 2.0, RH * T - 14)
	center = global_position + Vector2(RW * T / 2.0, RH * T / 2.0 + 8)
	if is_home and floor_i == 0:
		var light := PointLight2D.new()
		light.texture = Lights.radial(200)
		light.color = Color(1.0, 0.75, 0.45)
		light.energy = 0.9
		light.position = Vector2(8.0 * T, 3.6 * T)
		add_child(light)


func _build_room(paper: String, floor_suffix: String, rng: RandomNumberGenerator) -> void:
	var img := Image.create(RW * T, RH * T + 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.16, 0.1, 0.08))
	var wall: Image = Res.tex("res://assets/sprites/in_wall_%s.png" % paper).get_image()
	var floor_tex: Image = Res.tex("res://assets/sprites/in_floor%s.png" % floor_suffix).get_image()
	wall.convert(Image.FORMAT_RGBA8)
	floor_tex.convert(Image.FORMAT_RGBA8)
	for x in RW:
		var window := (x == 3 or x == RW - 4) and rng.randf() < 0.85
		img.blit_rect(wall, Rect2i(16 if window else 0, 0, 16, 32), Vector2i(x * T, 0))
	for y in range(2, RH):
		for x in RW:
			img.blit_rect(floor_tex, Rect2i(0, 0, 16, 16), Vector2i(x * T, y * T))
	# doorway at the bottom (only on the ground floor)
	if floor_i == 0:
		var mat: Image = Res.tex("res://assets/sprites/in_exit.png").get_image()
		mat.convert(Image.FORMAT_RGBA8)
		img.blend_rect(mat, Rect2i(0, 0, 20, 8), Vector2i(RW * T / 2 - 10, RH * T))
	var spr := Sprite2D.new()
	spr.texture = ImageTexture.create_from_image(img)
	spr.centered = false
	spr.z_index = -10
	add_child(spr)
	# dark frame around the room
	var frame := ColorRect.new()
	frame.color = Color(0.06, 0.04, 0.05)
	frame.position = Vector2(-6, -6)
	frame.size = Vector2(RW * T + 12, RH * T + 20)
	frame.z_index = -11
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)


func _build_walls() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	add_child(body)
	var w := RW * T
	var h := RH * T
	var gap := 12.0
	var rects := [
		Rect2(0, 0, w, 34),                         # back wall
		Rect2(-16, 0, 16, h + 24),                  # left
		Rect2(w, 0, 16, h + 24),                    # right
		Rect2(0, h, w / 2.0 - gap, 16),             # bottom left of the door
		Rect2(w / 2.0 + gap, h, w / 2.0 - gap, 16), # bottom right of the door
		Rect2(0, h + 12, w, 16),                    # behind the doorway
	]
	if floor_i > 0:
		rects.append(Rect2(w / 2.0 - gap, h - 2, gap * 2.0, 16))  # no door upstairs
	for r in rects:
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = r.size
		cs.shape = rs
		cs.position = r.position + r.size / 2.0
		body.add_child(cs)


func _add_furniture(kind: String, pos: Vector2) -> void:
	var f := Furniture.new()
	f.setup(kind, pos, kind in SEARCHABLE and (not is_home or floor_i > 0))
	furniture.add_child(f)
	if f.searchable:
		containers.append(f)
	if f.is_stairs():
		stairs.append(f)


## True when the player stands in the doorway (walking out).
func at_exit(p: Vector2) -> bool:
	return floor_i == 0 and p.y > exit_pos.y - 8.0 and abs(p.x - exit_pos.x) < 14.0


func nearest_stairs(p: Vector2, max_d: float) -> Furniture:
	for s in stairs:
		var at: Vector2 = s.global_position + (Vector2(0, 4) if s.kind == "stairs_up" else Vector2(0, -6))
		if at.distance_to(p) < max_d:
			return s
	return null


## Where you arrive on this floor when you take the stairs.
func arrival(from_below: bool) -> Vector2:
	for s in stairs:
		if from_below and s.kind == "stairs_down":
			return s.global_position + Vector2(-20, 4)
		if not from_below and s.kind == "stairs_up":
			return s.global_position + Vector2(-18, 12)
	return spawn_pos


func nearest_container(p: Vector2, max_d: float) -> Furniture:
	var best: Furniture = null
	var bd := max_d
	for c in containers:
		if c.searched:
			continue
		var d: float = c.global_position.distance_to(p)
		if d < bd:
			bd = d
			best = c
	return best


## New day: the cupboards are full again.
func refill() -> void:
	for c in containers:
		c.set_searched(false)


static func roll_loot(day: int) -> Dictionary:
	var loot := {}
	for i in 2:
		var r := randf()
		if r < 0.38:
			loot["scrap"] = loot.get("scrap", 0) + randi_range(2, 4)
		elif r < 0.6:
			loot["ammo"] = loot.get("ammo", 0) + randi_range(4, 8) + mini(day, 6)
		elif r < 0.8:
			loot["coins"] = loot.get("coins", 0) + randi_range(4, 10)
		elif r < 0.92:
			loot["food"] = loot.get("food", 0) + 1
		else:
			loot["weapon"] = 1
	return loot
