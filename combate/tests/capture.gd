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
					elif mv == "guard":
						p.guard_w = 1.0
					elif mv == "stance":
						pass
					else:
						p.start_move(mv)
				for i in 8:
					p.move_t = t
					p.inert_t = 99.0
					p._update_rig(0.016)
					f._update_rig(0.016)
				var ang := float(args[4]) if args.size() > 4 else 90.0
				var c: Vector3 = p.global_position + Vector3(0, 1.0, 0)
				var cam: Camera3D = main.cam
				cam.global_position = c + Basis(Vector3.UP, deg_to_rad(ang)) * Vector3(0, 0.2, 3.0)
				cam.look_at(c, Vector3.UP)
				cam.fov = 50
				if frame == 12:
					_shot("pose_%s_%s_%d" % [mv, args[3], int(ang)])
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
				if frame % 22 == 0 and d < 1.8:
					main._on_attack_down()
					main._on_attack_up()
				if frame % 150 == 75:
					p.ctrl.heavy = true
				if frame % 30 == 0:
					_shot("fight_%04d" % frame)
				if frame > 900 or (main.phase == "result" and main.phase_t > 0.5):
					_shot("fight_end")
					return true
	return false
