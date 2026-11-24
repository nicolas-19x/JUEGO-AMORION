extends SceneTree
## Capturas reales del juego para revisión visual.
## Uso (necesita display; en servidores: xvfb-run):
##   godot --rendering-driver opengl3 -s res://tests/capture.gd -- <dir> menu
##   godot ... -- <dir> fight            (combate guionizado, capturas periódicas)
##   godot ... -- <dir> pose jab 0.115 [ángulo]  (pose congelada, vista lateral)

var out := "/tmp"
var mode := "fight"
var args: PackedStringArray
var main: Node
var frame := 0
var shots := 0


func _initialize() -> void:
	args = OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 1:
		mode = args[1]
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _shot(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [out, name])
	shots += 1


func _process(_delta: float) -> bool:
	frame += 1
	match mode:
		"menu":
			if frame == 90:
				_shot("menu")
				return true
		"pose":
			if frame == 3:
				main.start_fight()
				main.paused = true
				main._hint.modulate.a = 0.0
				main._banner.modulate.a = 0.0
			if frame >= 4:
				var p = main.player
				var f = main.foe
				var mv: String = args[2]
				var t := float(args[3])
				if frame == 4:
					p.reset(Vector3(0, 0, 0.9), Vector3(0, 0, -1))
					f.reset(Vector3(0, 0, -0.9), Vector3(0, 0, 1))
					if mv.begins_with("hit") or mv in ["stagger", "launch", "ko", "wall_splat", "dazed", "parried", "blockstun", "clinched"]:
						p.start_reaction(mv, f, 1.0, 1.0)
						f.start_reaction(mv, p, 1.0, 1.0)
					elif mv == "guard":
						p.guard_w = 1.0
					elif mv == "stance":
						pass
					else:
						p.start_move(mv)
				for i in 8:
					p.move_t = t
					p.inert_t = 99.0
					if not f.move.is_empty():
						f.move_t = t
						f.inert_t = 99.0
					p._update_rig(0.016)
					f._update_rig(0.016)
				var ang := float(args[4]) if args.size() > 4 else 90.0
				var face := args.size() > 5 and args[5] == "face"
				var who = f if args.size() > 6 and args[6] == "foe" else p
				var c: Vector3 = who.rig.points.head if face else p.global_position + Vector3(0, 1.0, 0)
				var cam: Camera3D = main.cam
				var base_yaw: float = who.yaw if face else 0.0
				cam.global_position = c + Basis(Vector3.UP, base_yaw + deg_to_rad(ang)) * (Vector3(0, 0.05, -0.75) if face else Vector3(0, 0.2, 3.0))
				cam.look_at(c, Vector3.UP)
				cam.fov = 50
				if frame == 12:
					_shot("pose_%s_%s_%d%s" % [mv, args[3], int(ang), ("_" + str(args[6]) if args.size() > 6 else "")])
					return true
		"seq":
			# secuencia de un golpe: <movimiento> <ángulo> ; cada 3 fotogramas desde el inicio
			if frame == 3:
				main.start_fight()
				main.phase = "fight"
				main.scripted = true
				main.set_physics_process(false)
				main.touch.visible = false
				main.hud.visible = false
				main._hint.visible = false
				main._banner.visible = false
				main.player.reset(Vector3(0, 0, 0.55), Vector3(0, 0, -1))
				main.foe.reset(Vector3(0, 0, -0.55), Vector3(0, 0, 1))
				for i in 20:
					main.sim_step(1.0 / 60.0)
				main.player.start_move(args[2])
				main.player.charging = false
			if frame > 3:
				main.sim_step(1.0 / 60.0)
				var ang := float(args[3]) if args.size() > 3 else 90.0
				var c: Vector3 = (main.player.global_position + main.foe.global_position) * 0.5 + Vector3(0, 1.1, 0)
				var cam: Camera3D = main.cam
				cam.global_position = c + Basis(Vector3.UP, deg_to_rad(ang)) * Vector3(0, 0.15, 3.2)
				cam.look_at(c, Vector3.UP)
				cam.fov = 45
				var every := int(args[4]) if args.size() > 4 else 3
				if (frame - 4) % every == 0 and frame < 4 + every * 16:
					_shot("seq_%s_%02d" % [args[2], (frame - 4) / every])
				if frame >= 4 + every * 16:
					return true
		"pause":
			if frame == 3:
				main.start_fight()
				main._set_phase("fight")
				main._hint.modulate.a = 0.0
			if frame == 30:
				main._toggle_pause()
			if frame == 36:
				_shot("pause")
				return true
		"art":
			# retrato: ambos luchadores, sin interfaz, desde varios ángulos
			if frame == 3:
				main.start_fight()
				main.paused = true
				main.touch.visible = false
				main.hud.visible = false
				main._hint.modulate.a = 0.0
				main._banner.modulate.a = 0.0
				main.player.reset(Vector3(-0.55, 0, 0), Vector3(-0.55, 0, 3))
				main.foe.reset(Vector3(0.55, 0, 0), Vector3(0.55, 0, 3))
			if frame >= 4:
				for f in [main.player, main.foe]:
					f.guard_w = float(args[3]) if args.size() > 3 else 0.0
					f._update_rig(0.016)
				var ang := float(args[2]) if args.size() > 2 else 0.0
				var c := Vector3(0, 1.0, 0)
				var close := args.size() > 4 and args[4] == "close"
				var cam: Camera3D = main.cam
				var dist := 1.3 if close else 3.4
				var tgt := c + (Vector3(0, 0.55, 0) if close else Vector3.ZERO)
				cam.global_position = tgt + Basis(Vector3.UP, deg_to_rad(ang)) * Vector3(0, 0.15, dist)
				cam.look_at(tgt, Vector3.UP)
				cam.fov = 40
				if frame == 10:
					_shot("art_%s_%s%s" % [args[2] if args.size() > 2 else "0", args[3] if args.size() > 3 else "0", "_close" if close else ""])
					return true
		"damage":
			# primeros planos con heridas: cara y torso tras un combate duro
			if frame == 3:
				main.start_fight()
				main.paused = true
				main._hint.modulate.a = 0.0
				main._banner.modulate.a = 0.0
				main.touch.visible = false
				var p = main.player
				var f = main.foe
				p.reset(Vector3(0, 0, 0.9), Vector3(0, 0, -1))
				f.reset(Vector3(0, 0, -0.9), Vector3(0, 0, 1))
				for i in 4:
					p._update_rig(0.016)
					f._update_rig(0.016)
			if frame == 5:
				var p = main.player
				var f = main.foe
				var lvl := int(args[2]) if args.size() > 2 else 3
				for fi in [f, p]:
					if fi == p and lvl < 2:
						continue
					var h: Vector3 = fi.rig.points.head
					var c: Vector3 = fi.rig.points.chest
					var fwd: Vector3 = -fi.global_transform.basis.z
					var rt: Vector3 = fi.global_transform.basis.x
					for k in lvl * 2:
						fi._take_injury(h + fwd * 0.1 + rt * 0.05 * (1 if k % 2 else -1), 9.0, 2 + (k % 2), 1.0 if k % 2 else -1.0, true, k == 3)
						fi._take_injury(c + fwd * 0.12 + rt * (0.08 if k % 2 else -0.06) + Vector3.UP * (0.05 * (k % 3)), 9.0, 2, 1.0, false, false)
					fi.bleed = 0.8
					fi.rig.face.smear = 0.25 * lvl
					fi.rig.update_face(0.5)
					fi.hp = 40
				var fx = main.fx
				for k in 3:
					fx.blood(f.rig.points.head + Vector3(0, 0, 0.1), Vector3(0.3, 0.2, 1.0), 2.0)
				fx.spit(f.rig.points.nose, Vector3(0.4, 0.1, 1.0))
				var ch: Vector3 = f.rig.points.chest
				for k in 5:
					f.rig.add_blood(ch + Vector3.UP * 0.12 + Vector3(0, 0, 0.12) + Vector3(randf_range(-0.07, 0.07), 0, 0), 0.6)
				for k in 4:
					p.rig.add_blood(p.rig.points.chest + Vector3(randf_range(-0.1, 0.1), randf_range(-0.05, 0.1), -0.12), 0.6)
				fx.pool("p", f.global_position + Vector3(0.4, 0, 0.3), 0.8)
				fx.wall_stain(Vector3(0.8, 1.2, -Arena.HALF + 0.02), Vector3(0, 0, 1), 1.0)
				for i in 8:
					fx.process_fx(1.0 / 60.0, main.cam)
			if frame >= 6:
				var who = main.foe if args.size() < 4 or args[3] == "foe" else main.player
				var tgt: Vector3 = who.rig.points.head if args.size() < 5 or args[4] == "face" else who.rig.points.chest
				var fwd: Vector3 = -who.global_transform.basis.z
				var cam: Camera3D = main.cam
				var dist := 0.75 if args.size() < 5 or args[4] == "face" else 1.6
				cam.global_position = tgt + (fwd * 0.9 + who.global_transform.basis.x * 0.35).normalized() * dist + Vector3.UP * 0.05
				cam.look_at(tgt, Vector3.UP)
				cam.fov = 40
				for i in 2:
					main.player._update_rig(0.016)
					main.foe._update_rig(0.016)
				if frame == 14:
					_shot("damage_%s_%s_%s" % [args[2] if args.size() > 2 else "3", args[3] if args.size() > 3 else "foe", args[4] if args.size() > 4 else "face"])
					return true
		"fight":
			if frame == 3:
				main.difficulty = int(args[2]) if args.size() > 2 else 1
				main.start_fight()
			if frame > 3:
				var p = main.player
				var f = main.foe
				var d: float = p.global_position.distance_to(f.global_position)
				var to: Vector3 = (f.global_position - p.global_position).normalized()
				p.ctrl.move = to if d > 1.3 else to.cross(Vector3.UP) * 0.4
				if frame % 7 == 0 and d < 1.6:
					main._on_attack_down()
					main._on_attack_up()
				if frame % 41 == 0 and d < 1.6:
					main._on_kick_down()
					main._on_kick_up()
				if frame % 15 == 0:
					_shot("fight_%04d" % frame)
				if (main.phase == "ko" or main.phase == "replay") and frame % 8 == 0:
					_shot("ko_%04d" % frame)
				if main.cam.shot_t >= 0.0 and frame % 3 == 0:
					_shot("shot_%04d" % frame)
				if frame > 1400 or (main.phase == "result" and main.phase_t > 0.5):
					_shot("fight_end")
					return true
	return false
