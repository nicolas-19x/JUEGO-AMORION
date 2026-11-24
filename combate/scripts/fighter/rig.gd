class_name FighterRig
extends Node3D
## Cuerpo visual del luchador.
##
## Tronco y cabeza por cinemática directa (caderas → columna → pecho → cabeza);
## brazos y piernas por IK analítica de dos huesos. Así las poses se escriben
## como "dónde están las manos y los pies", los pies apoyados nunca patinan y
## los golpes llegan exactamente al punto deseado.
## Movimiento secundario: faja y cinta de la cabeza con cadenas verlet.

const HIP_HEIGHT := 0.98
const SPINE_OFS := Vector3(0, 0.12, 0)
const CHEST_OFS := Vector3(0, 0.20, 0)
const NECK_OFS := Vector3(0, 0.25, 0)
const SHOULDER := Vector3(0.19, 0.17, 0.0)
const HIP_SOCKET := Vector3(0.10, -0.06, 0.0)
const UPPER_ARM := 0.29
const FOREARM := 0.27
const THIGH := 0.44
const SHIN := 0.44
const ANKLE_H := 0.08

var palette := {}
var mats := {}
var _parts := {}
var points := {}            # puntos en espacio mundo: manos, pies, cabeza…
var local_points := {}      # los mismos, en espacio del rig
var _chains: Array = []
var _flash := 0.0
var shake_offset := Vector3.ZERO


static var blood_mode := 2   # 0 sin sangre, 1 reducida, 2 normal

var _all_mats: Array[ShaderMaterial] = []
var _damage_parts := {}      # parte → {mi, mat, marks: Array[Vector4], r}
var _outline: ShaderMaterial
var face := {"nose": 0.0, "lip": 0.0, "cut": 0.0, "cut_side": 1.0, "swell_l": 0.0, "swell_r": 0.0, "smear": 0.0}
var _sweat := 0.0


func setup(p: Dictionary) -> void:
	palette = p
	_outline = ShaderMaterial.new()
	_outline.shader = preload("res://shaders/outline.gdshader")
	_outline.set_shader_parameter("thickness", 0.010)
	mats["pants"] = _mat(p.pants, 0.85, _outline)
	mats["wrap"] = _mat(p.wrap, 0.8, _outline)
	mats["accent"] = _mat(p.accent, 0.7, _outline)
	mats["hair"] = _mat(p.hair, 0.7, _outline, 0.15)
	mats["shoe"] = _mat(p.shoe, 0.6, _outline)
	mats["dark"] = _mat(Color(0.05, 0.04, 0.04), 0.3, null, 0.0)
	var shirtless: bool = not p.has("top")
	var torso := "skin" if shirtless else "top"

	_add("pelvis", _cyl(0.145, 0.16, 0.21), "pants", Vector3(1, 1, 0.74))
	_add("seat", _sphere(1.0), "pants", Vector3(0.155, 0.08, 0.115))
	_add("sash", _cyl(0.152, 0.16, 0.07), "accent", Vector3(1, 1, 0.78))
	_add("abdomen", _cyl(0.13, 0.14, 0.24), torso, Vector3(1, 1, 0.72))
	_add("chest", _cyl(0.205, 0.14, 0.31), torso, Vector3(1, 1, 0.6))
	_add("traps", _sphere(1.0), torso, Vector3(0.17, 0.06, 0.1))
	_add("shoulder_l", _sphere(0.072), "skin")
	_add("shoulder_r", _sphere(0.072), "skin")
	_add("neck", _cyl(0.048, 0.054, 0.13), "skin")
	_add("head", _sphere(1.0), "face", Vector3(0.1, 0.122, 0.11))
	_add("hair", _sphere(1.0), "hair", Vector3(0.112, 0.104, 0.116))
	_add("nose", _box(Vector3(0.021, 0.042, 0.028)), "skin")
	_add("mouth", _box(Vector3(0.034, 0.006, 0.01)), "dark")
	for s in ["l", "r"]:
		_add("eye_" + s, _sphere(0.011), "dark")
		_add("brow_" + s, _box(Vector3(0.036, 0.009, 0.014)), "hair")
		_add("ear_" + s, _sphere(1.0), "skin", Vector3(0.012, 0.024, 0.018))
		var sw := _add("swell_" + s, _sphere(1.0), "bruise", Vector3(0.026, 0.02, 0.016))
		sw.visible = false
	if p.get("beard", false):
		_add("beard", _sphere(1.0), "hair", Vector3(0.085, 0.065, 0.07))
	if p.get("bun", false):
		_add("knot", _sphere(0.042), "hair")
	for s in ["l", "r"]:
		_add("upper_" + s, _cyl(0.058, 0.046, UPPER_ARM), "skin")
		_add("fore_" + s, _cyl(0.047, 0.04, FOREARM - 0.04), "wrapc")
		_add("fist_" + s, _sphere(1.0), "wrapc", Vector3(0.042, 0.046, 0.054))
		_add("thigh_" + s, _cyl(0.09, 0.066, THIGH), "pants")
		_add("shin_" + s, _cyl(0.066, 0.052, SHIN), "pants")
		_add("foot_" + s, _box(Vector3(0.1, 0.075, 0.24)), "shoec")
	# cadenas de tela: faja (dos cintas) y cinta de la cabeza
	_chains.append(_make_chain("sash_a", 4, 0.11, 0.032, "accent"))
	_chains.append(_make_chain("sash_b", 3, 0.11, 0.028, "accent"))
	_chains.append(_make_chain("band", 4, 0.1, 0.022, "accent"))


func _mat(c: Color, rough: float, outline: Material, rim := 0.3) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/body.gdshader")
	m.set_shader_parameter("albedo", c)
	m.set_shader_parameter("roughness_value", rough)
	m.set_shader_parameter("rim_color", palette.get("rim", Color(1, 0.7, 0.45)))
	m.set_shader_parameter("rim_strength", rim)
	if outline:
		m.next_pass = outline
	_all_mats.append(m)
	return m


## Material por pieza para piel, cara, moretón y camiseta (cada pieza guarda sus marcas).
func _material_for(kind: String) -> ShaderMaterial:
	match kind:
		"skin", "face":
			var m := _mat(palette.skin, 0.5, _outline, 0.32)
			m.set_shader_parameter("skin", 1.0)
			if kind == "face":
				m.set_shader_parameter("face_mode", 1.0)
			return m
		"top":
			return _mat(palette.top, 0.85, _outline)
		"wrapc":
			return _mat(palette.wrap, 0.8, _outline)
		"shoec":
			return _mat(palette.shoe, 0.6, _outline)
		"bruise":
			var c: Color = (palette.skin as Color).lerp(Color(0.42, 0.18, 0.28), 0.55)
			var m2 := _mat(c, 0.45, null, 0.2)
			return m2
	return mats[kind]


func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 18
	m.rings = 9
	return m


func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = 12
	m.rings = 1
	return m


func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


func _add(part: String, mesh: Mesh, mat: String, scl := Vector3.ONE) -> MeshInstance3D:
	var holder := Node3D.new()
	holder.name = part
	add_child(holder)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := _material_for(mat)
	mi.material_override = m
	mi.scale = scl
	if mesh is CylinderMesh:
		mi.position.y = -(mesh as CylinderMesh).height * 0.5
	holder.add_child(mi)
	_parts[part] = holder
	if mat in ["skin", "face", "top", "wrapc", "shoec"] and not part.begins_with("nose") and not part.begins_with("ear"):
		var avg := (scl.x + scl.y + scl.z) / 3.0
		var r := (0.042 if mat == "face" else 0.065) / avg
		m.set_shader_parameter("mark_r", r)
		_damage_parts[part] = {"mi": mi, "mat": m, "marks": [], "bloods": [], "r": r}
		_push_marks(_damage_parts[part])
	return mi


func _make_chain(id: String, n: int, seg: float, radius: float, mat: String) -> Dictionary:
	var nodes := []
	for i in n:
		var h := Node3D.new()
		h.name = "%s_%d" % [id, i]
		add_child(h)
		var mi := MeshInstance3D.new()
		mi.mesh = _cyl(radius, radius * 0.8, seg)
		mi.material_override = mats[mat]
		mi.position.y = -seg * 0.5
		mi.scale = Vector3(1.0, 1.0, 0.35)  # cinta plana
		h.add_child(mi)
		nodes.append(h)
	return {"id": id, "n": n, "seg": seg, "nodes": nodes, "p": [], "prev": [], "anchor": Vector3.ZERO}


func flash(_amount: float) -> void:
	pass  # sin destello blanco: el impacto se comunica con el cuerpo, no con un parpadeo


# ---------------------------------------------------------------------------
# Pose
# ---------------------------------------------------------------------------

static func two_bone(a: Vector3, t: Vector3, l1: float, l2: float, pole: Vector3) -> Array:
	var dv := t - a
	var dist := dv.length()
	var dir := dv / dist if dist > 0.0001 else Vector3.DOWN
	var d := clampf(dist, 0.02, l1 + l2 - 0.0005)
	var cos_a := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var sin_a := sqrt(1.0 - cos_a * cos_a)
	var perp := pole - dir * pole.dot(dir)
	if perp.length_squared() < 0.000001:
		perp = Vector3.FORWARD - dir * Vector3.FORWARD.dot(dir)
		if perp.length_squared() < 0.000001:
			perp = Vector3.RIGHT
	perp = perp.normalized()
	var mid := a + dir * (l1 * cos_a) + perp * (l1 * sin_a)
	var end := a + dir * d
	return [mid, end]


static func seg_basis(a: Vector3, b: Vector3, ref: Vector3) -> Basis:
	# el eje -Y local apunta de a hacia b
	var y := a - b
	if y.length_squared() < 0.000001:
		return Basis.IDENTITY
	y = y.normalized()
	var x := ref.cross(y)
	if x.length_squared() < 0.000001:
		x = Vector3.RIGHT.cross(y) if abs(y.x) < 0.9 else Vector3.FORWARD.cross(y)
	x = x.normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


static func euler(v: Vector3) -> Basis:
	return Basis.from_euler(Vector3(deg_to_rad(v.x), deg_to_rad(v.y), deg_to_rad(v.z)))


## pose: diccionario de Vector3 (ver FighterMoves.STANCE). Pies en espacio del rig.
func apply_pose(pose: Dictionary, foot_l: Vector3, foot_r: Vector3, foot_yaw_l: float, foot_yaw_r: float,
		point_l: float, point_r: float, delta: float) -> void:
	var t_hips := Transform3D(euler(pose.hips_rot), Vector3(0, HIP_HEIGHT, 0) + pose.hips_pos + shake_offset)
	var t_spine := t_hips * Transform3D(euler(pose.spine_rot), SPINE_OFS)
	var t_chest := t_spine * Transform3D(euler(pose.chest_rot), CHEST_OFS)
	var t_head := t_chest * Transform3D(euler(pose.head_rot), NECK_OFS)

	_place("pelvis", t_hips * Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 0)))
	_place("seat", t_hips * Transform3D(Basis.IDENTITY, Vector3(0, -0.01, 0)))
	_place("sash", t_hips * Transform3D(Basis.IDENTITY, Vector3(0, 0.125, 0)))
	_place("abdomen", t_spine * Transform3D(Basis.IDENTITY, Vector3(0, 0.16, 0)))
	_place("chest", t_chest * Transform3D(Basis.IDENTITY, Vector3(0, 0.27, 0)))
	_place("traps", t_chest * Transform3D(Basis.IDENTITY, Vector3(0, 0.255, 0)))
	_place("neck", t_chest * Transform3D(Basis.IDENTITY, Vector3(0, 0.3, 0)))
	_place("head", t_head * Transform3D(Basis.IDENTITY, Vector3(0, 0.12, 0)))
	_place("hair", t_head * Transform3D(Basis.IDENTITY, Vector3(0, 0.162, 0.02)))
	_place("nose", t_head * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-14)), Vector3(0, 0.104, -0.11)))
	_place("mouth", t_head * Transform3D(Basis.IDENTITY, Vector3(0, 0.07, -0.101)))
	for s in ["l", "r"]:
		var sd := -1.0 if s == "l" else 1.0
		_place("eye_" + s, t_head * Transform3D(Basis.IDENTITY, Vector3(0.036 * sd, 0.127, -0.094)))
		_place("brow_" + s, t_head * Transform3D(Basis(Vector3.FORWARD, deg_to_rad(-9.0 * sd)), Vector3(0.037 * sd, 0.146, -0.099)))
		_place("ear_" + s, t_head * Transform3D(Basis.IDENTITY, Vector3(0.099 * sd, 0.118, 0.006)))
		_place("swell_" + s, t_head * Transform3D(Basis.IDENTITY, Vector3(0.041 * sd, 0.118, -0.09)))
	if _parts.has("beard"):
		_place("beard", t_head * Transform3D(Basis.IDENTITY, Vector3(0, 0.062, -0.042)))
	if _parts.has("knot"):
		_place("knot", t_head * Transform3D(Basis.IDENTITY, Vector3(0, 0.235, 0.06)))

	# brazos
	for s in ["l", "r"]:
		var sd := -1.0 if s == "l" else 1.0
		var sh: Vector3 = t_chest * Vector3(SHOULDER.x * sd, SHOULDER.y, SHOULDER.z)
		_place("shoulder_" + s, Transform3D(t_chest.basis, sh))
		var target: Vector3 = (pose["hand_" + s] as Vector3) + (pose.hips_pos as Vector3) + shake_offset
		var pole_local: Vector3 = pose.get("elbow_" + s, Vector3(0.55 * sd, -1.0, 0.35))
		var pole: Vector3 = t_chest.basis * pole_local
		var r := two_bone(sh, target, UPPER_ARM, FOREARM, pole)
		var elbow: Vector3 = r[0]
		var hand: Vector3 = r[1]
		var up_b := seg_basis(sh, elbow, t_chest.basis.z)
		var fo_b := seg_basis(elbow, hand, t_chest.basis.z)
		_place("upper_" + s, Transform3D(up_b, sh))
		_place("fore_" + s, Transform3D(fo_b, elbow))
		_place("fist_" + s, Transform3D(fo_b, hand))
		local_points["hand_" + s] = hand
		local_points["elbow_" + s] = elbow

	# piernas
	for s in ["l", "r"]:
		var sd := -1.0 if s == "l" else 1.0
		var hip: Vector3 = t_hips * Vector3(HIP_SOCKET.x * sd, HIP_SOCKET.y, HIP_SOCKET.z)
		var ft: Vector3 = foot_l if s == "l" else foot_r
		var yaw: float = foot_yaw_l if s == "l" else foot_yaw_r
		var pointed: float = point_l if s == "l" else point_r
		var knee_pole: Vector3 = t_hips.basis * Vector3(0.25 * sd, 0.0, -1.0)
		if pose.has("knee_" + s):
			knee_pole = t_hips.basis * (pose["knee_" + s] as Vector3)
		var r := two_bone(hip, ft, THIGH, SHIN, knee_pole)
		var knee: Vector3 = r[0]
		var ankle: Vector3 = r[1]
		var th_b := seg_basis(hip, knee, t_hips.basis.z)
		var sh_b := seg_basis(knee, ankle, t_hips.basis.z)
		_place("thigh_" + s, Transform3D(th_b, hip))
		_place("shin_" + s, Transform3D(sh_b, knee))
		# pie: plano sobre el suelo con su orientación, o en punta durante patadas
		var flat := Basis(Vector3.UP, yaw)
		var shin_dir := (ankle - knee).normalized()
		var toe_dir := (flat * Vector3.FORWARD)
		if pointed > 0.0:
			var pt := shin_dir.slerp(toe_dir, 0.25) if shin_dir.dot(toe_dir) > -0.9 else shin_dir
			toe_dir = toe_dir.slerp(pt.normalized(), pointed).normalized()
		var fb := Basis.looking_at(toe_dir, Vector3.UP if abs(toe_dir.y) < 0.95 else Vector3.BACK)
		_place("foot_" + s, Transform3D(fb, ankle + fb * Vector3(0, -0.035, -0.06)))
		local_points["foot_" + s] = ankle + fb * Vector3(0, -0.02, -0.08)
		local_points["knee_" + s] = knee

	local_points["head"] = t_head * Vector3(0, 0.12, 0)
	local_points["nose"] = t_head * Vector3(0, 0.085, -0.125)
	local_points["chest"] = t_chest * Vector3(0, 0.08, 0)
	local_points["hips"] = t_hips.origin
	var g := global_transform
	for k in local_points:
		points[k] = g * (local_points[k] as Vector3)

	_update_chains(t_hips, t_head, delta)

	if _flash > 0.0:
		_flash = max(0.0, _flash - delta * 6.0)
		for m in _all_mats:
			m.set_shader_parameter("hit_flash", _flash)


func _place(part: String, t: Transform3D) -> void:
	(_parts[part] as Node3D).transform = t


func _update_chains(t_hips: Transform3D, t_head: Transform3D, delta: float) -> void:
	var g := global_transform
	var inv := g.affine_inverse()
	var anchors := [
		g * (t_hips * Vector3(-0.11, 0.09, 0.13)),
		g * (t_hips * Vector3(-0.07, 0.09, 0.15)),
		g * (t_head * Vector3(0, 0.19, 0.11)),
	]
	var dt := clampf(delta, 0.0, 1.0 / 30.0)
	for ci in _chains.size():
		var ch: Dictionary = _chains[ci]
		var n: int = ch.n
		var seg: float = ch.seg
		var anchor: Vector3 = anchors[ci]
		var p: Array = ch.p
		var prev: Array = ch.prev
		if p.is_empty():
			for i in n + 1:
				p.append(anchor + Vector3(0, -seg * i, 0.02 * i))
				prev.append(p[i])
		p[0] = anchor
		prev[0] = anchor
		for i in range(1, n + 1):
			var cur: Vector3 = p[i]
			var vel: Vector3 = (cur - (prev[i] as Vector3)) * 0.9
			prev[i] = cur
			p[i] = cur + vel + Vector3(0, -6.5, 0) * dt * dt
		for _it in 3:
			for i in range(1, n + 1):
				var a: Vector3 = p[i - 1]
				var b: Vector3 = p[i]
				var d := b - a
				var l := d.length()
				if l > 0.0001:
					p[i] = a + d * (seg / l)
				var q: Vector3 = p[i]
				if q.y < g.origin.y + 0.03:
					q.y = g.origin.y + 0.03
					p[i] = q
		var nodes: Array = ch.nodes
		for i in n:
			var a: Vector3 = inv * (p[i] as Vector3)
			var b: Vector3 = inv * (p[i + 1] as Vector3)
			(nodes[i] as Node3D).transform = Transform3D(seg_basis(a, b, Vector3.FORWARD), a)


func reset_chains() -> void:
	for ch in _chains:
		ch.p.clear()
		ch.prev.clear()


# ---------------------------------------------------------------------------
# Daño visible
# ---------------------------------------------------------------------------

func _push_marks(d: Dictionary) -> void:
	for key in ["marks", "bloods"]:
		var arr: Array = []
		for m in d.get(key, []):
			arr.append(m)
		while arr.size() < 6:
			arr.append(Vector4(99, 99, 99, 0))
		(d.mat as ShaderMaterial).set_shader_parameter(key, arr)


## Deja una marca (moretón en piel, sangre en ropa) en la pieza más cercana al punto.
## Mancha de sangre (no moretón) en la pieza más cercana: goteo y salpicaduras.
func add_blood(world_p: Vector3, amount: float, max_dist := 0.35) -> void:
	var best := ""
	var best_d := max_dist
	for part in _damage_parts:
		var mi: MeshInstance3D = _damage_parts[part].mi
		var dd := mi.global_position.distance_to(world_p)
		if dd < best_d:
			best_d = dd
			best = part
	if best == "":
		return
	var d: Dictionary = _damage_parts[best]
	var mi2: MeshInstance3D = d.mi
	var local: Vector3 = mi2.global_transform.affine_inverse() * world_p
	var arr: Array = d.bloods
	for i in arr.size():
		var m: Vector4 = arr[i]
		if Vector3(m.x, m.y, m.z).distance_to(local) < float(d.r) * 0.5:
			arr[i] = Vector4(m.x, m.y, m.z, minf(1.0, m.w + amount))
			_push_marks(d)
			return
	if arr.size() >= 6:
		arr.remove_at(0)
	arr.append(Vector4(local.x, local.y, local.z, minf(1.0, amount)))
	_push_marks(d)


func add_mark(world_p: Vector3, amount: float, gear_only := false) -> String:
	var best := ""
	var best_d := 9.0
	for part in _damage_parts:
		var gear: bool = part.begins_with("fist") or part.begins_with("fore") or part.begins_with("foot")
		if gear != gear_only:
			continue
		var mi: MeshInstance3D = _damage_parts[part].mi
		var dd := mi.global_position.distance_to(world_p)
		if part == "head":
			dd -= 0.04
		if dd < best_d:
			best_d = dd
			best = part
	if best == "" or best_d > 0.45:
		return ""
	var d: Dictionary = _damage_parts[best]
	var mi: MeshInstance3D = d.mi
	var local: Vector3 = mi.global_transform.affine_inverse() * world_p
	# acercar la marca a la superficie de la pieza
	if best in ["head", "traps"]:
		local = local.normalized() * 0.95
	var marks: Array = d.marks
	var merged := false
	for i in marks.size():
		var m: Vector4 = marks[i]
		if Vector3(m.x, m.y, m.z).distance_to(local) < float(d.r) * 0.7:
			marks[i] = Vector4(m.x, m.y, m.z, minf(1.45, m.w + amount * 0.8))
			merged = true
			break
	if not merged:
		if marks.size() >= 6:
			# sustituye la más leve
			var low := 0
			for i in marks.size():
				if (marks[i] as Vector4).w < (marks[low] as Vector4).w:
					low = i
			marks.remove_at(low)
		marks.append(Vector4(local.x, local.y, local.z, minf(1.2, amount)))
	_push_marks(d)
	return best


func update_face(sweat: float) -> void:
	var fm: ShaderMaterial = _damage_parts["head"].mat
	var on := 0.0 if blood_mode == 0 else 1.0
	fm.set_shader_parameter("nose_blood", face.nose)
	fm.set_shader_parameter("lip_blood", face.lip)
	fm.set_shader_parameter("cut_amount", face.cut)
	fm.set_shader_parameter("cut_side", face.cut_side)
	fm.set_shader_parameter("smear", face.smear * (0.5 if blood_mode == 1 else 1.0))
	for d in _damage_parts.values():
		(d.mat as ShaderMaterial).set_shader_parameter("blood_on", on)
		(d.mat as ShaderMaterial).set_shader_parameter("sweat", sweat)
	for s in ["l", "r"]:
		var sw: float = face["swell_" + s]
		var mi := (_parts["swell_" + s] as Node3D).get_child(0) as MeshInstance3D
		mi.visible = sw > 0.02
		mi.scale = Vector3(0.026, 0.02, 0.016) * (0.6 + sw * 0.75)
		var eye := (_parts["eye_" + s] as Node3D).get_child(0) as MeshInstance3D
		eye.scale = Vector3(1.0, maxf(0.15, 1.0 - sw * 0.85), 1.0)


func clear_damage() -> void:
	for d in _damage_parts.values():
		(d.marks as Array).clear()
		(d.bloods as Array).clear()
		_push_marks(d)
	face = {"nose": 0.0, "lip": 0.0, "cut": 0.0, "cut_side": 1.0, "swell_l": 0.0, "swell_r": 0.0, "smear": 0.0}
	if not _damage_parts.is_empty():
		update_face(0.0)
