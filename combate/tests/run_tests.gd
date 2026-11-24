extends SceneTree
## Pruebas automáticas del combate (sin pantalla).
## Uso: godot --headless -s res://tests/run_tests.gd

var fails := 0
var checks := 0
var main: Node


func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("  FALLO: ", msg)


func _initialize() -> void:
	print("== Datos de movimientos")
	test_moves()
	print("== IK")
	test_ik()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


var _stage := 0
var _dbg := {}
func _process(_d: float) -> bool:
	_stage += 1
	if _stage < 3:
		return false
	main.set_physics_process(false)
	print("== Parada, bloqueo, rotura de guardia")
	test_defense()
	print("== Contra la pared")
	test_wall()
	print("== Remate sincronizado")
	test_clinch()
	print("== Novedades: empujón, contraataque, equilibrio, lesiones")
	test_new()
	print("== Combos largos y colisiones")
	test_combos()
	print("== Combate completo (IA contra jugador guionizado)")
	for lvl in 3:
		test_full_fight(lvl)
	print("\n%d comprobaciones, %d fallos" % [checks, fails])
	quit(1 if fails > 0 else 0)
	return true


func test_moves() -> void:
	var m := FighterMoves.all()
	for k in m:
		var mv: Dictionary = m[k]
		var last := -1.0
		for key in mv.kf:
			ok(float(key.t) > last, "%s: claves ordenadas" % k)
			last = float(key.t)
			for p in key:
				if p != "t" and p != "e":
					ok(p in FighterMoves.PARAMS, "%s: parámetro conocido %s" % [k, p])
		if not mv.get("hold", false):
			ok(last <= float(mv.dur) + 0.001, "%s: claves dentro de la duración" % k)
		if mv.has("hit"):
			ok(float(mv.hit.from) < float(mv.hit.to) and float(mv.hit.to) < float(mv.dur), "%s: ventana de golpe válida" % k)
	var st := FighterMoves.stance()
	var mm := FighterMoves.mirror(FighterMoves.mirror(st))
	for p in st:
		ok((st[p] as Vector3).is_equal_approx(mm[p]), "reflejar dos veces = identidad (%s)" % p)


func test_ik() -> void:
	for i in 200:
		var a := Vector3(randf_range(-1, 1), randf_range(0, 2), randf_range(-1, 1))
		var t := a + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(0.1, 0.55)
		var r := FighterRig.two_bone(a, t, 0.29, 0.27, Vector3(0, -1, 0.3))
		var mid: Vector3 = r[0]
		var end: Vector3 = r[1]
		ok(absf(a.distance_to(mid) - 0.29) < 0.001, "IK conserva el hueso superior")
		ok(absf(mid.distance_to(end) - 0.27) < 0.001, "IK conserva el hueso inferior")
		ok(end.distance_to(t) < 0.002, "IK alcanza objetivos alcanzables")


func _place(p: Fighter, f: Fighter, d: float) -> void:
	p.reset(Vector3(0, 0, d * 0.5), Vector3(0, 0, -1))
	f.reset(Vector3(0, 0, -d * 0.5), Vector3(0, 0, 1))


func _run(frames: int, before := Callable()) -> void:
	for i in frames:
		if before.is_valid():
			before.call(i)
		main.sim_step(1.0 / 60.0)


func test_defense() -> void:
	main.start_fight()
	main.phase = "fight"
	main.scripted = true
	var p: Fighter = main.player
	var f: Fighter = main.foe
	# parada
	_place(p, f, 1.3)
	f.start_move("jab")
	p.guard_age = 0.0
	main._hit_log.clear()
	_run(1)
	p.guard_age = 0.0
	_run(25, func(_i): p.guard_age = minf(p.guard_age, 0.05) if main._hit_log.is_empty() else p.guard_age)
	ok(main._hit_log.size() == 1 and main._hit_log[0].result == "parry", "parada en el momento justo")
	ok(f.state == "react" and f.move.name == "parried", "el atacante queda desequilibrado tras la parada")
	ok(p.hp == p.max_hp, "la parada no hace daño")
	# bloqueo
	_run(80)
	_place(p, f, 1.3)
	main._hit_log.clear()
	f.start_move("cross")
	p.guard_age = 9.0
	_run(30, func(_i): p.ctrl.guard = true)
	ok(main._hit_log.size() == 1 and main._hit_log[0].result == "block", "bloqueo del directo")
	ok(p.hp == p.max_hp, "bloquear un golpe ligero no hace daño")
	# rotura de guardia con la patada fuerte
	_run(40, func(_i): p.ctrl.guard = false)
	_place(p, f, 1.5)
	main._hit_log.clear()
	f.start_move("push_kick")
	f.charging = false
	_run(40, func(_i): p.ctrl.guard = true)
	ok(main._hit_log.size() == 1 and main._hit_log[0].result == "guard_break", "la patada fuerte rompe la guardia")
	_run(50, func(_i): p.ctrl.guard = false)
	ok(p.move.get("name", "") == "dazed", "tras romper la guardia queda aturdido")
	# esquiva: invulnerable en su ventana
	_run(120)
	_place(p, f, 1.2)
	main._hit_log.clear()
	f.start_move("jab")
	p.start_dodge(Vector3.RIGHT)
	_run(30)
	ok(main._hit_log.is_empty(), "la esquiva evita el golpe")
	_run(60)


func test_wall() -> void:
	var p: Fighter = main.player
	var f: Fighter = main.foe
	p.reset(Vector3(0, 0, -2.2), Vector3(0, 0, -5))
	f.reset(Vector3(0, 0, -3.3), Vector3(0, 0, 0))
	main._hit_log.clear()
	var saw_splat := false
	p.start_move("push_kick")
	p.charging = false
	for i in 90:
		main.sim_step(1.0 / 60.0)
		if f.move.get("name", "") == "wall_splat":
			saw_splat = true
	ok(main._hit_log.size() == 1 and main._hit_log[0].result == "hit", "la patada conecta")
	ok(saw_splat, "la víctima choca contra la pared")
	ok(f.global_position.z > -Arena.HALF, "la víctima no atraviesa la pared")
	_run(120)


func test_clinch() -> void:
	var p: Fighter = main.player
	var f: Fighter = main.foe
	_place(p, f, 1.5)
	f.start_reaction("dazed", null, 1.0, 1.0)
	ok(f.is_vulnerable_to_special(), "aturdido = remate disponible")
	main._hit_log.clear()
	p.ctrl.special = true
	var min_d := 9.0
	for i in 70:
		main.sim_step(1.0 / 60.0)
		if i > 5 and i < 25:
			min_d = minf(min_d, p.global_position.distance_to(f.global_position))
	ok(p.move.get("name", "") == "clinch_knee" or main._hit_log.size() > 0, "el remate se ejecuta")
	ok(main._hit_log.size() == 1 and main._hit_log[0].reaction == "launch", "el rodillazo derriba")
	ok(min_d > 0.45 and min_d < 0.8, "la víctima se coloca a distancia de agarre (%.2f)" % min_d)
	_run(200)


func test_full_fight(lvl: int) -> void:
	main.difficulty = lvl
	main.scripted = false
	main.start_fight()
	main._set_phase("fight")
	var p: Fighter = main.player
	var f: Fighter = main.foe
	main._hit_log.clear()
	var min_dist := 99.0
	var nan := false
	var slide := 0.0
	var prev_feet := []
	var frames := 0
	var ai_attacks := 0
	var prev_state := ""
	for i in 60 * 70:
		frames = i
		if main.phase == "fight":
			var d := p.global_position.distance_to(f.global_position)
			var to := (f.global_position - p.global_position).normalized()
			p.ctrl.move = to if d > 1.3 else to.cross(Vector3.UP) * (0.5 if (i / 120) % 2 == 0 else -0.5)
			if i % 25 == 0 and d < 1.8:
				main._on_attack_down()
				main._on_attack_up()
			if i % 200 == 100:
				main._on_guard_down()
			if i % 200 == 150:
				main._on_guard_up()
		main.sim_step(1.0 / 60.0)
		if f.state == "attack" and prev_state != "attack":
			ai_attacks += 1
		prev_state = f.state
		if main.phase == "ko":
			main.phase_t += 1.0 / 60.0
		for fi in [p, f]:
			var fg := fi as Fighter
			for k in fg.rig.points:
				var v: Vector3 = fg.rig.points[k]
				if not v.is_finite():
					nan = true
			var lim := Arena.HALF
			ok(absf(fg.global_position.x) < lim and absf(fg.global_position.z) < lim, "dentro del patio") if i % 60 == 0 else null
		if not p.sync_target and not f.sync_target and main.phase == "fight":
			min_dist = minf(min_dist, p.global_position.distance_to(f.global_position))
		# pies apoyados: no deben moverse en el mundo
		var cur := []
		for fi in [p, f]:
			for ft in (fi as Fighter).feet:
				cur.append([ft.pos, ft.stepping or ft.air])
		if prev_feet.size() == cur.size():
			for j in cur.size():
				if not cur[j][1] and not prev_feet[j][1]:
					slide = maxf(slide, (cur[j][0] as Vector3).distance_to(prev_feet[j][0]))
		prev_feet = cur
		if main.phase == "result":
			break
	var hits := 0
	var blocks := 0
	for h in main._hit_log:
		if h.result == "hit":
			hits += 1
		elif h.result == "block":
			blocks += 1
	print("  nivel %s: %.1f s, %d impactos, %d bloqueos, vida %d / %d, distancia mínima %.2f, deslizamiento máx. de pie %.4f" % [
		main.LEVEL_NAMES[lvl], frames / 60.0, hits, blocks, p.hp, f.hp, min_dist, slide])
	ok(not nan, "sin valores no finitos")
	ok(hits >= 5, "hay intercambio de golpes")
	ok(min_dist > 0.45, "los cuerpos no se atraviesan")
	ok(slide < 0.0005, "los pies apoyados no patinan")
	var dist_r := {}
	for h in main._hit_log:
		var k2: String = ("IA " if h.attacker == f else "J ") + str(h.result) + " " + str(h.move) + " " + str(h.get("reaction", ""))
		dist_r[k2] = dist_r.get(k2, 0) + 1
	print("    ", dist_r)
	# iniciativa: con el jugador quieto, la IA debe atacar por su cuenta
	main.start_fight()
	main._set_phase("fight")
	var starts := 0
	var prev := ""
	for i in 60 * 10:
		p.ctrl.move = Vector3.ZERO
		main.sim_step(1.0 / 60.0)
		if f.state == "attack" and prev != "attack":
			starts += 1
		prev = f.state
		if main.phase != "fight":
			break
	ok(starts >= 2, "la IA toma la iniciativa (%d ataques en 10 s)" % starts)


func test_new() -> void:
	main.start_fight()
	main.phase = "fight"
	main.scripted = true
	var p: Fighter = main.player
	var f: Fighter = main.foe
	# golpe por contexto: pegado al rival sale un gancho; con atrás, empujón
	_place(p, f, 0.8)
	p.ctrl.move = Vector3.ZERO
	ok(p._choose("punch", false) == "hook", "pegado al rival: gancho")
	p.ctrl.move = Vector3(0, 0, 1)
	ok(p._choose("punch", false) == "shove", "atrás + golpe: empujón")
	p.ctrl.move = Vector3.ZERO
	_place(p, f, 1.4)
	ok(p._choose("punch", false) == "jab", "a media distancia: jab")
	# empujón contra la pared
	p.reset(Vector3(0, 0, -2.6), Vector3(0, 0, -5))
	f.reset(Vector3(0, 0, -3.45), Vector3(0, 0, 0))
	main._hit_log.clear()
	p.start_move("shove")
	var splat := false
	for i in 60:
		main.sim_step(1.0 / 60.0)
		splat = splat or f.move.get("name", "") == "wall_splat"
	ok(main._hit_log.size() == 1 and main._hit_log[0].damage < 3.0, "el empujón casi no hace daño")
	ok(splat, "el empujón estampa contra la pared")
	_run(150)
	# esquiva lateral en el último momento → ventana de contraataque → uppercut
	_place(p, f, 1.25)
	main._hit_log.clear()
	f.start_move("cross")
	var dodged := false
	for i in 40:
		if not dodged and f.move_t >= 0.07:
			p.start_dodge(p.global_transform.basis.x)
			dodged = true
		main.sim_step(1.0 / 60.0)
	ok(main._hit_log.is_empty(), "la esquiva lateral evita el directo")
	ok(f.evaded, "el golpe queda marcado como esquivado")
	ok(p.counter_t > 0.0 or p.move.get("name", "") == "uppercut", "se abre la ventana de contraataque")
	p.ctrl.light = true
	var up := false
	for i in 50:
		main.sim_step(1.0 / 60.0)
		up = up or p.move.get("name", "") == "uppercut"
	ok(up, "el contraataque es un uppercut")
	ok(main._hit_log.size() >= 1 and main._hit_log[0].get("counter", false), "el uppercut cuenta como contragolpe")
	Engine.time_scale = 1.0
	main.slowmo_t = 0.0
	_run(160)
	# equilibrio: bloquear muchos golpes rompe la guardia
	_place(p, f, 1.3)
	p.posture = 0.0
	main._hit_log.clear()
	var broke := false
	for k in 8:
		if broke:
			break
		f.start_move("cross")
		for i in 30:
			p.ctrl.guard = true
			main.sim_step(1.0 / 60.0)
		for h in main._hit_log:
			if h.result == "guard_break":
				broke = true
		f.global_position = p.global_position + (f.global_position - p.global_position).normalized() * 1.3
	p.ctrl.guard = false
	ok(broke, "bloquear sin parar acaba rompiendo la guardia")
	_run(150)
	# lesiones visibles
	p.reset(Vector3(0, 0, 0.65), Vector3(0, 0, -1))
	f.reset(Vector3(0, 0, -0.65), Vector3(0, 0, 1))
	for k in 4:
		p.start_move("cross")
		_run(40)
		p.global_position = Vector3(0, 0, 0.65)
		f.global_position = Vector3(0, 0, -0.65)
	ok(f.head_dmg > 10.0, "los golpes a la cara suman daño de cabeza (%.1f)" % f.head_dmg)
	ok(f.rig.face.nose > 0.0, "la nariz sangra tras varios golpes")
	var marks := 0
	for d in f.rig._damage_parts.values():
		marks += (d.marks as Array).size()
	ok(marks > 0, "quedan marcas de los impactos en la piel")
	f.reset(Vector3(0, 0, -1), Vector3(0, 0, 1))
	ok(f.rig.face.nose == 0.0 and f.head_dmg == 0.0, "la revancha empieza sin heridas")
	_run(30)


func _body_inside(f: Fighter) -> bool:
	var back := f.global_transform.basis.z
	back.y = 0
	back = back.normalized()
	var n: String = f.move.get("name", "")
	var lying := (n == "launch" and f.move_t > 0.3 and f.move_t < 1.6) or (n == "ko" and f.move_t > 0.3)
	var pts := [f.global_position]
	if lying:
		pts.append(f.global_position + back * 0.9)
		pts.append(f.global_position - back * 0.8)
	for q in pts:
		if Arena.constrain(q, 0.1).distance_to(q) > 0.03:
			return false
	return true


func test_combos() -> void:
	main.start_fight()
	main.phase = "fight"
	main.scripted = true
	var p: Fighter = main.player
	var f: Fighter = main.foe
	# machacar GOLPE: serie larga que el rival termina rompiendo
	_place(p, f, 1.1)
	main._hit_log.clear()
	var escaped := false
	for i in 240:
		if i % 6 == 0:
			p.ctrl.punch = true
		main.sim_step(1.0 / 60.0)
		for h in main._hit_log:
			if h.get("escape", false):
				escaped = true
		if escaped:
			break
	var names := {}
	var streak := 0
	var best := 0
	for h in main._hit_log:
		names[h.move] = true
		if h.result == "hit":
			streak += 1
			best = maxi(best, streak)
		else:
			streak = 0
	ok(best >= 6, "machacar GOLPE encadena una serie larga (%d golpes)" % best)
	ok(names.has("cross") and names.has("hook") and names.has("body_hook"), "la serie mezcla directo, gancho y gancho al cuerpo")
	ok(escaped, "tras %d golpes el rival sale despedido y se libera" % Fighter.ESCAPE_HITS)
	_run(120)
	# PATADA en mitad de la serie la remata
	_place(p, f, 1.1)
	main._hit_log.clear()
	for i in 150:
		if i in [0, 10, 20, 30]:
			p.ctrl.punch = true
		if i == 42:
			p.ctrl.kick = true
		main.sim_step(1.0 / 60.0)
	var kicked := false
	for h in main._hit_log:
		if h.move in ["roundhouse", "spin_kick"] and h.result == "hit":
			kicked = true
	ok(kicked, "una patada en mitad de la serie remata")
	_run(160)
	# patada baja sola: dobla la pierna
	_place(p, f, 1.3)
	main._hit_log.clear()
	p.ctrl.kick = true
	_run(40)
	ok(main._hit_log.size() == 1 and main._hit_log[0].reaction == "hit_leg", "PATADA a media distancia: patada baja que dobla la pierna")
	_run(80)
	# derribos junto a la pared y la jardinera: el cuerpo nunca entra en ellas
	var spots := [
		[Vector3(0, 0, -2.9), Vector3(0, 0, -3.9)],
		[Vector3(3.0, 0, 0), Vector3(4.0, 0, 0)],
		[Vector3(-1.7, 0, 1.7), Vector3(-2.6, 0, 2.6)],
		[Vector3(-3.0, 0, -3.0), Vector3(-3.9, 0, -3.9)],
	]
	var all_inside := true
	for sp in spots:
		p.reset(sp[0], sp[1])
		f.reset(sp[1], sp[0])
		p.start_move("spin_kick")
		for i in 150:
			main.sim_step(1.0 / 60.0)
			if not _body_inside(f) or not _body_inside(p):
				all_inside = false
		f.hp = f.max_hp
		_run(60)
	ok(all_inside, "derribado junto a pared o jardinera: el cuerpo no las atraviesa")
	# KO contra la pared
	p.reset(Vector3(0, 0, -2.8), Vector3(0, 0, -4))
	f.reset(Vector3(0, 0, -3.8), Vector3(0, 0, 0))
	f.hp = 1.0
	p.start_move("push_kick")
	p.charging = false
	var ko_inside := true
	for i in 200:
		main.sim_step(1.0 / 60.0)
		if not _body_inside(f):
			ko_inside = false
	ok(f.state == "ko", "KO contra la pared")
	ok(ko_inside, "el cuerpo del KO queda dentro del patio")
	Engine.time_scale = 1.0
	main.slowmo_t = 0.0
