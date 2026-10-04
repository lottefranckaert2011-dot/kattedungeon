class_name Res
## Central place for preloaded textures and game balance values.

const TILES := preload("res://assets/sprites/tiles.png")
const EDGES := preload("res://assets/sprites/edges.png")
const ITEMS := preload("res://assets/sprites/items.png")
const SHADOW := preload("res://assets/sprites/shadow.png")
const SLASH := preload("res://assets/sprites/slash.png")
const BULLET := preload("res://assets/sprites/bullet.png")
const SPLAT := preload("res://assets/sprites/splat.png")
const AXE := preload("res://assets/sprites/axe.png")
const PISTOL := preload("res://assets/sprites/pistol.png")
const PLAYER := preload("res://assets/sprites/player.png")

const PROPS := {
	"tree_round": preload("res://assets/sprites/tree_round.png"),
	"tree_round2": preload("res://assets/sprites/tree_round2.png"),
	"tree_fruit": preload("res://assets/sprites/tree_fruit.png"),
	"tree_pine": preload("res://assets/sprites/tree_pine.png"),
	"bush": preload("res://assets/sprites/bush.png"),
	"bush_berry": preload("res://assets/sprites/bush_berry.png"),
	"rock": preload("res://assets/sprites/rock.png"),
	"rock_big": preload("res://assets/sprites/rock_big.png"),
	"log": preload("res://assets/sprites/log.png"),
	"stump": preload("res://assets/sprites/stump.png"),
	"fence": preload("res://assets/sprites/fence.png"),
	"crate": preload("res://assets/sprites/crate.png"),
	"barrel": preload("res://assets/sprites/barrel.png"),
	"car": preload("res://assets/sprites/car.png"),
	"sign": preload("res://assets/sprites/sign.png"),
	"well": preload("res://assets/sprites/well.png"),
	"house_red": preload("res://assets/sprites/house_red.png"),
	"house_blue": preload("res://assets/sprites/house_blue.png"),
	"house_tan": preload("res://assets/sprites/house_tan.png"),
	"house_white": preload("res://assets/sprites/house_white.png"),
	"shop": preload("res://assets/sprites/shop.png"),
	"van": preload("res://assets/sprites/van_broken.png"),
}
const VAN_FIXED := preload("res://assets/sprites/van.png")
const SMOKE := preload("res://assets/sprites/smoke.png")
const SHOPKEEPER := preload("res://assets/sprites/shopkeeper.png")
const WEAPON_SHEET := preload("res://assets/sprites/weapons.png")

## Survivors you can find in the areas. They follow you and help.
const SURVIVORS := {
	"shooter": {"name": "Sam", "tex": preload("res://assets/sprites/survivor_shooter.png"), "hp": 80.0, "speed": 70.0},
	"fighter": {"name": "Noor", "tex": preload("res://assets/sprites/survivor_fighter.png"), "hp": 120.0, "speed": 74.0},
	"medic": {"name": "Mila", "tex": preload("res://assets/sprites/survivor_medic.png"), "hp": 75.0, "speed": 70.0},
	"builder": {"name": "Bram", "tex": preload("res://assets/sprites/survivor_builder.png"), "hp": 95.0, "speed": 68.0},
}
const SURVIVOR_ORDER := ["shooter", "fighter", "medic", "builder"]
const MAX_ALLIES := 4

const STRUCT_TEX := {
	"barricade": preload("res://assets/sprites/barricade.png"),
	"wall": preload("res://assets/sprites/wall_stone.png"),
	"spikes": preload("res://assets/sprites/spikes.png"),
	"turret": preload("res://assets/sprites/turret_base.png"),
	"campfire": preload("res://assets/sprites/campfire.png"),
}
const TURRET_GUN := preload("res://assets/sprites/turret_gun.png")

const ZOMBIE_TEX := {
	"zombie_farmer": preload("res://assets/sprites/zombie_farmer.png"),
	"zombie_cap": preload("res://assets/sprites/zombie_cap.png"),
	"zombie_granny": preload("res://assets/sprites/zombie_granny.png"),
	"zombie_girl": preload("res://assets/sprites/zombie_girl.png"),
	"zombie_worker": preload("res://assets/sprites/zombie_worker.png"),
	"zombie_runner": preload("res://assets/sprites/zombie_runner.png"),
	"zombie_brute": preload("res://assets/sprites/zombie_brute.png"),
}

## Index of each 12x12 icon inside items.png
const ICON := {
	"wood": 0, "stone": 1, "scrap": 2, "ammo": 3, "food": 4, "heart": 5,
	"skull": 6, "moon": 7, "sun": 8, "zombie": 9, "axe": 10, "gun": 11,
	"sound": 12, "mute": 13, "coins": 14,
}

const RESOURCES := ["wood", "stone", "scrap", "ammo", "food", "coins"]

## Weapons. Melee: damage per swing, chop = damage to trees/rocks.
## Guns: damage per bullet, pellets per shot, spread in radians.
const WEAPON_INDEX := {"axe": 0, "bat": 1, "machete": 2, "chainsaw": 3, "pistol": 4, "shotgun": 5, "smg": 6}
const WEAPONS := {
	"axe": {"melee": true, "damage": 14.0, "cooldown": 0.34, "range": 22.0, "knock": 160.0, "chop": 1},
	"bat": {"melee": true, "damage": 19.0, "cooldown": 0.36, "range": 25.0, "knock": 320.0, "chop": 1},
	"machete": {"melee": true, "damage": 27.0, "cooldown": 0.26, "range": 24.0, "knock": 140.0, "chop": 2},
	"chainsaw": {"melee": true, "damage": 13.0, "cooldown": 0.09, "range": 21.0, "knock": 50.0, "chop": 3},
	"pistol": {"melee": false, "damage": 22.0, "cooldown": 0.28, "pellets": 1, "spread": 0.04},
	"shotgun": {"melee": false, "damage": 13.0, "cooldown": 0.7, "pellets": 6, "spread": 0.32},
	"smg": {"melee": false, "damage": 14.0, "cooldown": 0.09, "pellets": 1, "spread": 0.12},
}

## Items in the weapon shop (prices in coins).
const SHOP := [
	{"id": "bat", "price": 25},
	{"id": "machete", "price": 60},
	{"id": "chainsaw", "price": 150},
	{"id": "shotgun", "price": 80},
	{"id": "smg", "price": 140},
	{"id": "ammo_pack", "price": 10, "give": {"ammo": 20}},
	{"id": "food_pack", "price": 8, "give": {"food": 2}},
]

## Areas you can drive to with the repaired van. After the last one they repeat (harder).
const AREAS := [
	{"nl": "Het Dorp", "en": "The Village", "tint": Color(1, 1, 1), "houses": 7, "trees": 1.0, "rocks": 1.0, "pond": true, "farm": true},
	{"nl": "Het Donkere Bos", "en": "The Dark Forest", "tint": Color(0.8, 0.93, 0.84), "houses": 3, "trees": 2.2, "rocks": 0.8, "pond": true, "farm": false},
	{"nl": "De Oude Boerderij", "en": "The Old Farm", "tint": Color(1.0, 0.95, 0.82), "houses": 4, "trees": 0.7, "rocks": 0.7, "pond": false, "farm": true},
	{"nl": "De Rotsvallei", "en": "Rocky Valley", "tint": Color(0.95, 0.9, 0.86), "houses": 4, "trees": 0.6, "rocks": 2.6, "pond": true, "farm": false},
]

static func area_info(i: int) -> Dictionary:
	return AREAS[i % AREAS.size()]

static func area_name(i: int) -> String:
	var a := area_info(i)
	var n: String = a["nl"] if Lang.lang == "nl" else a["en"]
	if i >= AREAS.size():
		n += " %d" % (i / AREAS.size() + 1)
	return n

## Scrap/wood/stone needed to fix the van in area i.
static func van_cost(i: int) -> Dictionary:
	return {"scrap": 8 + 4 * i, "wood": 6 + 2 * i, "stone": 3 + i}

static var _weapon_cache := {}

static func weapon_icon(id: String) -> AtlasTexture:
	if _weapon_cache.has(id):
		return _weapon_cache[id]
	var at := AtlasTexture.new()
	at.atlas = WEAPON_SHEET
	at.region = Rect2(WEAPON_INDEX.get(id, 0) * 16, 0, 16, 16)
	_weapon_cache[id] = at
	return at

## Buildings: cost, hit points and whether zombies have to break through them.
const BUILD := {
	"barricade": {"cost": {"wood": 4}, "hp": 80, "blocks": true, "weight": 6.0},
	"wall": {"cost": {"stone": 4, "wood": 1}, "hp": 220, "blocks": true, "weight": 12.0},
	"spikes": {"cost": {"wood": 2, "scrap": 2}, "hp": 40, "blocks": false, "weight": 1.0},
	"turret": {"cost": {"scrap": 5, "wood": 3, "stone": 2}, "hp": 90, "blocks": true, "weight": 8.0},
	"campfire": {"cost": {"wood": 5, "stone": 2}, "hp": 60, "blocks": false, "weight": 1.0},
}
const BUILD_ORDER := ["barricade", "wall", "spikes", "turret", "campfire"]

const ZOMBIE_TYPES := {
	"walker": {"hp": 32.0, "speed": 24.0, "damage": 8.0, "struct_damage": 8.0, "score": 10},
	"runner": {"hp": 20.0, "speed": 46.0, "damage": 6.0, "struct_damage": 5.0, "score": 15},
	"brute": {"hp": 120.0, "speed": 17.0, "damage": 20.0, "struct_damage": 28.0, "score": 35},
}
const WALKER_SKINS := ["zombie_farmer", "zombie_cap", "zombie_granny", "zombie_girl", "zombie_worker"]

static var _icon_cache := {}

static func icon(name: String) -> AtlasTexture:
	if _icon_cache.has(name):
		return _icon_cache[name]
	var at := AtlasTexture.new()
	at.atlas = ITEMS
	at.region = Rect2(ICON.get(name, 0) * 12, 0, 12, 12)
	_icon_cache[name] = at
	return at

static func cost_text(kind: String) -> String:
	return dict_text(BUILD[kind]["cost"])

static func dict_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for r in cost:
		parts.append("%d %s" % [cost[r], Lang.t(r)])
	return ", ".join(parts)
