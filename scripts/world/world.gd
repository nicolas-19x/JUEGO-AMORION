class_name World
extends Node2D
## La isla: terreno, objetos, personaje, cámara, ciclo de día y ambientación.
## También resuelve las interacciones con objetos (sentarse, contemplar, mirar,
## encender faroles).

signal interactable_changed(target: PlacedObject)
signal caption_requested(text: String)
signal cinematic_started(caption: String)
signal cinematic_finished

const MAP_PATH := "res://data/world/island_start.json"
const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")
const TILE := 16
const REACH := 14.0

var map_data: Dictionary
var terrain: TerrainGrid
var entities: Node2D
var player: Player
var camera: WorldCamera
var ambient: AmbientFx
var modulate_node: CanvasModulate
var objects: Dictionary = {}  # uid -> PlacedObject
var current_target: PlacedObject
var in_cinematic := false


func _ready() -> void:
	map_data = Catalog.read_json(MAP_PATH)
	terrain = TerrainGrid.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.build(map_data)

	entities = Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	add_child(entities)
	var n := 0
	for o in map_data.get("objects", []):
		spawn_object(o["item"], Vector2i(int(o["cell"][0]), int(o["cell"][1])), "init%03d" % n)
		n += 1

	player = PLAYER_SCENE.instantiate()
	entities.add_child(player)
	player.global_position = _spawn_point()
	player.stepped.connect(_on_player_step)

	camera = WorldCamera.new()
	add_child(camera)
	camera.target = player
	camera.set_bounds(Rect2(Vector2(-32, -48), terrain.pixel_size() + Vector2(64, 80)))
	camera.make_current()
	camera.snap_to_target()

	modulate_node = CanvasModulate.new()
	add_child(modulate_node)

	ambient = AmbientFx.new()
	ambient.name = "Ambient"
	add_child(ambient)
	ambient.build(terrain.pixel_size(),
			[_cell_px(10, 15), _cell_px(13, 22), _cell_px(28, 22), _cell_px(40, 8)],
			[_cell_px(10, 15), _cell_px(31, 21), _cell_px(24, 26)])


func _process(_delta: float) -> void:
	modulate_node.color = WorldClock.ambient_color()
	if not in_cinematic:
		_update_target()


# --------------------------------------------------------------- objetos
func spawn_object(item_id: String, cell: Vector2i, uid: String, meta := {}) -> PlacedObject:
	var def := Catalog.get_item(item_id)
	if def.is_empty():
		push_warning("World: objeto desconocido %s" % item_id)
		return null
	var obj := PlacedObject.new()
	obj.setup(def, cell, uid, meta)
	entities.add_child(obj)
	objects[uid] = obj
	if def.get("emitter", "") == "petals":
		ambient_add(AmbientFx.petals(obj.position + Vector2(0, -30)))
	if def.has("chimney"):
		ambient_add(AmbientFx.chimney_smoke(obj.position + Vector2(def["chimney"][0], def["chimney"][1])))
	return obj


func ambient_add(node: Node2D) -> void:
	# los efectos pueden crearse antes que el nodo de ambiente
	if ambient == null:
		add_child.call_deferred(node)
	else:
		ambient.add_child(node)


# ----------------------------------------------------------- interacción
func _update_target() -> void:
	var best: PlacedObject = null
	var best_d := REACH
	if player.state == Player.State.FREE:
		var probe := player.global_position + player.facing_vector() * 6.0 + Vector2(0, -3)
		for node in get_tree().get_nodes_in_group("interactables"):
			var obj := node as PlacedObject
			var d := obj.distance_to_point(probe)
			if d < best_d:
				best_d = d
				best = obj
	if best != current_target:
		current_target = best
		interactable_changed.emit(best)


func interact() -> void:
	if current_target == null:
		return
	var it := current_target.interaction()
	match String(it.get("type", "")):
		"inspect":
			AudioDirector.play("chime", -10.0)
			caption_requested.emit(String(it.get("text", "")))
		"toggle_light":
			current_target.toggle_light()
			AudioDirector.play("click", -6.0)
			if WorldClock.night_factor() < 0.05:
				caption_requested.emit("El farol solo luce cuando cae la tarde.")
		"sit":
			var seat: Array = it.get("seat", [0, 0])
			player.sit_at(current_target.global_position + Vector2(seat[0], seat[1]))
		"view":
			var off: Array = it.get("view_offset", [0, -100])
			_start_view(current_target.global_position + Vector2(off[0], off[1]), String(it.get("caption", "")))


func interaction_label() -> String:
	if current_target == null:
		return ""
	var it := current_target.interaction()
	if it.get("type") == "toggle_light":
		return "Apagar" if current_target.light_on else "Encender"
	return String(it.get("label", "Usar"))


func _start_view(goal: Vector2, caption: String) -> void:
	in_cinematic = true
	player.lock(true)
	current_target = null
	interactable_changed.emit(null)
	camera.start_cinematic(goal)
	AudioDirector.play("chime", -8.0, 0.9)
	cinematic_started.emit(caption)


func end_view() -> void:
	if not in_cinematic:
		return
	in_cinematic = false
	camera.end_cinematic()
	player.lock(false)
	cinematic_finished.emit()


# --------------------------------------------------------------- auxiliares
func _on_player_step(pos: Vector2) -> void:
	AudioDirector.footstep(terrain.footstep_at(pos + Vector2(0, -2)))


func _spawn_point() -> Vector2:
	var last: Variant = Settings.get_value("last_position")
	if last is Array and last.size() == 2:
		var p := Vector2(last[0], last[1])
		if terrain.is_walkable(terrain.world_to_cell(p)):
			return p
	var s: Array = map_data.get("spawn", [400, 380])
	return Vector2(s[0], s[1])


func _cell_px(x: int, y: int) -> Vector2:
	return Vector2(x * TILE + TILE / 2.0, y * TILE + TILE / 2.0)


func save_player_position() -> void:
	Settings.set_value("last_position", [roundf(player.global_position.x), roundf(player.global_position.y)])
