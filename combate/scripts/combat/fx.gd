class_name ImpactFx
extends Node3D
## Efectos de impacto discretos: chispas, anillo de choque, destello, polvo y
## estelas de los golpes. Todo se recicla; nada de texturas externas.

var _add_mat: ShaderMaterial
var _ring_mat: ShaderMaterial
var _quad := QuadMesh.new()
var _live: Array = []
var _trails := {}
var _stains: Array[MeshInstance3D] = []
var _stain_mats: Array[StandardMaterial3D] = []
var _drops: Array = []
const MAX_STAINS := 40


func _ready() -> void:
	_add_mat = ShaderMaterial.new()
	_add_mat.shader = preload("res://shaders/fx_additive.gdshader")
	_ring_mat = ShaderMaterial.new()
	_ring_mat.shader = preload("res://shaders/fx_additive.gdshader")
	_ring_mat.set_shader_parameter("ring", 1.0)
	_quad.size = Vector2(1, 1)


func _sparks(point: Vector3, dir: Vector3, n: int, color: Color, speed: float, life := 0.28) -> void:
	var p := CPUParticles3D.new()
	add_child(p)
	p.global_position = point
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = n
	p.lifetime = life
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.035, 0.035)
	var m := _add_mat.duplicate() as ShaderMaterial
	m.set_shader_parameter("tint", color)
	mesh.material = m
	p.mesh = mesh
	p.particle_flag_align_y = true
	p.direction = dir
	p.spread = 55.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -6, 0)
	p.damping_min = 4.0
	p.damping_max = 8.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = g
	p.emitting = true
	_live.append({"node": p, "t": 0.0, "life": life + 0.2})


func _billboard(point: Vector3, size: float, color: Color, life: float, ring: bool, grow: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _quad
	var m := (_ring_mat if ring else _add_mat).duplicate() as ShaderMaterial
	m.set_shader_parameter("tint", color)
	m.render_priority = 2
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = point
	_live.append({"node": mi, "t": 0.0, "life": life, "bb": true, "size": size, "grow": grow, "mat": m, "color": color})


func impact(point: Vector3, dir: Vector3, level: int, kind: String) -> void:
	match kind:
		"block":
			_sparks(point, -dir + Vector3.UP * 0.3, 8, Color(0.7, 0.85, 1.0), 2.5, 0.2)
			_billboard(point, 0.35, Color(0.6, 0.8, 1.0, 0.6), 0.12, true, 2.0)
		"parry":
			_sparks(point, Vector3.UP, 18, Color(1.0, 0.95, 0.7), 4.0, 0.35)
			_billboard(point, 0.4, Color(1.0, 0.95, 0.8, 1.0), 0.18, true, 4.0)
			_billboard(point, 0.6, Color(1.0, 0.9, 0.6, 0.8), 0.08, false, 1.0)
		_:
			var warm := Color(1.0, 0.72, 0.38)
			_sparks(point, dir + Vector3.UP * 0.2, 6 + level * 5, warm, 2.0 + level * 1.0)
			_billboard(point, 0.18 + level * 0.07, Color(1.0, 0.85, 0.65, 0.9), 0.07 + level * 0.015, false, 1.5)
			if level >= 2:
				_billboard(point, 0.2 + level * 0.06, Color(1.0, 0.8, 0.55, 0.7), 0.12 + level * 0.03, true, 3.0 + level)


func dust(point: Vector3, amount: int, scale := 1.0) -> void:
	var p := CPUParticles3D.new()
	add_child(p)
	p.global_position = point
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = 0.9
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.25, 0.25) * scale
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft_tex()
	mesh.material = m
	p.mesh = mesh
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.4
	p.gravity = Vector3(0, 0.3, 0)
	p.damping_min = 2.0
	p.damping_max = 3.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.8
	var g := Gradient.new()
	g.set_color(0, Color(0.75, 0.68, 0.62, 0.45))
	g.set_color(1, Color(0.75, 0.68, 0.62, 0.0))
	p.color_ramp = g
	p.emitting = true
	_live.append({"node": p, "t": 0.0, "life": 1.2})


var _soft: Texture2D
func _soft_tex() -> Texture2D:
	if _soft:
		return _soft
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	_soft = t
	return t


## Estela del miembro que golpea: se alimenta cada frame durante el golpe.
func trail(key: String, a: Vector3, b: Vector3, color: Color) -> void:
	var tr: Dictionary = _trails.get(key, {})
	if tr.is_empty():
		var mi := MeshInstance3D.new()
		mi.mesh = ImmediateMesh.new()
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/trail.gdshader")
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		tr = {"mi": mi, "pts": [], "mat": m}
		_trails[key] = tr
	tr.mat.set_shader_parameter("tint", color)
	var pts: Array = tr.pts
	pts.push_front([a, b, 1.0])
	while pts.size() > 9:
		pts.pop_back()
	tr["fresh"] = true


func process_fx(delta: float, cam: Camera3D) -> void:
	process_drops(delta)
	for i in range(_live.size() - 1, -1, -1):
		var e: Dictionary = _live[i]
		e.t += delta
		var n: Node3D = e.node
		if e.get("bb", false):
			var u: float = e.t / e.life
			var s: float = e.size * (1.0 + u * e.grow)
			n.look_at_from_position(n.global_position, cam.global_position, Vector3.UP)
			n.scale = Vector3.ONE * s
			var c: Color = e.color
			(e.mat as ShaderMaterial).set_shader_parameter("tint", Color(c.r, c.g, c.b, c.a * (1.0 - u)))
		if e.t >= e.life:
			n.queue_free()
			_live.remove_at(i)
	for key in _trails:
		var tr: Dictionary = _trails[key]
		var pts: Array = tr.pts
		if not tr.get("fresh", false):
			for p in pts:
				p[2] = p[2] - delta * 9.0
			while not pts.is_empty() and pts[pts.size() - 1][2] <= 0.0:
				pts.pop_back()
		tr.fresh = false
		var im: ImmediateMesh = (tr.mi as MeshInstance3D).mesh
		im.clear_surfaces()
		if pts.size() < 2:
			continue
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for j in pts.size():
			var p: Array = pts[j]
			var f := (1.0 - float(j) / float(pts.size() - 1)) * clampf(p[2], 0.0, 1.0)
			im.surface_set_color(Color(1, 1, 1, f * 0.8))
			im.surface_set_uv(Vector2(float(j) / pts.size(), 0))
			im.surface_add_vertex(p[0])
			im.surface_set_color(Color(1, 1, 1, f * 0.8))
			im.surface_set_uv(Vector2(float(j) / pts.size(), 1))
			im.surface_add_vertex(p[1])
		im.surface_end()


# ---------------------------------------------------------------------------
# Sangre: salpicadura en el impacto, gotas que caen y manchas que se quedan
# ---------------------------------------------------------------------------

func _blood_tex(seed_i: int) -> Texture2D:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + seed_i
	var blobs := []
	blobs.append([Vector2(32, 32), rng.randf_range(10, 15)])
	for i in rng.randi_range(4, 9):
		var a := rng.randf() * TAU
		var d := rng.randf_range(8, 24)
		blobs.append([Vector2(32, 32) + Vector2(cos(a), sin(a)) * d, rng.randf_range(1.5, 6.0)])
	for y in 64:
		for x in 64:
			var v := 0.0
			for b in blobs:
				var dd := Vector2(x, y).distance_to(b[0]) / float(b[1])
				v = maxf(v, clampf(1.6 - dd * 1.1, 0.0, 1.0))
			var edge := clampf(v * 1.6, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, edge))
	return ImageTexture.create_from_image(img)


func _stain_material(i: int) -> StandardMaterial3D:
	while _stain_mats.size() < 4:
		var m := StandardMaterial3D.new()
		m.albedo_texture = _blood_tex(_stain_mats.size())
		m.albedo_color = Color(0.36, 0.02, 0.03, 0.9)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.2
		m.metallic_specular = 0.6
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_stain_mats.append(m)
	return _stain_mats[i % 4]


func _stain(pos: Vector3, normal: Vector3, size: float) -> void:
	if FighterRig.blood_mode == 0:
		return
	var mi: MeshInstance3D
	if _stains.size() >= MAX_STAINS:
		mi = _stains.pop_front()
	else:
		mi = MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1, 1)
		mi.mesh = q
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	mi.material_override = _stain_material(randi())
	var up := Vector3.UP if absf(normal.y) < 0.9 else Vector3.FORWARD
	var basis := Basis.looking_at(-normal, up).rotated(normal, randf() * TAU)
	mi.global_transform = Transform3D(basis.scaled(Vector3.ONE * size), pos + normal * (0.016 + _stains.size() * 0.0002))
	_stains.append(mi)


func clear_stains() -> void:
	for mi in _stains:
		mi.queue_free()
	_stains.clear()
	for d in _drops:
		(d.node as Node).queue_free()
	_drops.clear()


func blood(point: Vector3, dir: Vector3, amount: float) -> void:
	var n := clampi(int(4 + amount * 10.0), 3, 18)
	var p := CPUParticles3D.new()
	add_child(p)
	p.global_position = point
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = n
	p.lifetime = 0.55
	var mesh := SphereMesh.new()
	mesh.radius = 0.012
	mesh.height = 0.024
	mesh.radial_segments = 6
	mesh.rings = 3
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.42, 0.02, 0.03)
	m.roughness = 0.15
	mesh.material = m
	p.mesh = mesh
	p.direction = dir.normalized()
	p.spread = 28.0
	p.initial_velocity_min = 1.5 + amount
	p.initial_velocity_max = 3.0 + amount * 2.0
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.5
	p.emitting = true
	_live.append({"node": p, "t": 0.0, "life": 0.8})
	# manchas donde caerá: en el suelo, más lejos cuanto más fuerte
	var flat := Vector3(dir.x, 0, dir.z).normalized()
	for i in clampi(int(1 + amount * 2.5), 1, 5):
		var d := randf_range(0.3, 0.8 + amount * 0.5)
		var spot := Vector3(point.x, 0, point.z) + flat * d + Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2))
		_stain(spot, Vector3.UP, randf_range(0.08, 0.16) + amount * 0.05)


func wall_stain(point: Vector3, normal: Vector3, amount: float) -> void:
	_stain(point, normal.normalized(), 0.3 + amount * 0.25)


## Una gota que cae desde la nariz o la ceja y deja una marca pequeña al tocar el suelo.
func drip(from: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.008
	sm.height = 0.02
	sm.radial_segments = 6
	sm.rings = 3
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.42, 0.02, 0.03)
	m.roughness = 0.15
	sm.material = m
	mi.mesh = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = from
	_drops.append({"node": mi, "v": 0.0})


func process_drops(delta: float) -> void:
	for i in range(_drops.size() - 1, -1, -1):
		var d: Dictionary = _drops[i]
		var mi: MeshInstance3D = d.node
		d.v += 9.8 * delta
		mi.global_position.y -= d.v * delta
		if mi.global_position.y <= 0.02:
			_stain(Vector3(mi.global_position.x, 0, mi.global_position.z), Vector3.UP, randf_range(0.04, 0.07))
			mi.queue_free()
			_drops.remove_at(i)
