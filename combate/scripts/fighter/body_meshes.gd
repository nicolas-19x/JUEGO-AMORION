class_name BodyMeshes
extends RefCounted
## Escultura procedural de los cuerpos.
##
## Cada pieza se define como una serie de anillos (sección superelíptica: entre
## elipse y rectángulo redondeado) a lo largo de un eje. Así se modelan
## deltoides, bíceps, antebrazos, cuádriceps, gemelos, un torso en V con
## pectorales y dorsales, una pelvis con glúteos, zapatillas… con normales
## suaves, UV (u = vuelta, v = a lo largo) y tangentes para el relieve del shader.
## Las mallas se generan una vez y se cachean: los dos luchadores las comparten.

static var _cache := {}


## anillo: [s, rx, rz, cx, cz]  (s a lo largo del eje; r = semiejes; c = desplazamiento del centro)
## axis "y": la pieza cuelga hacia -Y (brazos, piernas, torso). axis "z": hacia -Z (pies).
static func loft(rings: Array, seg := 20, p := 2.0, cap_a := true, cap_b := true, axis := "y") -> ArrayMesh:
	var key := "%s|%d|%.2f|%s|%s|%s" % [str(rings), seg, p, cap_a, cap_b, axis]
	if _cache.has(key):
		return _cache[key]
	var rs: Array = rings.duplicate(true)
	# casquetes redondeados: anillos extra que se cierran
	if cap_a:
		var r0: Array = rs[0]
		var k := minf(float(r0[1]), float(r0[2]))
		var dir := 1.0 if float(rs[0][0]) > float(rs[1][0]) else -1.0
		rs.push_front([float(r0[0]) + dir * k * 0.45, float(r0[1]) * 0.78, float(r0[2]) * 0.78, r0[3], r0[4]])
		rs.push_front([float(r0[0]) + dir * k * 0.8, float(r0[1]) * 0.35, float(r0[2]) * 0.35, r0[3], r0[4]])
		rs.push_front([float(r0[0]) + dir * k * 0.9, 0.0, 0.0, r0[3], r0[4]])
	if cap_b:
		var rn: Array = rs[rs.size() - 1]
		var k := minf(float(rn[1]), float(rn[2]))
		var dir := -1.0 if float(rs[rs.size() - 2][0]) > float(rn[0]) else 1.0
		rs.push_back([float(rn[0]) + dir * k * 0.45, float(rn[1]) * 0.78, float(rn[2]) * 0.78, rn[3], rn[4]])
		rs.push_back([float(rn[0]) + dir * k * 0.8, float(rn[1]) * 0.35, float(rn[2]) * 0.35, rn[3], rn[4]])
		rs.push_back([float(rn[0]) + dir * k * 0.9, 0.0, 0.0, rn[3], rn[4]])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := rs.size()
	var e := 2.0 / p
	for i in n:
		var r: Array = rs[i]
		var v := float(i) / float(n - 1)
		for j in seg + 1:
			var a := TAU * float(j) / float(seg)
			var ca := cos(a)
			var sa := sin(a)
			var x := float(r[3]) + float(r[1]) * signf(ca) * pow(absf(ca), e)
			var z := float(r[4]) + float(r[2]) * signf(sa) * pow(absf(sa), e)
			var pos := Vector3(x, float(r[0]), z) if axis == "y" else Vector3(x, z, float(r[0]))
			st.set_uv(Vector2(float(j) / float(seg), v))
			st.add_vertex(pos)
	for i in n - 1:
		for j in seg:
			var a := i * (seg + 1) + j
			var b := a + seg + 1
			if axis == "y":
				st.add_index(a)
				st.add_index(b)
				st.add_index(a + 1)
				st.add_index(a + 1)
				st.add_index(b)
				st.add_index(b + 1)
			else:
				st.add_index(a)
				st.add_index(a + 1)
				st.add_index(b)
				st.add_index(a + 1)
				st.add_index(b + 1)
				st.add_index(b)
	st.generate_normals()
	st.generate_tangents()
	var m := st.commit()
	_cache[key] = m
	return m


## Brazo: deltoides que se funde con el hombro, bíceps delante (-Z) y tríceps detrás.
static func upper_arm(bulk: float) -> ArrayMesh:
	var k := bulk
	return loft([
		[0.02, 0.06 * k, 0.062 * k, 0.0, 0.0],
		[-0.05, 0.062 * k, 0.064 * k, 0.0, 0.0],
		[-0.11, 0.054 * k, 0.06 * k, 0.0, -0.006],
		[-0.17, 0.05 * k, 0.057 * k, 0.0, -0.008],
		[-0.23, 0.044 * k, 0.046 * k, 0.0, -0.002],
		[-0.29, 0.04 * k, 0.04 * k, 0.0, 0.0],
	], 18, 2.0)


## Antebrazo: masa muscular cerca del codo, muñeca plana.
static func forearm(bulk: float) -> ArrayMesh:
	var k := bulk
	return loft([
		[0.015, 0.041 * k, 0.04 * k, 0.0, 0.0],
		[-0.04, 0.047 * k, 0.044 * k, 0.0, 0.0],
		[-0.11, 0.041 * k, 0.036 * k, 0.0, 0.0],
		[-0.19, 0.034 * k, 0.027 * k, 0.0, 0.0],
		[-0.235, 0.032 * k, 0.026 * k, 0.0, 0.0],
	], 16, 2.2)


## Puño vendado: bloque redondeado con nudillos marcados.
static func fist() -> ArrayMesh:
	return loft([
		[0.012, 0.032, 0.026, 0.0, 0.0],
		[-0.02, 0.043, 0.034, 0.0, -0.002],
		[-0.055, 0.047, 0.037, 0.0, -0.004],
		[-0.082, 0.046, 0.034, 0.0, -0.003],
		[-0.095, 0.04, 0.027, 0.0, 0.0],
	], 16, 3.2)


## Muslo (dentro del pantalón: la pieza ya es la tela, holgada) y espinilla.
static func thigh(loose: float) -> ArrayMesh:
	var k := loose
	return loft([
		[0.03, 0.094 * k, 0.1 * k, 0.0, 0.0],
		[-0.06, 0.098 * k, 0.104 * k, 0.0, -0.006],
		[-0.18, 0.088 * k, 0.094 * k, 0.0, -0.01],
		[-0.32, 0.074 * k, 0.078 * k, 0.0, -0.004],
		[-0.44, 0.066 * k, 0.07 * k, 0.0, 0.0],
	], 18, 2.0)


static func shin(loose: float) -> ArrayMesh:
	var k := loose
	return loft([
		[0.02, 0.064 * k, 0.068 * k, 0.0, 0.0],
		[-0.08, 0.064 * k, 0.074 * k, 0.0, 0.01],
		[-0.18, 0.06 * k, 0.07 * k, 0.0, 0.012],
		[-0.32, 0.056 * k, 0.058 * k, 0.0, 0.004],
		[-0.42, 0.062 * k, 0.064 * k, 0.0, 0.0],
		[-0.44, 0.064 * k, 0.066 * k, 0.0, 0.0],
	], 18, 2.0, true, false)


## Zapatilla: talón, empeine y puntera, a lo largo de -Z desde el tobillo.
static func shoe() -> ArrayMesh:
	return loft([
		[0.07, 0.034, 0.03, 0.0, -0.05],
		[0.045, 0.045, 0.045, 0.0, -0.045],
		[0.0, 0.047, 0.05, 0.0, -0.04],
		[-0.06, 0.05, 0.04, 0.0, -0.052],
		[-0.12, 0.05, 0.03, 0.0, -0.062],
		[-0.16, 0.043, 0.022, 0.0, -0.066],
	], 18, 2.6, true, true, "z")


## Pelvis con glúteos (detrás = +Z) y cadera ancha.
static func pelvis(k: float) -> ArrayMesh:
	return loft([
		[0.13, 0.138 * k, 0.096 * k, 0.0, 0.0],
		[0.06, 0.148 * k, 0.104 * k, 0.0, 0.004],
		[-0.02, 0.162 * k, 0.114 * k, 0.0, 0.012],
		[-0.09, 0.155 * k, 0.112 * k, 0.0, 0.014],
		[-0.14, 0.11 * k, 0.084 * k, 0.0, 0.006],
	], 22, 2.4)


## Abdomen: cintura, oblicuos.
static func abdomen(k: float) -> ArrayMesh:
	return loft([
		[0.22, 0.152 * k, 0.1 * k, 0.0, -0.004],
		[0.13, 0.138 * k, 0.094 * k, 0.0, -0.008],
		[0.03, 0.134 * k, 0.094 * k, 0.0, -0.006],
		[-0.06, 0.142 * k, 0.1 * k, 0.0, 0.0],
	], 22, 2.5, false, false)


## Pecho en V: trapecios, línea de hombros, pectorales y dorsales.
static func chest(k: float) -> ArrayMesh:
	return loft([
		[0.34, 0.085 * k, 0.07 * k, 0.0, 0.004],
		[0.31, 0.17 * k, 0.088 * k, 0.0, 0.004],
		[0.27, 0.21 * k, 0.104 * k, 0.0, -0.004],
		[0.2, 0.218 * k, 0.118 * k, 0.0, -0.014],
		[0.12, 0.2 * k, 0.112 * k, 0.0, -0.014],
		[0.03, 0.168 * k, 0.102 * k, 0.0, -0.008],
		[-0.06, 0.152 * k, 0.1 * k, 0.0, -0.004],
	], 24, 2.6, true, false)


## Camiseta de tirantes: algo más holgada que el pecho, abierta arriba.
static func tank_chest() -> ArrayMesh:
	return loft([
		[0.345, 0.092, 0.078, 0.0, 0.006],
		[0.32, 0.14, 0.094, 0.0, 0.006],
		[0.27, 0.19, 0.11, 0.0, -0.004],
		[0.24, 0.212, 0.116, 0.0, -0.006],
		[0.17, 0.222, 0.126, 0.0, -0.016],
		[0.08, 0.2, 0.118, 0.0, -0.012],
		[-0.02, 0.172, 0.11, 0.0, -0.006],
		[-0.07, 0.164, 0.108, 0.0, -0.004],
	], 24, 2.6, false, false)


static func tank_abdomen() -> ArrayMesh:
	return loft([
		[0.23, 0.162, 0.108, 0.0, -0.004],
		[0.12, 0.15, 0.104, 0.0, -0.006],
		[0.02, 0.15, 0.106, 0.0, -0.004],
		[-0.07, 0.158, 0.112, 0.0, 0.002],
	], 22, 2.5, false, false)


static func neck(k: float) -> ArrayMesh:
	return loft([
		[0.07, 0.046 * k, 0.05 * k, 0.0, 0.006],
		[-0.02, 0.05 * k, 0.054 * k, 0.0, 0.006],
		[-0.1, 0.064 * k, 0.06 * k, 0.0, 0.01],
		[-0.15, 0.085 * k, 0.066 * k, 0.0, 0.012],
	], 16, 2.0, false, false)


## Cabeza: esfera unidad deformada (el shader de heridas trabaja en estas
## coordenadas). Mandíbula que se estrecha, barbilla, pómulos, arco superciliar,
## cuencas de los ojos y nuca.
static func head(jaw: float) -> ArrayMesh:
	var key := "head|%.2f" % jaw
	if _cache.has(key):
		return _cache[key]
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 28
	sm.rings = 18
	var arr := sm.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		var v := verts[i]
		var o := v
		# mandíbula: la parte baja se estrecha y se alarga hacia delante
		if v.y < -0.1:
			var t := clampf((-v.y - 0.1) / 0.9, 0.0, 1.0)
			o.x *= lerpf(1.0, 0.72 * jaw, t)
			if v.z < 0.0:
				o.z *= lerpf(1.0, 1.06, t)
			else:
				o.z *= lerpf(1.0, 0.7, t)
		# barbilla
		o += Vector3(0, -0.04, -0.06) * _g(v, Vector3(0, -0.85, -0.55), 0.35)
		# pómulos
		for sx in [-1.0, 1.0]:
			o += Vector3(sx * 0.05, 0.01, -0.02) * _g(v, Vector3(sx * 0.62, -0.08, -0.72), 0.32)
			# cuencas de los ojos: hundidas
			o += Vector3(0, 0, 0.07) * _g(v, Vector3(sx * 0.36, 0.08, -0.93), 0.2)
		# arco superciliar y frente
		o += Vector3(0, 0.0, -0.045) * _g(v, Vector3(0, 0.3, -0.95), 0.42)
		# nuca más llena
		o += Vector3(0, 0.02, 0.05) * _g(v, Vector3(0, 0.25, 0.95), 0.6)
		verts[i] = o
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = null
	arr[Mesh.ARRAY_TANGENT] = null
	var tmp := ArrayMesh.new()
	tmp.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var st := SurfaceTool.new()
	st.create_from(tmp, 0)
	st.generate_normals()
	st.generate_tangents()
	var m := st.commit()
	_cache[key] = m
	return m


static func _g(v: Vector3, c: Vector3, r: float) -> float:
	var d := v.distance_to(c)
	return exp(-(d * d) / (r * r))


## Nariz: puente que baja y se ensancha en la punta (en metros, -Z delante).
static func nose() -> ArrayMesh:
	return loft([
		[0.025, 0.006, 0.006, 0.0, -0.002],
		[0.0, 0.009, 0.009, 0.0, -0.007],
		[-0.022, 0.013, 0.012, 0.0, -0.013],
		[-0.032, 0.016, 0.011, 0.0, -0.014],
	], 12, 2.0, true, true)


static func ear() -> ArrayMesh:
	return loft([
		[0.022, 0.008, 0.012, 0.0, 0.0],
		[0.0, 0.011, 0.018, 0.0, 0.002],
		[-0.02, 0.008, 0.013, 0.0, 0.0],
	], 10, 2.0)
