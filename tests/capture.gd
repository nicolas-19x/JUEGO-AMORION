extends SceneTree
## Captura de pantalla del juego real para revisión visual.
## Uso: godot --rendering-driver opengl3 -s res://tests/capture.gd -- <salida.png> [hora] [x] [y] [zoom] [mostrar_titulo]
## (necesita un display; en servidores se usa xvfb-run)

var _frames := 0
var _out := "user://capture.png"
var _main: Node
var _keep_title := false
var _args: PackedStringArray


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	_args = args
	_keep_title = args.size() > 5 and args[5] == "title"


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		# las preferencias se fijan cuando los autoloads ya han cargado
		var settings := root.get_node("Settings")
		settings.data["time_mode"] = _args[1] if _args.size() > 1 else "day"
		settings.data["last_position"] = [float(_args[2]), float(_args[3])] if _args.size() > 3 else []
		if _args.size() > 4:
			settings.data["zoom_index"] = int(_args[4])
		_main = load("res://scenes/main/main.tscn").instantiate()
		root.add_child(_main)
		return false
	if _frames == 2 and not _keep_title:
		_main.get_node("Hud").call("_dismiss_title")
	if _frames == 3:
		var world = _main.get("world")
		if world:
			world.camera.snap_to_target()
	if _frames == 6 and _args.size() > 6:
		var world = _main.get("world")
		match _args[6]:
			"settings":
				_main.get_node("Hud").open_settings()
			"interact":
				world.player.facing = "up"
				world._update_target()
				world.interact()
			"build":
				var hud = _main.get_node("Hud")
				hud.enter_build()
				var bm = hud.build_mode
				var what: String = _args[7] if _args.size() > 7 else ""
				if what == "select":
					var best = null
					for o in world.objects.values():
						if o.item["id"] == (_args[8] if _args.size() > 8 else "bench"):
							if best == null or o.global_position.distance_to(world.player.global_position) < best.global_position.distance_to(world.player.global_position):
								best = o
					if best:
						bm._select(best)
				elif what == "demo":
					# una pequeña sesión de construcción para la captura
					var p0: Vector2i = world.terrain.world_to_cell(world.player.global_position)
					world.build_place("picnic_blanket", 0, p0 + Vector2i(2, -3))
					world.build_place("apple_crate", 0, p0 + Vector2i(4, -3))
					world.build_place("garden_lantern", 0, p0 + Vector2i(1, -3))
					world.build_place("flower_pot", 2, p0 + Vector2i(5, -2))
					world.build_place("hydrangea", 0, p0 + Vector2i(-2, -4))
					world.build_place("sunflower", 0, p0 + Vector2i(-3, -4))
					world.build_place("planter", 1, p0 + Vector2i(-1, -6))
					bm.drawer.show_tab("flores")
					bm.drawer.select_key("item:flowers")
					bm.start_placing("flowers", 2)
					bm._move_ghost_to(p0 + Vector2i(1, -6))
				elif what == "paint":
					bm.drawer.show_tab("terreno")
					bm.start_painting(3)
				elif what != "":
					var tab: String = root.get_node("Catalog").get_item(what).get("tab", "naturaleza")
					bm.drawer.show_tab(tab)
					bm.drawer.select_key("item:" + what)
					bm.start_placing(what, 0)
					if _args.size() > 8 and _args[8] == "bad":
						bm._move_ghost_to(world.terrain.world_to_cell(world.player.global_position) + Vector2i(-1, -1))
	if _frames == 5 and _args.size() > 6 and _args[6] == "interact":
		_main.get("world").player.facing = "up"
	if _frames == (160 if _args.size() > 6 and _args[6] == "interact" else 70):
		var img := root.get_texture().get_image()
		img.save_png(_out)
		print("captura guardada: ", _out, " ", img.get_size())
		return true
	return false
