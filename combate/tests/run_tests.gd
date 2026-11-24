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
	var by_ai := 0
	for h in main._hit_log:
		if h.attacker == f:
			by_ai += 1
	ok(by_ai >= 2, "la IA también ataca")
