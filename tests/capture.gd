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
	if _frames == 5 and _args.size() > 6 and _args[6] == "interact":
		_main.get("world").player.facing = "up"
	if _frames == (160 if _args.size() > 6 and _args[6] == "interact" else 50):
		var img := root.get_texture().get_image()
		img.save_png(_out)
		print("captura guardada: ", _out, " ", img.get_size())
		return true
	return false
