class_name Minimap
extends Control
## Small map in the corner: one pixel per tile. Shows the shop, the van,
## your team, people shouting HELP!, your buildings and zombies.

const BORDER := 2

var world
var _base: ImageTexture
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Builds the background picture of the map (call again after travelling).
func set_world(w) -> void:
	world = w
	var img := Image.create(World.W, World.H, false, Image.FORMAT_RGBA8)
	var colors := {
		World.G.GRASS: Color8(92, 150, 72), World.G.DIRT: Color8(160, 116, 78),
		World.G.WATER: Color8(70, 120, 196), World.G.COBBLE: Color8(150, 148, 142),
		World.G.SOIL: Color8(112, 76, 52),
	}
	for y in World.H:
		for x in World.W:
			img.set_pixel(x, y, colors.get(world.g_at(Vector2i(x, y)), Color8(92, 150, 72)))
	for c in world.occupied:
		var p = world.occupied[c]
		var col := Color8(44, 96, 50)
		if p.kind.begins_with("rock"):
			col = Color8(126, 126, 136)
		elif p.def.get("shop", false):
			col = Color8(170, 110, 200)
		elif p.def.get("home", false):
			col = Color8(90, 220, 120)
		elif p.def.get("house", false):
			col = Color8(196, 136, 84)
		elif p.kind in ["crate", "barrel", "car", "fence", "well", "sign", "log", "stump"]:
			col = Color8(140, 100, 64)
		elif p.def.get("van", false):
			continue
		img.set_pixel(c.x, c.y, col)
	_base = ImageTexture.create_from_image(img)
	custom_minimum_size = Vector2(World.W + BORDER * 2, World.H + BORDER * 2)
	size = custom_minimum_size
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if is_visible_in_tree():
		queue_redraw()


func _dot(world_pos: Vector2, col: Color, s := 2) -> void:
	var p := Vector2(BORDER, BORDER) + world_pos / float(World.T) - Vector2(s, s) / 2.0
	draw_rect(Rect2(p.floor(), Vector2(s, s)), col)


func _draw() -> void:
	if world == null or not is_instance_valid(world) or _base == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.07, 0.1, 0.9))
	draw_texture(_base, Vector2(BORDER, BORDER), Color(1, 1, 1, 0.9))
	for c in world.structures:
		_dot(world.cell_center(c), Color8(230, 200, 140), 1)
	var blink := int(_t * 4.0) % 2 == 0
	for z in world.zombies:
		if not z.dead:
			_dot(z.global_position, Color8(230, 50, 50), 1)
	if world.shop:
		_dot(world.shop.global_position + Vector2(0, -8), Color8(220, 140, 255) if blink else Color8(150, 90, 190), 4)
	if world.van:
		_dot(world.van.global_position, Color8(90, 160, 255), 3)
	for sv in world.waiting:
		if blink:
			_dot(sv.global_position, Color8(255, 230, 60), 3)
	for a in world.allies:
		if world.inside != null:
			continue
		_dot(a.global_position, Color8(110, 240, 110) if a.alive else Color8(90, 120, 90), 2)
	if world.home:
		_dot(world.home.global_position + Vector2(0, -8), Color8(90, 230, 120), 4)
	if world.player:
		var pp: Vector2 = world.player.global_position
		if world.inside != null:
			pp = world.inside.global_position
		_dot(pp, Color(0.1, 0.06, 0.1), 4)
		_dot(pp, Color.WHITE, 2)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.03, 0.05), false, 1.0)
