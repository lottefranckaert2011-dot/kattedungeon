class_name Prop
extends StaticBody2D
## Everything that stands on the map: trees, rocks, crates, houses, cars...
## Some can be chopped/mined with the axe, some can be searched with E.

const DEFS := {
	"tree_round": {"hp": 5, "tool": "chop", "loot": {"wood": [3, 4]}, "leaves": "stump", "col": Vector2(10, 6)},
	"tree_round2": {"hp": 5, "tool": "chop", "loot": {"wood": [3, 4]}, "leaves": "stump", "col": Vector2(10, 6)},
	"tree_fruit": {"hp": 5, "tool": "chop", "loot": {"wood": [2, 3], "food": [1, 2]}, "leaves": "stump", "col": Vector2(10, 6)},
	"tree_pine": {"hp": 4, "tool": "chop", "loot": {"wood": [2, 3]}, "leaves": "stump", "col": Vector2(6, 5)},
	"bush": {"hp": 1, "tool": "chop", "loot": {"wood": [1, 1]}, "col": Vector2(12, 6)},
	"bush_berry": {"hp": 1, "tool": "chop", "loot": {"wood": [1, 1], "food": [1, 1]}, "col": Vector2(12, 6)},
	"rock": {"hp": 4, "tool": "mine", "loot": {"stone": [2, 3]}, "col": Vector2(12, 6)},
	"rock_big": {"hp": 7, "tool": "mine", "loot": {"stone": [4, 6], "scrap": [0, 1]}, "col": Vector2(16, 8)},
	"log": {"hp": 2, "tool": "chop", "loot": {"wood": [2, 3]}, "col": Vector2(22, 6), "fp": [Vector2i(0, 0), Vector2i(1, 0)]},
	"stump": {"hp": 2, "tool": "chop", "loot": {"wood": [1, 2]}, "col": Vector2(12, 6)},
	"fence": {"hp": 2, "tool": "chop", "loot": {"wood": [1, 1]}, "col": Vector2(16, 5)},
	"crate": {"hp": 2, "tool": "chop", "loot": {}, "random_loot": 3, "search": "crate", "col": Vector2(12, 8)},
	"barrel": {"hp": 2, "tool": "chop", "loot": {}, "random_loot": 2, "search": "crate", "col": Vector2(10, 7)},
	"car": {"hp": -1, "loot": {}, "random_loot": 3, "search": "car", "col": Vector2(36, 10), "fp": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]},
	"well": {"hp": -1, "col": Vector2(20, 9), "fp": [Vector2i(0, 0), Vector2i(1, 0)]},
	"sign": {"hp": 1, "tool": "chop", "loot": {"wood": [1, 1]}, "col": Vector2(4, 3)},
	"house_red": {"hp": -1, "enter": true, "col": Vector2(56, 24), "house": true},
	"house_blue": {"hp": -1, "enter": true, "col": Vector2(56, 24), "house": true},
	"house_tan": {"hp": -1, "enter": true, "col": Vector2(56, 24), "house": true},
	"house_white": {"hp": -1, "enter": true, "col": Vector2(56, 24), "house": true},
	"shop": {"hp": -1, "col": Vector2(56, 24), "house": true, "shop": true},
	"home": {"hp": -1, "enter": true, "col": Vector2(56, 24), "house": true, "home": true},
	"mansion": {"hp": -1, "enter": true, "col": Vector2(88, 28), "house": true, "home": true,
		"size": Vector2i(6, 7), "floors": 3},
	"van": {"hp": -1, "col": Vector2(40, 10), "van": true, "fp": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]},
}

var world
var kind := ""
var def: Dictionary
var cell := Vector2i.ZERO
var cells: Array[Vector2i] = []
var hp := 1
var solid := true
var searched := false
var repaired := false
var door: HouseDoor = null
var sprite: Sprite2D
var _smoke: CPUParticles2D
var _shake := 0.0


## Size of a house in tiles (width, height of the picture).
static func house_size(k: String) -> Vector2i:
	return DEFS.get(k, {}).get("size", Vector2i(4, 4))


static func footprint_of(k: String) -> Array:
	var d: Dictionary = DEFS.get(k, {})
	if d.get("house", false):
		var fp := []
		for y in range(-1, 1):
			for x in range(house_size(k).x):
				fp.append(Vector2i(x, y))
		return fp
	return d.get("fp", [Vector2i.ZERO])


func setup(w, k: String, c: Vector2i, extra := {}) -> void:
	world = w
	kind = k
	def = DEFS.get(k, {})
	cell = c
	hp = def.get("hp", 1)
	solid = extra.get("solid", true)
	collision_layer = 1 if solid else 0
	collision_mask = 0

	var fp: Array = footprint_of(k)
	var width_cells := 1
	for f in fp:
		width_cells = maxi(width_cells, f.x + 1)
	for f in fp:
		var cc: Vector2i = c + f
		cells.append(cc)
		world.occupied[cc] = self
		if solid:
			world.set_solid(cc, true)
	if def.get("house", false):
		# reserve the roof area so nothing spawns hidden under it
		var hs := house_size(k)
		for y in range(-(hs.y - 1), 2):
			for x in range(-1, hs.x + 1):
				world.reserved[c + Vector2i(x, y)] = true

	position = Vector2(c.x * 16 + width_cells * 8, c.y * 16 + 14)
	var tex: Texture2D = Res.prop_tex(k, world.biome)
	var shadow := Sprite2D.new()
	shadow.texture = Res.SHADOW
	shadow.z_index = -1
	shadow.scale = Vector2(width_cells * 1.1, 1.2)
	if not def.get("house", false) and k != "sign":
		add_child(shadow)
	sprite = Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	var bottom_pad := 2
	if def.get("house", false):
		bottom_pad = 4
	sprite.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height() + bottom_pad)
	add_child(sprite)

	if solid:
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = def.get("col", Vector2(12, 6))
		cs.shape = rs
		cs.position = Vector2(0, -rs.size.y / 2.0 + 1)
		if def.get("house", false):
			cs.position = Vector2(0, -rs.size.y / 2.0)
		add_child(cs)

	if def.get("enter", false):
		door = HouseDoor.new()
		door.setup(self, 1000.0 if def.get("home", false) else 120.0)
		add_child(door)

	if def.get("van", false):
		_smoke = CPUParticles2D.new()
		_smoke.texture = Res.SMOKE
		_smoke.position = Vector2(13, -22)
		_smoke.amount = 10
		_smoke.lifetime = 1.6
		_smoke.direction = Vector2.UP
		_smoke.spread = 25.0
		_smoke.gravity = Vector2(4, -8)
		_smoke.initial_velocity_min = 6.0
		_smoke.initial_velocity_max = 12.0
		_smoke.scale_amount_min = 0.6
		_smoke.scale_amount_max = 1.3
		_smoke.color = Color(0.75, 0.75, 0.78, 0.7)
		add_child(_smoke)


## The repairable van: swap to the fixed sprite and stop smoking.
func repair(effects := true) -> void:
	repaired = true
	sprite.texture = Res.VAN_FIXED
	if _smoke:
		_smoke.emitting = false
		_smoke.visible = false
	if not effects:
		return
	Fx.burst(world, global_position + Vector2(0, -10), Color(1.0, 0.9, 0.5), 14, 60.0)
	sprite.scale = Vector2(1.15, 0.85)
	create_tween().tween_property(sprite, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if _shake > 0:
		_shake = maxf(0.0, _shake - delta)
		sprite.position.x = sin(_shake * 80.0) * 2.0 * (_shake / 0.25)
	else:
		set_process(false)


func can_harvest() -> bool:
	return hp > 0 and def.has("tool")


## Point used for "is the axe close enough" checks.
func hit_point() -> Vector2:
	return global_position + Vector2(0, -6)


func interact_point() -> Vector2:
	if def.get("house", false):
		return global_position + Vector2(0, 2)
	if def.get("van", false):
		return global_position + Vector2(0, 2)
	return global_position


func can_search() -> bool:
	return def.has("search") and not searched


func harvest_hit(dmg := 1) -> void:
	if not can_harvest():
		return
	hp -= dmg
	_shake = 0.25
	set_process(true)
	Audio.play(def["tool"], -2.0, 0.12, global_position)
	if hp <= 0:
		_drop_loot()
		if def.has("leaves"):
			world.remove_prop_cells(self)
			var stump = world.add_prop(def["leaves"], cell)
			stump.modulate.a = 0.0
			stump.create_tween().tween_property(stump, "modulate:a", 1.0, 0.3)
		else:
			world.remove_prop_cells(self)
		Audio.play("break", -8.0, 0.1, global_position)
		_die()


## Search with E. Returns the loot dictionary (may be empty).
func search() -> Dictionary:
	if not can_search():
		return {}
	searched = true
	Audio.play("search_house" if def["search"] == "house" else "search_crate", -2.0)
	var loot := _roll_random_loot(def.get("random_loot", 2))
	if def["search"] == "crate":
		world.remove_prop_cells(self)
		_die()
	return loot


func _roll_random_loot(rolls: int) -> Dictionary:
	var loot := {}
	var day: int = world.day
	for i in rolls:
		var r := randf()
		var key := ""
		var amount := 1
		if r < 0.32:
			key = "scrap"
			amount = randi_range(1, 2)
		elif r < 0.62:
			key = "ammo"
			amount = randi_range(3, 6) + mini(day, 4)
		elif r < 0.8:
			key = "food"
		elif r < 0.88:
			key = "coins"
			amount = randi_range(3, 8)
		elif r < 0.96:
			key = "wood"
			amount = randi_range(1, 3)
		else:
			continue
		loot[key] = loot.get(key, 0) + amount
	return loot


func _drop_loot() -> void:
	var loot: Dictionary = {}
	var base: Dictionary = def.get("loot", {})
	for k in base:
		var n := randi_range(base[k][0], base[k][1])
		if n > 0:
			loot[k] = n
	if def.has("random_loot"):
		var extra := _roll_random_loot(def["random_loot"])
		for k in extra:
			loot[k] = loot.get(k, 0) + extra[k]
	for k in loot:
		for i in loot[k]:
			Pickup.spawn(world, k, 1, hit_point())


func _die() -> void:
	collision_layer = 0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(queue_free)
