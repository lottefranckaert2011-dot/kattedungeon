class_name Furniture
extends StaticBody2D
## A piece of furniture inside a house. Cupboards, chests and bookshelves
## sparkle until you search them.

const OPEN_TEX := {"cupboard": "cupboard_open", "chest": "chest_open", "shelf": "shelf_empty", "treasure": "treasure_open"}
const SOLID := ["bed", "bed_blue", "table", "cupboard", "chest", "shelf", "fireplace", "plant", "sofa", "box", "treasure"]

var kind := ""
var searchable := false
var searched := false
var sprite: Sprite2D
var sparkle: Sprite2D
var _t := 0.0


func setup(k: String, pos: Vector2, can_search: bool) -> void:
	kind = k
	searchable = can_search
	position = pos
	collision_layer = 1 if k in SOLID else 0
	collision_mask = 0
	sprite = Sprite2D.new()
	sprite.texture = Res.tex("res://assets/sprites/in_%s.png" % k)
	sprite.centered = false
	var size: Vector2 = sprite.texture.get_size()
	sprite.offset = Vector2(-size.x / 2.0, -size.y)
	add_child(sprite)
	if k == "rug":
		z_index = -9
	if k in SOLID:
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = Vector2(size.x - 2, minf(10.0, size.y * 0.5))
		cs.shape = rs
		cs.position = Vector2(0, -rs.size.y / 2.0)
		add_child(cs)
	if searchable:
		sparkle = Sprite2D.new()
		sparkle.texture = Res.tex("res://assets/sprites/in_sparkle.png")
		sparkle.position = Vector2(0, -size.y - 5)
		add_child(sparkle)


func _process(delta: float) -> void:
	_t += delta
	if sparkle and sparkle.visible:
		sparkle.position.y = -sprite.texture.get_size().y - 5 + sin(_t * 4.0) * 1.5
		sparkle.modulate.a = 0.6 + sin(_t * 6.0) * 0.4


func set_searched(on: bool) -> void:
	searched = on
	var name: String = OPEN_TEX.get(kind, kind) if on else kind
	sprite.texture = Res.tex("res://assets/sprites/in_%s.png" % name)
	if sparkle:
		sparkle.visible = not on


func is_stairs() -> bool:
	return kind == "stairs_up" or kind == "stairs_down"
