class_name CombatCamera
extends Camera3D
## Cámara de combate en tercera persona.
##
## Se coloca detrás y a un lado del jugador mirando a un punto entre ambos
## luchadores, así el rival siempre está en cuadro. La distancia y la altura
## dependen de la separación; el giro es "perezoso" (solo corrige cuando hace
## falta) para no marear. Sacudidas por trauma, golpes de zoom en impactos
## fuertes, prevención de paredes y un plano cinematográfico al final.

var player: Fighter
var foe: Fighter
var trauma := 0.0
var fov_kick := 0.0
var cam_yaw := 0.0
var side := 1.0
var cine_t := -1.0
var cine_target: Fighter
var _focus := Vector3.ZERO
var _dist := 4.0
var _height := 0.7
var _noise := FastNoiseLite.new()
var _t := 0.0
var _cur_pos := Vector3.ZERO


func _ready() -> void:
	fov = 56.0
	near = 0.08
	far = 140.0
	_noise.frequency = 3.0


func snap() -> void:
	var d := player.global_position - foe.global_position
	cam_yaw = atan2(d.x, d.z)
	_focus = _focus_point()
	_dist = _want_dist()
	_cur_pos = _want_pos()
	global_position = _cur_pos
	look_at(_focus, Vector3.UP)


func add_trauma(a: float) -> void:
	trauma = clampf(trauma + a, 0.0, 1.0)


func kick_fov(a: float) -> void:
	fov_kick = minf(fov_kick + a, 10.0)


func cinematic(target: Fighter) -> void:
	cine_t = 0.0
	cine_target = target


func _focus_point() -> Vector3:
	var a := player.global_position
	var b := foe.global_position
	var f := a.lerp(b, 0.5)
	f.y = 1.2
	return f


func _want_dist() -> float:
	var sep := player.global_position.distance_to(foe.global_position)
	return clampf(2.3 + sep * 0.6, 2.9, 5.6)


func _want_pos() -> Vector3:
	# detrás del jugador, desplazada al lado para un encuadre de tres cuartos
	var sep := player.global_position.distance_to(foe.global_position)
	var ang := 0.5 + clampf((2.2 - sep) * 0.12, 0.0, 0.2)
	var off := Basis(Vector3.UP, cam_yaw + side * ang) * Vector3(0, 0, _dist)
	return _focus + off + Vector3.UP * _height


func update(delta: float) -> void:
	if not player or not foe:
		return
	_t += delta
	if cine_t >= 0.0:
		_cinematic(delta)
		return
	var d := player.global_position - foe.global_position
	d.y = 0
	if d.length() > 0.2:
		var want_yaw := atan2(d.x, d.z)
		var diff := angle_difference(cam_yaw, want_yaw)
		# zona muerta: corrige poco cuando el desvío es pequeño, más si crece
		var rate := 1.2 + clampf(absf(diff) - 0.25, 0.0, 1.5) * 4.0
		cam_yaw = rotate_toward(cam_yaw, want_yaw, rate * delta * absf(diff) + 0.0001)
	var sep := d.length()
	_focus = _focus.lerp(_focus_point(), minf(1.0, delta * 6.0))
	_dist = lerpf(_dist, _want_dist(), minf(1.0, delta * 2.5))
	var close := clampf((1.6 - sep) / 0.8, 0.0, 1.0)
	_height = lerpf(_height, 0.55 + sep * 0.1 - close * 0.12, minf(1.0, delta * 2.5))
	var want := _want_pos()
	# evitar atravesar paredes
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(_focus, want, 1 | 8)
	var hit := space.intersect_ray(q)
	if hit:
		want = (hit.position as Vector3) + ((_focus - want).normalized() * 0.25)
	_cur_pos = _cur_pos.lerp(want, minf(1.0, delta * 7.0))
	_apply(_cur_pos, _focus + Vector3(0, 0.05, 0), 56.0, delta)


func _apply(pos: Vector3, look: Vector3, base_fov: float, delta: float) -> void:
	trauma = maxf(0.0, trauma - delta * 1.9)
	fov_kick = lerpf(fov_kick, 0.0, minf(1.0, delta * 7.0))
	var s := trauma * trauma
	var shake := Vector3(_noise.get_noise_2d(_t * 60.0, 0.0), _noise.get_noise_2d(0.0, _t * 60.0), 0) * s * 0.16
	global_position = pos + global_transform.basis * shake
	look_at(look, Vector3.UP)
	rotate_object_local(Vector3.FORWARD, _noise.get_noise_2d(_t * 40.0, 50.0) * s * 0.05)
	fov = base_fov - fov_kick


func _cinematic(delta: float) -> void:
	cine_t += delta
	var c := cine_target.rig.points.get("chest", cine_target.global_position) as Vector3
	# siempre desde el lado del centro del patio: nunca dentro de una pared
	var to_center := Vector3(-c.x, 0, -c.z)
	var base := atan2(to_center.x, to_center.z) if to_center.length() > 0.5 else cam_yaw + 1.2
	var ang := base + 0.5 + cine_t * 0.2
	var dist := 3.2 - minf(cine_t, 2.0) * 0.25
	var pos := c + Basis(Vector3.UP, ang) * Vector3(0, 0, dist) + Vector3.UP * (0.7 + cine_t * 0.1)
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(c, pos, 1 | 8))
	if hit:
		pos = (hit.position as Vector3) + (c - pos).normalized() * 0.25
	_cur_pos = _cur_pos.lerp(pos, minf(1.0, delta * 3.0))
	_apply(_cur_pos, c, 48.0, delta)
