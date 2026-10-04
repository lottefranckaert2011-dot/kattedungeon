class_name Pickup
extends Node2D
## A dropped item that hops out, then gets sucked towards the player.

var kind := "wood"
var amount := 1
var world
var _vel := Vector2.ZERO
var _z := 0.0
var _vz := 0.0
var _age := 0.0
var _sprite: Sprite2D

static func spawn(w, k: String, n: int, pos: Vector2) -> Pickup:
	var p := Pickup.new()
	p.world = w
	p.kind = k
	p.amount = n
	p.position = pos + Vector2(randf_range(-3, 3), randf_range(2, 6))
	p._vel = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(20, 45)
	p._vz = randf_range(50, 80)
	w.entities.add_child(p)
	return p

func _ready() -> void:
	var sh := Sprite2D.new()
	sh.texture = Res.SHADOW
	sh.scale = Vector2(0.6, 0.6)
	sh.z_index = -1
	add_child(sh)
	_sprite = Sprite2D.new()
	_sprite.texture = Res.icon(kind)
	_sprite.offset = Vector2(0, -6)
	add_child(_sprite)

func _process(delta: float) -> void:
	_age += delta
	if _vz != 0.0 or _z > 0.0:
		_vz -= 260.0 * delta
		_z = maxf(0.0, _z + _vz * delta)
		if _z == 0.0:
			_vz = 0.0
		position += _vel * delta
		_vel = _vel.move_toward(Vector2.ZERO, 60.0 * delta)
	else:
		_sprite.position.y = sin(_age * 4.0) * 1.0
	_sprite.position.y = -_z + (sin(_age * 4.0) if _z == 0.0 else 0.0)
	if _age > 45.0:
		modulate.a = maxf(0.0, 1.0 - (_age - 45.0) / 3.0)
		if _age > 48.0:
			queue_free()
			return
	var player = world.player
	if player == null or not player.alive or _age < 0.35:
		return
	var to: Vector2 = player.global_position - global_position
	var d: float = to.length()
	if d < 6.0:
		player.add_item(kind, amount, global_position)
		queue_free()
	elif d < 34.0:
		position += to.normalized() * (60.0 + (34.0 - d) * 6.0) * delta
