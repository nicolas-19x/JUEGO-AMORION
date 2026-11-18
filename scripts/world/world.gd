class_name World
extends Node2D
## La isla: terreno, objetos, personaje, cámara, ciclo de día y ambientación.
## Guarda su estado en local, resuelve interacciones y ofrece la API de
## construcción (validar, colocar, mover, variar, guardar, borrar, pintar)
## a través de operaciones reversibles.

signal interactable_changed(target: PlacedObject)
signal caption_requested(text: String)
signal cinematic_started(caption: String)
signal cinematic_finished
signal world_changed
signal inventory_changed
signal milestone_reached(text: String)

const MAP_PATH := "res://data/world/island_start.json"
const SAVE_PATH := "user://world.json"
const SAVE_VERSION := 2
const PLAYER_SCENE := preload("res://scenes/characters/player.tscn")
const TILE := 16
const REACH := 14.0
const SURFACE_NAMES := {"grass": "césped", "dirt": "tierra", "sand": "arena",
		"cobble": "adoquín", "wood": "madera", "water": "agua"}

var map_data: Dictionary
var terrain: TerrainGrid
var entities: Node2D
var player: Player
var camera: WorldCamera
var ambient: AmbientFx
var overlay: BuildOverlay
var modulate_node: CanvasModulate
var history: BuildHistory

var objects: Dictionary = {}  # uid -> PlacedObject
var occupancy: Dictionary = {}  # celda -> uid (objetos normales)
var minors: Dictionary = {}  # celda -> uid (matas de hierba: se apartan solas)
var inventory: Array = []  # datos de objetos guardados por los jugadores
var milestones: Dictionary = {}  # clave -> {at, by, item}

var current_target: PlacedObject
var in_cinematic := false
var build_mode := false

var _save_timer: Timer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	map_data = Catalog.read_json(MAP_PATH)
	terrain = TerrainGrid.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.build(map_data)

	entities = Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	add_child(entities)

	ambient = AmbientFx.new()
	ambient.name = "Ambient"
	add_child(ambient)

	_load_state()

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

	overlay = BuildOverlay.new()
	overlay.name = "BuildOverlay"
	overlay.world = self
	add_child(overlay)

	ambient.build(terrain.pixel_size(),
			[_cell_px(10, 15), _cell_px(13, 22), _cell_px(28, 22), _cell_px(40, 8)],
			[_cell_px(10, 15), _cell_px(31, 21), _cell_px(24, 26)])

	history = BuildHistory.new(self)
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 1.2
	_save_timer.timeout.connect(save_world)
	add_child(_save_timer)
	world_changed.connect(func() -> void: _save_timer.start())


func _process(_delta: float) -> void:
	modulate_node.color = WorldClock.ambient_color()
	if not in_cinematic and not build_mode:
		_update_target()


# ----------------------------------------------------------- guardado local
func _load_state() -> void:
	var saved: Variant = LocalStore.load_json(SAVE_PATH, null)
	var objs: Array = []
	if saved is Dictionary and int(saved.get("version", 0)) == SAVE_VERSION \
			and (saved.get("terrain", []) as Array).size() == terrain.size.y:
		terrain.load_rows(saved["terrain"])
		objs = saved.get("objects", [])
		inventory = saved.get("inventory", [])
		milestones = saved.get("milestones", {})
	else:
		var n := 0
		for o in map_data.get("objects", []):
			objs.append({"uid": "init%03d" % n, "item": o["item"], "cell": o["cell"],
					"variant": int(o.get("variant", 0)), "meta": {}, "light_on": true})
			n += 1
	for d in objs:
		_add_object(d, false)


func save_world() -> void:
	var objs := []
	for o in objects.values():
		objs.append((o as PlacedObject).to_data())
	var data := {"version": SAVE_VERSION, "saved_at": int(Time.get_unix_time_from_system()),
			"terrain": terrain.to_rows(), "objects": objs, "inventory": inventory,
			"milestones": milestones}
	LocalStore.save_json(SAVE_PATH, data)


func flush_save() -> void:
	if _save_timer and not _save_timer.is_stopped():
		_save_timer.stop()
	save_world()


# ------------------------------------------------ objetos (bajo nivel, sin historial)
func _add_object(d: Dictionary, pop: bool) -> PlacedObject:
	var base := Catalog.get_item(String(d["item"]))
	if base.is_empty():
		push_warning("World: objeto desconocido %s" % d["item"])
		return null
	var obj := PlacedObject.new()
	obj.setup(base, Vector2i(int(d["cell"][0]), int(d["cell"][1])), String(d["uid"]),
			d.get("meta", {}), int(d.get("variant", 0)))
	obj.light_on = bool(d.get("light_on", true))
	entities.add_child(obj)
	objects[obj.uid] = obj
	_occupy(obj, true)
	if obj.def.get("emitter", "") == "petals":
		var fx := AmbientFx.petals(obj.position + Vector2(0, -30))
		fx.set_meta("owner_uid", obj.uid)
		ambient.add_child(fx)
	if obj.def.has("chimney"):
		var sm := AmbientFx.chimney_smoke(obj.position + Vector2(obj.def["chimney"][0], obj.def["chimney"][1]))
		sm.set_meta("owner_uid", obj.uid)
		ambient.add_child(sm)
	if pop:
		obj.play_pop()
		ambient.add_child(AmbientFx.dust(obj.position))
	return obj


func _remove_object(uid: String) -> Dictionary:
	var obj: PlacedObject = objects.get(uid)
	if obj == null:
		return {}
	var d := obj.to_data()
	_occupy(obj, false)
	objects.erase(uid)
	for fx in ambient.get_children():
		if fx.has_meta("owner_uid") and fx.get_meta("owner_uid") == uid:
			fx.queue_free()
	if current_target == obj:
		current_target = null
		interactable_changed.emit(null)
	ambient.add_child(AmbientFx.dust(obj.position))
	obj.queue_free()
	return d


func _move_object(uid: String, to: Vector2i) -> void:
	var obj: PlacedObject = objects.get(uid)
	if obj == null:
		return
	_occupy(obj, false)
	obj.set_cell(to)
	_occupy(obj, true)
	_sync_fx(obj)
	obj.play_pop()
	ambient.add_child(AmbientFx.dust(obj.position))


func _set_variant(uid: String, v: int) -> void:
	var obj: PlacedObject = objects.get(uid)
	if obj == null:
		return
	_occupy(obj, false)
	obj.set_variant(v)
	obj.set_cell(obj.cell)
	_occupy(obj, true)
	obj.play_pop()


func _occupy(obj: PlacedObject, on: bool) -> void:
	var table := minors if obj.def.get("minor", false) else occupancy
	for c in obj.footprint_cells():
		if on:
			table[c] = obj.uid
		elif table.get(c) == obj.uid:
			table.erase(c)


func _sync_fx(obj: PlacedObject) -> void:
	for fx in ambient.get_children():
		if fx.has_meta("owner_uid") and fx.get_meta("owner_uid") == obj.uid:
			if obj.def.has("chimney"):
				fx.position = obj.position + Vector2(obj.def["chimney"][0], obj.def["chimney"][1])
			else:
				fx.position = obj.position + Vector2(0, -30)


# ------------------------------------------------------------ validación
## ¿Se puede poner este objeto aquí? Devuelve {ok, reason, minors}.
func can_place(item_id: String, variant: int, at: Vector2i, ignore_uid := "") -> Dictionary:
	var base := Catalog.get_item(item_id)
	if base.is_empty():
		return {"ok": false, "reason": "Objeto desconocido", "minors": []}
	var d := Catalog.resolve(base, variant)
	var surfaces: Array = d.get("surfaces", [])
	var is_minor: bool = d.get("minor", false)
	var hit: Array = []
	for c in Catalog.footprint_cells(d, at):
		if not terrain.in_bounds(c):
			return {"ok": false, "reason": "Fuera de la isla", "minors": []}
		var mat: String = Catalog.material_ids[terrain.material_at(c)]
		if not surfaces.has(mat):
			return {"ok": false, "reason": "Va sobre " + _surface_text(surfaces), "minors": []}
		if occupancy.has(c) and occupancy[c] != ignore_uid:
			return {"ok": false, "reason": "Ya hay algo aquí", "minors": []}
		if minors.has(c) and minors[c] != ignore_uid:
			if is_minor:
				return {"ok": false, "reason": "Ya hay hierba aquí", "minors": []}
			if not hit.has(minors[c]):
				hit.append(minors[c])
	if d.has("collision") and not d.get("flat", false) and player:
		var r := Rect2(Vector2(at * TILE), Vector2(int(d["footprint"][0]), int(d["footprint"][1])) * TILE)
		if r.grow(-1).has_point(player.global_position + Vector2(0, -2)):
			return {"ok": false, "reason": "Tu personaje está justo ahí", "minors": []}
	return {"ok": true, "reason": "", "minors": hit}


func _surface_text(surfaces: Array) -> String:
	var names := []
	for s in surfaces:
		names.append(SURFACE_NAMES.get(s, s))
	if names.size() <= 1:
		return ", ".join(names)
	return ", ".join(names.slice(0, names.size() - 1)) + " o " + names[-1]


# ----------------------------------------------- construcción (con historial)
func build_place(item_id: String, variant: int, at: Vector2i, from_inventory_uid := "") -> bool:
	var check := can_place(item_id, variant, at)
	if not check["ok"]:
		return false
	var data := {}
	if from_inventory_uid != "":
		for d in inventory:
			if d["uid"] == from_inventory_uid:
				data = (d as Dictionary).duplicate(true)
		if data.is_empty():
			return false
		data["cell"] = [at.x, at.y]
		data["variant"] = variant
	else:
		data = {"uid": new_uid(), "item": item_id, "cell": [at.x, at.y], "variant": variant,
				"meta": {"placed_by": Settings.character_preset().get("name", ""),
						"placed_at": int(Time.get_unix_time_from_system())}, "light_on": true}
	history.run({"t": "place", "obj": data, "minors": _minor_data(check["minors"]),
			"from_inventory": from_inventory_uid != ""})
	_check_milestones(Catalog.get_item(item_id))
	return true


func build_move(uid: String, to: Vector2i) -> bool:
	var obj: PlacedObject = objects.get(uid)
	if obj == null or to == obj.cell:
		return false
	var check := can_place(obj.item["id"], obj.variant, to, uid)
	if not check["ok"]:
		return false
	history.run({"t": "move", "uid": uid, "from": [obj.cell.x, obj.cell.y], "to": [to.x, to.y],
			"minors": _minor_data(check["minors"])})
	return true


func build_cycle_variant(uid: String) -> bool:
	var obj: PlacedObject = objects.get(uid)
	if obj == null:
		return false
	var n := Catalog.variant_count(obj.item)
	if n <= 1:
		return false
	for step in range(1, n):
		var v := (obj.variant + step) % n
		var check := can_place(obj.item["id"], v, obj.cell, uid)
		if check["ok"]:
			history.run({"t": "variant", "uid": uid, "from": obj.variant, "to": v})
			return true
	return false


func build_remove(uid: String, to_inventory: bool) -> bool:
	var obj: PlacedObject = objects.get(uid)
	if obj == null:
		return false
	history.run({"t": "remove", "obj": obj.to_data(), "to_inventory": to_inventory})
	return true


## Registra un trazo de pincel ya dibujado (celdas [x, y, antes, después]).
func build_paint_commit(changes: Array) -> void:
	if changes.is_empty():
		terrain.finalize_changes()
		return
	var hit := []
	for ch in changes:
		var c := Vector2i(ch[0], ch[1])
		if minors.has(c):
			var obj: PlacedObject = objects[minors[c]]
			var mat: String = Catalog.material_ids[int(ch[3])]
			if not (obj.def.get("surfaces", []) as Array).has(mat) and not hit.has(obj.uid):
				hit.append(obj.uid)
	# el trazo ya está pintado: se registra sin volver a pintarlo
	var op := {"t": "paint", "cells": changes, "minors": _minor_data(hit)}
	for uid in hit:
		_remove_object(uid)
	terrain.finalize_changes()
	history._undo.push_back(op)
	history._redo.clear()
	history.changed.emit()
	world_changed.emit()
	_check_milestone("first_paint", "")


## ¿Se puede pintar esta celda con este material? (no bajo objetos ni bajo el personaje)
func can_paint(c: Vector2i, material: int) -> bool:
	if not terrain.in_bounds(c) or terrain.material_at(c) == material:
		return false
	if occupancy.has(c):
		return false
	if not Catalog.materials[material].get("walkable", true):
		if terrain.world_to_cell(player.global_position + Vector2(0, -2)) == c:
			return false
	return true


func apply_op(op: Dictionary) -> void:
	match String(op["t"]):
		"place":
			for m in op["minors"]:
				_remove_object(m["uid"])
			if op.get("from_inventory", false):
				_inventory_take(op["obj"]["uid"])
			_add_object(op["obj"], true)
		"remove":
			_remove_object(op["obj"]["uid"])
			if op["to_inventory"]:
				inventory.append(op["obj"])
				inventory_changed.emit()
		"move":
			for m in op["minors"]:
				_remove_object(m["uid"])
			_move_object(op["uid"], Vector2i(op["to"][0], op["to"][1]))
		"variant":
			_set_variant(op["uid"], int(op["to"]))
		"paint":
			for ch in op["cells"]:
				terrain.set_cell_fast(Vector2i(ch[0], ch[1]), int(ch[3]))
			for m in op["minors"]:
				_remove_object(m["uid"])
			terrain.finalize_changes()
	world_changed.emit()


func revert_op(op: Dictionary) -> void:
	match String(op["t"]):
		"place":
			_remove_object(op["obj"]["uid"])
			if op.get("from_inventory", false):
				inventory.append(op["obj"])
				inventory_changed.emit()
			for m in op["minors"]:
				_add_object(m, false)
		"remove":
			if op["to_inventory"]:
				_inventory_take(op["obj"]["uid"])
			_add_object(op["obj"], true)
		"move":
			_move_object(op["uid"], Vector2i(op["from"][0], op["from"][1]))
			for m in op["minors"]:
				_add_object(m, false)
		"variant":
			_set_variant(op["uid"], int(op["from"]))
		"paint":
			for ch in op["cells"]:
				terrain.set_cell_fast(Vector2i(ch[0], ch[1]), int(ch[2]))
			terrain.finalize_changes()
			for m in op["minors"]:
				_add_object(m, false)
	world_changed.emit()


func _inventory_take(uid: String) -> void:
	for i in inventory.size():
		if inventory[i]["uid"] == uid:
			inventory.remove_at(i)
			inventory_changed.emit()
			return


func _minor_data(uids: Array) -> Array:
	var out := []
	for u in uids:
		if objects.has(u):
			out.append((objects[u] as PlacedObject).to_data())
	return out


func new_uid() -> String:
	return "%x%04x" % [int(Time.get_unix_time_from_system() * 1000.0), _rng.randi() % 65536]


## Objeto bajo un punto del mundo (el que está más al frente).
func object_at(p: Vector2) -> PlacedObject:
	var best: PlacedObject = null
	for o in objects.values():
		var obj := o as PlacedObject
		var inside := obj.sprite_rect().has_point(p)
		if not inside:
			continue
		# el píxel tocado debe ser visible (no el hueco transparente del sprite)
		var local := Vector2i(p - obj.sprite_rect().position)
		var img := Catalog.image(obj.def["sprite"])
		if img and img.get_pixelv(local).a < 0.3 and not obj.footprint_rect().grow(2).has_point(p):
			continue
		if best == null or obj.global_position.y > best.global_position.y:
			best = obj
	return best


# --------------------------------------------------------------- hitos
func _check_milestones(it: Dictionary) -> void:
	var id: String = it.get("id", "")
	_check_milestone("first_object", id)
	if id.begins_with("tree_") or id == "sapling":
		_check_milestone("first_tree", id)
	if it.get("tab", "") == "flores":
		_check_milestone("first_flower", id)
	if it.has("light"):
		_check_milestone("first_light", id)
	if (it.get("interaction", {}) as Dictionary).get("type", "") == "sit":
		_check_milestone("first_seat", id)


func _check_milestone(key: String, item_id: String) -> void:
	if milestones.has(key) or not Catalog.milestones.has(key):
		return
	milestones[key] = {"at": int(Time.get_unix_time_from_system()), "item": item_id,
			"by": Settings.character_preset().get("name", "")}
	milestone_reached.emit(String(Catalog.milestones[key]))


# ----------------------------------------------------------- modo construir
func set_build_mode(on: bool) -> void:
	build_mode = on
	player.lock(on)
	overlay.active = on
	camera.free_mode = on
	if on:
		camera.free_goal = camera.global_position
		if current_target:
			current_target = null
			interactable_changed.emit(null)
	else:
		flush_save()


# ----------------------------------------------------------- interacción
func _update_target() -> void:
	var best: PlacedObject = null
	var best_d := REACH
	if player.state == Player.State.FREE:
		var probe := player.global_position + player.facing_vector() * 6.0 + Vector2(0, -3)
		for node in get_tree().get_nodes_in_group("interactables"):
			var obj := node as PlacedObject
			if obj.is_queued_for_deletion():
				continue
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
			world_changed.emit()
			if WorldClock.night_factor() < 0.05:
				caption_requested.emit("Solo luce cuando cae la tarde.")
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
	flush_save()
