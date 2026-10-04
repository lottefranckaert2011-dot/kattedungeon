class_name Bullet
extends Sprite2D
## A fast bullet that hits the first zombie it touches (or a solid obstacle).

var world
var dir := Vector2.RIGHT
var damage := 20.0
var speed := 340.0
var life := 0.6
var from_player := true

static func fire(w, pos: Vector2, d: Vector2, dmg: float, player_shot := true) -> void:
	var b := Bullet.new()
	b.world = w
	b.position = pos
	b.dir = d.normalized()
	b.damage = dmg
	b.from_player = player_shot
	b.texture = Res.BULLET
	b.rotation = d.angle()
	b.z_index = 20
	w.add_child(b)

func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var step := dir * speed * delta
	var next := position + step
	# hit zombies (checked along the segment so fast bullets don't tunnel)
	for z in world.zombies:
		if z.dead:
			continue
		var c: Vector2 = z.global_position + Vector2(0, -7)
		var closest := Geometry2D.get_closest_point_to_segment(c, position, next)
		if closest.distance_to(c) < z.radius + 2.0:
			z.take_damage(damage, dir * 90.0, true)
			queue_free()
			return
	var cell: Vector2i = world.to_cell(next + Vector2(0, 6))
	if world.in_bounds(cell) and world.astar.is_point_solid(cell) and world.g_at(cell) != World.G.WATER:
		Fx.burst(world, next, Color(0.9, 0.85, 0.6), 4, 30.0)
		queue_free()
		return
	position = next
