class_name HouseDoor
extends Node2D
## The front door of a house you can go into. While you are inside,
## zombies come and bash it. If it breaks you have to get out.

signal broken(door)

var house
var hp := 80.0
var max_hp := 80.0
var alive := true      # zombies only attack targets that are "alive"
var radius := 6.0
var _hit_msg_t := 0.0

func setup(h, strength: float) -> void:
	house = h
	max_hp = strength
	hp = strength
	position = Vector2(0, 2)

func _process(delta: float) -> void:
	_hit_msg_t -= delta

func take_damage(amount: float, _dir: Vector2) -> void:
	if hp <= 0.0:
		return
	# Doors are sturdy: zombies only do a quarter of their normal damage.
	hp -= amount * 0.25
	Audio.play("barricade_hit", -6.0, 0.15, global_position)
	Fx.burst(house.world, global_position + Vector2(0, -8), Color(0.6, 0.42, 0.25), 4, 30.0)
	house.sprite.modulate = Color(1.6, 1.2, 1.2)
	var tw: Tween = house.create_tween()
	tw.tween_property(house.sprite, "modulate", Color.WHITE, 0.15)
	if hp <= 0.0:
		hp = 0.0
		alive = false
		Audio.play("break", 0.0, 0.1, global_position)
		broken.emit(self)

## True the first time in a while: used for the "they are banging on your door" message.
func should_warn() -> bool:
	if _hit_msg_t > 0.0:
		return false
	_hit_msg_t = 8.0
	return true

func repair() -> void:
	hp = max_hp
	alive = true
