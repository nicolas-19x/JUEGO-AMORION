class_name Arena
extends Node3D
## "Azotea del Farol": patio en una azotea al atardecer.
## Pequeño, cerrado (paredes para los golpes contra pared), con objetos que
## reaccionan a los cuerpos y una ciudad lejana que se funde en la niebla.

const HALF := 4.6
const TREE := Vector3(-3.55, 0, 3.55)
const PLANTER_HALF := 0.65

var sun: DirectionalLight3D
var env: Environment
var props: Array[RigidBody3D] = []
var _rng := RandomNumberGenerator.new()


func build() -> void:
	_rng.seed = 11
	_environment()
	_floor()
	_walls()
	_facade()
	_corners()
	_tree(TREE)
	_props()
	_skyline()


## Mantiene un punto (con radio r) dentro del patio y fuera de la jardinera.
## Se aplica a todo lo que se coloca a mano (separación, agarre, cuerpo tumbado).
static func constrain(p: Vector3, r: float) -> Vector3:
	var lim := HALF - r
	p.x = clampf(p.x, -lim, lim)
	p.z = clampf(p.z, -lim, lim)
	var dx := p.x - TREE.x
	var dz := p.z - TREE.z
	var e := PLANTER_HALF + r
	if absf(dx) < e and absf(dz) < e:
		if e - absf(dx) < e - absf(dz):
			p.x = TREE.x + signf(dx if dx != 0.0 else 1.0) * e
		else:
			p.z = TREE.z + signf(dz if dz != 0.0 else 1.0) * e
	return p


func _mat(c: Color, rough := 0.8, emit := Color.BLACK, emit_e := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emit_e > 0.0:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = emit_e
	return m


func _box(size: Vector3, pos: Vector3, mat: Material, parent: Node = self, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _collider(size: Vector3, pos: Vector3, wall := true) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	sb.position = pos
	if wall:
		sb.add_to_group("wall")
	add_child(sb)
	return sb


func _environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.14, 0.15, 0.33)
	sm.sky_horizon_color = Color(0.98, 0.56, 0.36)
	sm.sky_curve = 0.12
	sm.ground_bottom_color = Color(0.09, 0.07, 0.11)
	sm.ground_horizon_color = Color(0.72, 0.42, 0.34)
	sm.sun_angle_max = 18.0
	sm.sun_curve = 0.08
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.ambient_light_sky_contribution = 0.85
	env.ambient_light_color = Color(0.45, 0.42, 0.6)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.62, 0.43, 0.46)
	env.fog_density = 0.011
	env.fog_sun_scatter = 0.25
	env.fog_aerial_perspective = 0.4
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.74, 0.52)
	sun.light_energy = 1.55
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_blur = 1.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 22.0
	sun.rotation_degrees = Vector3(-24, -38, 0)
	add_child(sun)


func _floor() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(HALF * 2 + 1.2, HALF * 2 + 1.2)
	mi.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/stone_floor.gdshader")
	mi.material_override = m
	add_child(mi)
	var sb := _collider(Vector3(30, 1, 30), Vector3(0, -0.5, 0), false)
	sb.name = "Floor"
	# un tapiz de entrenamiento en el centro: lectura del espacio de combate
	var rug := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 2.4
	cm.bottom_radius = 2.4
	cm.height = 0.012
	cm.radial_segments = 48
	rug.mesh = cm
	rug.position.y = 0.006
	rug.material_override = _mat(Color(0.42, 0.18, 0.16), 0.95)
	add_child(rug)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 2.18
	tm.outer_radius = 2.26
	tm.rings = 48
	ring.mesh = tm
	ring.scale = Vector3(1, 0.05, 1)
	ring.position.y = 0.014
	ring.material_override = _mat(Color(0.86, 0.66, 0.38), 0.6)
	add_child(ring)


func _walls() -> void:
	var stone := _mat(Color(0.5, 0.44, 0.42), 0.9)
	var cap := _mat(Color(0.3, 0.2, 0.16), 0.7)
	var h := 0.95
	for side: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1)]:
		var along := Vector3(absf(side.z), 0, absf(side.x))
		var ln := HALF * 2 + 0.8
		var center: Vector3 = side * (HALF + 0.2)
		var size := along * ln + side.abs() * 0.4 + Vector3(0, h, 0)
		_box(size, center + Vector3(0, h * 0.5, 0), stone)
		_box(along * (ln + 0.05) + side.abs() * 0.5 + Vector3(0, 0.08, 0), center + Vector3(0, h + 0.04, 0), cap)
		_collider(along * ln + side.abs() * 0.4 + Vector3(0, 2.4, 0), center + Vector3(0, 1.2, 0))


func _facade() -> void:
	# fachada de madera y papel al norte: la pared principal para los golpes
	var z := -HALF - 0.2
	var wood := _mat(Color(0.24, 0.13, 0.1), 0.65)
	var paper := _mat(Color(0.95, 0.86, 0.7), 0.9, Color(1.0, 0.7, 0.42), 0.55)
	var w := HALF * 2 + 0.8
	_box(Vector3(w, 4.2, 0.4), Vector3(0, 2.1, z - 0.05), _mat(Color(0.33, 0.27, 0.27), 0.9))
	_collider(Vector3(w, 4.2, 0.4), Vector3(0, 2.1, z - 0.05))
	# paneles shoji con su retícula
	for i in 5:
		var x := -3.6 + i * 1.8
		_box(Vector3(1.5, 2.3, 0.05), Vector3(x, 1.45, z + 0.17), paper, self, false)
		_box(Vector3(1.6, 0.08, 0.1), Vector3(x, 2.62, z + 0.2), wood)
		_box(Vector3(1.6, 0.08, 0.1), Vector3(x, 0.28, z + 0.2), wood)
		for k in 3:
			_box(Vector3(0.04, 2.3, 0.08), Vector3(x - 0.5 + k * 0.5, 1.45, z + 0.2), wood, self, false)
		for k in 3:
			_box(Vector3(1.5, 0.035, 0.08), Vector3(x, 0.85 + k * 0.6, z + 0.2), wood, self, false)
		_box(Vector3(0.14, 3.3, 0.16), Vector3(x + 0.9, 1.65, z + 0.2), wood)
	_box(Vector3(w, 0.2, 0.9), Vector3(0, 3.35, z + 0.3), wood)
	# alero
	var roof := _mat(Color(0.16, 0.15, 0.19), 0.6)
	var r := _box(Vector3(w + 0.6, 0.12, 1.6), Vector3(0, 3.75, z + 0.55), roof)
	r.rotation_degrees.x = -14
	# estandartes
	for x in [-2.7, 2.7]:
		var b := _box(Vector3(0.55, 1.5, 0.02), Vector3(x, 2.5, z + 0.32), _mat(Color(0.12, 0.36, 0.38), 0.9))
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_box(Vector3(0.18, 0.18, 0.025), Vector3(x, 2.75, z + 0.34), _mat(Color(0.9, 0.7, 0.4), 0.5), self, false)


func _corners() -> void:
	var wood := _mat(Color(0.26, 0.15, 0.11), 0.7)
	var glow := _mat(Color(1.0, 0.6, 0.3), 0.6, Color(1.0, 0.55, 0.25), 3.2)
	var i := 0
	for c: Vector3 in [Vector3(HALF + 0.2, 0, HALF + 0.2), Vector3(-HALF - 0.2, 0, HALF + 0.2),
			Vector3(HALF + 0.2, 0, -HALF + 0.3), Vector3(-HALF - 0.2, 0, -HALF + 0.3)]:
		_box(Vector3(0.28, 2.6, 0.28), c + Vector3(0, 1.3, 0), wood)
		var arm_dir := -Vector3(signf(c.x), 0, signf(c.z)).normalized() * 0.35
		_box(Vector3(0.08, 0.08, 0.08) + arm_dir.abs() * 2.0, c + Vector3(0, 2.45, 0) + arm_dir * 0.5, wood)
		var lan := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.13
		cm.bottom_radius = 0.15
		cm.height = 0.36
		cm.radial_segments = 10
		lan.mesh = cm
		lan.material_override = glow
		lan.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lan.position = c + Vector3(0, 2.15, 0) + arm_dir
		add_child(lan)
		if i < 2:
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.62, 0.32)
			l.light_energy = 1.6
			l.omni_range = 5.5
			l.omni_attenuation = 1.4
			l.position = lan.position + Vector3(0, -0.1, 0) + arm_dir
			add_child(l)
		i += 1


func _tree(pos: Vector3) -> void:
	var stone := _mat(Color(0.44, 0.39, 0.38), 0.9)
	_box(Vector3(1.3, 0.55, 1.3), pos + Vector3(0, 0.275, 0), stone)
	_collider(Vector3(1.3, 2.4, 1.3), pos + Vector3(0, 1.2, 0))
	var bark := _mat(Color(0.22, 0.14, 0.12), 0.85)
	var leaf := _mat(Color(0.93, 0.48, 0.36), 0.8)
	var leaf2 := _mat(Color(0.85, 0.36, 0.3), 0.8)
	var trunk := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.07
	cm.bottom_radius = 0.13
	cm.height = 1.9
	trunk.mesh = cm
	trunk.material_override = bark
	trunk.position = pos + Vector3(0.05, 1.45, 0)
	trunk.rotation_degrees = Vector3(0, 0, -8)
	add_child(trunk)
	for k in 9:
		var s := MeshInstance3D.new()
		var sp := SphereMesh.new()
		var r := _rng.randf_range(0.35, 0.6)
		sp.radius = r
		sp.height = r * 1.6
		sp.radial_segments = 12
		sp.rings = 6
		s.mesh = sp
		s.material_override = leaf if k % 3 else leaf2
		var a := k * 2.4
		s.position = pos + Vector3(cos(a) * 0.55 + 0.1, 2.45 + _rng.randf_range(-0.2, 0.35), sin(a) * 0.55)
		add_child(s)
	# volumen solo para la cámara: que la copa no tape la acción
	var cb := StaticBody3D.new()
	cb.collision_layer = 8
	cb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.35
	cs.shape = sph
	cb.add_child(cs)
	cb.position = pos + Vector3(0.1, 2.5, 0)
	add_child(cb)
	# pétalos que caen y cruzan el patio con la brisa
	var p := CPUParticles3D.new()
	p.amount = 26
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.8, 0.3, 0.8)
	p.position = pos + Vector3(0, 2.6, 0)
	p.direction = Vector3(1, -0.2, -0.6)
	p.spread = 30
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.7
	p.gravity = Vector3(0.25, -0.22, -0.15)
	p.angular_velocity_min = -180
	p.angular_velocity_max = 180
	var qm := QuadMesh.new()
	qm.size = Vector2(0.05, 0.035)
	var pm := _mat(Color(1.0, 0.62, 0.55), 0.8)
	pm.cull_mode = BaseMaterial3D.CULL_DISABLED
	qm.material = pm
	p.mesh = qm
	add_child(p)


func _props() -> void:
	var crate_m := _mat(Color(0.55, 0.38, 0.24), 0.85)
	var jar_m := _mat(Color(0.62, 0.32, 0.2), 0.5)
	for d in [[Vector3(3.75, 0, -1.4), 0.55], [Vector3(3.8, 0, -0.75), 0.48], [Vector3(3.75, 0.55, -1.25), 0.42],
			[Vector3(-3.8, 0, -2.6), 0.5], [Vector3(1.8, 0, 3.85), 0.5]]:
		var s: float = d[1]
		props.append(_rigid(_box_mesh(Vector3.ONE * s), BoxShape3D.new(), Vector3.ONE * s, d[0] + Vector3(0, s * 0.5, 0), crate_m, 9.0 * s))
	for pos: Vector3 in [Vector3(-1.2, 0, -4.15), Vector3(3.9, 0, 3.1), Vector3(-3.95, 0, 0.9)]:
		var cm := CylinderMesh.new()
		cm.top_radius = 0.16
		cm.bottom_radius = 0.2
		cm.height = 0.6
		cm.radial_segments = 14
		var cs := CylinderShape3D.new()
		cs.radius = 0.2
		cs.height = 0.6
		props.append(_rigid(cm, cs, Vector3.ZERO, pos + Vector3(0, 0.3, 0), jar_m, 6.0))


func _box_mesh(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


func _rigid(mesh: Mesh, shape: Shape3D, size: Vector3, pos: Vector3, mat: Material, mass: float) -> RigidBody3D:
	var rb := RigidBody3D.new()
	rb.collision_layer = 4
	rb.collision_mask = 1 | 2 | 4
	rb.mass = mass
	rb.contact_monitor = true
	rb.max_contacts_reported = 2
	rb.linear_damp = 0.6
	rb.angular_damp = 1.2
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	rb.add_child(mi)
	if shape is BoxShape3D:
		(shape as BoxShape3D).size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	rb.add_child(cs)
	rb.position = pos
	rb.rotation.y = _rng.randf_range(-0.3, 0.3)
	rb.set_meta("home", Transform3D(Basis(Vector3.UP, rb.rotation.y), pos))
	add_child(rb)
	return rb


func reset_props() -> void:
	for rb in props:
		rb.linear_velocity = Vector3.ZERO
		rb.angular_velocity = Vector3.ZERO
		rb.global_transform = rb.get_meta("home")


func _skyline() -> void:
	# ciudad lejana: siluetas violetas con ventanas cálidas que la niebla funde
	var dark := [_mat(Color(0.2, 0.16, 0.24), 0.9), _mat(Color(0.26, 0.19, 0.27), 0.9), _mat(Color(0.17, 0.14, 0.21), 0.9)]
	var win := _mat(Color(1, 0.7, 0.4), 1.0, Color(1.0, 0.62, 0.32), 2.0)
	for k in 70:
		var ang := _rng.randf() * TAU
		var dist := _rng.randf_range(16.0, 46.0)
		var p := Vector3(cos(ang) * dist, 0, sin(ang) * dist)
		var hgt := _rng.randf_range(-4.0, 9.0) + dist * 0.12
		var sz := Vector3(_rng.randf_range(3, 7), maxf(hgt + 10.0, 2.0), _rng.randf_range(3, 7))
		var b := _box(sz, p + Vector3(0, -10.0 + sz.y * 0.5, 0), dark[k % 3], self, false)
		b.rotation.y = _rng.randf() * PI
		if _rng.randf() < 0.55:
			for w in _rng.randi_range(1, 4):
				var wp := Vector3(_rng.randf_range(-0.4, 0.4) * sz.x, -10.0 + sz.y - _rng.randf_range(0.6, 5.0), sz.z * 0.51)
				_box(Vector3(0.6, 0.4, 0.05), wp, win, b, false)
	# cordillera
	var hill := _mat(Color(0.3, 0.22, 0.32), 1.0)
	for k in 9:
		var ang := k * TAU / 9.0 + 0.3
		var mi := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 30
		sp.height = 26
		sp.radial_segments = 16
		sp.rings = 8
		mi.mesh = sp
		mi.material_override = hill
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(cos(ang) * 95.0, -6.0, sin(ang) * 95.0)
		mi.scale = Vector3(1.4, 0.9 + (k % 3) * 0.25, 1.0)
		add_child(mi)
