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
}

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
	"sound": 12, "mute": 13,
}

const RESOURCES := ["wood", "stone", "scrap", "ammo", "food"]

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
	var parts: PackedStringArray = []
	var cost: Dictionary = BUILD[kind]["cost"]
	for r in cost:
		parts.append("%d %s" % [cost[r], Lang.t(r)])
	return ", ".join(parts)
