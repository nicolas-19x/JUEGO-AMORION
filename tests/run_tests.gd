extends SceneTree
## Pruebas técnicas sin pantalla: godot --headless -s res://tests/run_tests.gd
## Comprueban datos, terreno, objetos, guardado local y el arranque del mundo.

var _failures := 0
var _checks := 0
var _frame := 0
var _main: Node


func check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("  FALLO: ", what)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 1:
		DirAccess.remove_absolute("user://world.json")  # empezar desde la isla original
		DirAccess.remove_absolute("user://world.json.bak")
		_test_catalog()
		_test_map_data()
		_test_local_store()
		_main = load("res://scenes/main/main.tscn").instantiate()
		root.add_child(_main)
		return false
	if _frame == 5:
		_test_world()
		_test_terrain_paint()
		_test_interactions()
		_test_building()
	if _frame == 6:
		print("Pruebas: %d comprobaciones, %d fallos" % [_checks, _failures])
		quit(1 if _failures > 0 else 0)
		return true
	return false


func _test_catalog() -> void:
	print("· catálogo")
	var cat := root.get_node("Catalog")
	check(cat.tabs.size() >= 5, "hay pestañas de catálogo")
	for t in cat.tabs:
		check(cat.items_in_tab(t["id"]).size() > 0, "la pestaña %s tiene objetos" % t["id"])
	check(cat.items.size() >= 25, "el catálogo tiene objetos (%d)" % cat.items.size())
	for id in cat.items:
		var it: Dictionary = cat.items[id]
		for k in ["id", "name", "category", "sprite", "anchor", "footprint", "surfaces"]:
			check(it.has(k), "%s tiene '%s'" % [id, k])
		check(ResourceLoader.exists(it.get("sprite", "")), "%s: existe el sprite" % id)
		for v in it.get("variants", []):
			check(ResourceLoader.exists(v.get("sprite", "")), "%s: existe el sprite de la variante %s" % [id, v.get("name")])
		if it.has("night_overlay"):
			check(ResourceLoader.exists(it["night_overlay"]), "%s: existe la capa nocturna" % id)
	check(cat.material_ids.size() == 6, "hay 6 materiales de terreno")
	for m in cat.materials:
		if m.has("atlas"):
			var tex: Texture2D = load(m["atlas"])
			check(tex != null and tex.get_width() == 320 and tex.get_height() == 64, "atlas %s es 20x4 tiles" % m["id"])
	for p in cat.appearance.get("presets", []):
		for layer in p["layers"]:
			check(ResourceLoader.exists("res://assets/characters/ramps/%s.png" % p["layers"][layer]), "rampa %s" % p["layers"][layer])


func _test_map_data() -> void:
	print("· mapa inicial")
	var map: Dictionary = root.get_node("Catalog").read_json("res://data/world/island_start.json")
	var w: int = map["size"][0]
	var h: int = map["size"][1]
	check(map["terrain"].size() == h, "el mapa tiene %d filas" % h)
	for row in map["terrain"]:
		check(String(row).length() == w, "todas las filas miden %d" % w)
	for o in map["objects"]:
		check(root.get_node("Catalog").items.has(o["item"]), "objeto del mapa existe en el catálogo: %s" % o["item"])
		var c: Array = o["cell"]
		check(c[0] >= 0 and c[1] >= 0 and c[0] < w and c[1] < h, "objeto dentro del mapa: %s" % o["item"])


func _test_local_store() -> void:
	print("· guardado local")
	var path := "user://test_store.json"
	check(LocalStore.save_json(path, {"a": 1, "b": [1, 2, 3]}), "guardar JSON")
	var back: Variant = LocalStore.load_json(path)
	check(back is Dictionary and int(back["a"]) == 1, "leer lo guardado")
	check(LocalStore.save_json(path, {"a": 2}), "guardar una segunda versión")
	# simula un archivo principal dañado: debe recuperar la copia de seguridad
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{roto")
	f.close()
	var rec: Variant = LocalStore.load_json(path)
	check(rec is Dictionary and int(rec["a"]) == 1, "recuperación desde .bak si el principal está dañado")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".bak")


func _test_world() -> void:
	print("· mundo")
	var world = _main.get("world")
	check(world != null, "el mundo se monta")
	if world == null:
		return
	check(world.objects.size() > 50, "objetos colocados (%d)" % world.objects.size())
	check(world.player != null, "existe el personaje")
	check(world.terrain.is_walkable(world.terrain.world_to_cell(world.player.global_position)), "el personaje aparece en suelo caminable")
	check(not world.terrain.is_walkable(Vector2i(0, 0)), "la esquina del mapa es agua")
	check(world.get_tree().get_nodes_in_group("interactables").size() >= 8, "hay objetos interactivos")
	var stage = _main.get("stage")
	check(stage.pixel_scale >= 1, "escala de píxel entera válida")


func _test_terrain_paint() -> void:
	print("· pintar terreno")
	var t = _main.get("world").terrain
	var c := Vector2i(26, 24)
	var before: int = t.material_at(c)
	t.paint(c, 4)
	check(t.material_at(c) == 4, "pintar una celda cambia su material")
	t.paint(c, before)
	check(t.material_at(c) == before, "se puede restaurar")
	check(t.to_rows().size() == t.size.y, "el terreno se serializa por filas")


func _object_of(world, item_id: String):
	for o in world.objects.values():
		if o.item["id"] == item_id:
			return o
	return null


## Coloca al personaje junto a un objeto, mirando hacia él, y actualiza el objetivo.
func _stand_near(world, obj) -> void:
	world.player.global_position = obj.global_position + Vector2(0, 10)
	world.player.facing = "up"
	world._update_target()


func _test_interactions() -> void:
	print("· interacciones")
	var world = _main.get("world")
	var bench = _object_of(world, "bench")
	_stand_near(world, bench)
	check(world.current_target == bench, "el banco se detecta como objetivo")
	world.interact()
	check(world.player.state == 1, "sentarse en el banco")
	world.player.stand_up()
	var lamp = _object_of(world, "lamp_post")
	_stand_near(world, lamp)
	var was: bool = lamp.light_on
	world.interact()
	check(lamp.light_on != was, "encender / apagar un farol")
	var tele = _object_of(world, "telescope")
	_stand_near(world, tele)
	check(world.current_target == tele, "el catalejo se detecta como objetivo")
	world.interact()
	check(world.in_cinematic, "contemplar desde el mirador inicia la cinemática")
	world.end_view()
	check(not world.in_cinematic and world.player.state == 0, "volver de la cinemática libera al personaje")
	var shown := [""]
	world.caption_requested.connect(func(t: String) -> void: shown[0] = t)
	var fountain = _object_of(world, "fountain")
	_stand_near(world, fountain)
	world.interact()
	check(shown[0].length() > 10, "mirar la fuente muestra su texto")


func _free_grass_cell(world, fp := Vector2i(1, 1)) -> Vector2i:
	for y in range(8, 34):
		for x in range(6, 48):
			var c := Vector2i(x, y)
			if world.can_place("bench" if fp.x == 2 else "chair", 0, c)["ok"] and not world.minors.has(c):
				if world.can_place("fence", 1, c)["ok"]:
					return c
	return Vector2i(-1, -1)


func _test_building() -> void:
	print("· construcción")
	var world = _main.get("world")
	var h: BuildHistory = world.history
	var n0: int = world.objects.size()
	# validación
	check(not world.can_place("bench", 0, Vector2i(1, 1))["ok"], "no se puede colocar un banco en el mar")
	check(world.can_place("lily_pad", 0, Vector2i(1, 1))["ok"], "un nenúfar sí va en el agua")
	var house_cell: Vector2i = _object_of(world, "house_cottage").cell
	check(not world.can_place("chair", 0, house_cell + Vector2i(1, 1))["ok"], "no se puede colocar dentro de la casa")
	# colocar
	var c := _free_grass_cell(world)
	check(c.x >= 0, "hay una celda libre para colocar")
	check(world.build_place("chair", 0, c), "colocar una silla")
	check(world.objects.size() == n0 + 1, "la silla existe")
	check(not world.can_place("chair", 0, c)["ok"], "la celda queda ocupada")
	var chair = null
	for o in world.objects.values():
		if o.item["id"] == "chair" and o.cell == c:
			chair = o
	check(chair != null and chair.meta.has("placed_at"), "el objeto guarda cuándo se colocó")
	check(world.milestones.has("first_object"), "se registra el hito del primer objeto")
	# deshacer / rehacer
	h.undo()
	check(world.objects.size() == n0, "deshacer quita la silla")
	h.redo()
	check(world.objects.size() == n0 + 1, "rehacer la vuelve a poner")
	chair = null
	for o in world.objects.values():
		if o.item["id"] == "chair" and o.cell == c:
			chair = o
	# mover
	var c2 := c + Vector2i(1, 0)
	if world.can_place("chair", 0, c2, chair.uid)["ok"]:
		check(world.build_move(chair.uid, c2), "mover la silla")
		check(chair.cell == c2, "la silla está en su nueva celda")
		h.undo()
		check(chair.cell == c, "deshacer el movimiento")
	# variantes (valla: horizontal / lateral)
	var fc := _free_grass_cell(world)
	check(world.build_place("fence", 0, fc), "colocar una valla")
	var fence = null
	for o in world.objects.values():
		if o.item["id"] == "fence" and o.cell == fc:
			fence = o
	check(world.build_cycle_variant(fence.uid) and fence.variant == 1, "girar la valla")
	h.undo()
	check(fence.variant == 0, "deshacer el giro")
	# guardar en el inventario y volver a colocar
	var inv0: int = world.inventory.size()
	check(world.build_remove(chair.uid, true), "guardar la silla")
	check(world.inventory.size() == inv0 + 1, "la silla está en el inventario")
	var inv_uid: String = world.inventory[-1]["uid"]
	check(world.build_place("chair", 0, c, inv_uid), "colocarla desde el inventario")
	check(world.inventory.size() == inv0 and world.objects.has(inv_uid), "conserva su identidad y su historia")
	h.undo()
	check(world.inventory.size() == inv0 + 1, "deshacer la devuelve al inventario")
	h.redo()
	# pintar terreno
	var pc := Vector2i(30, 30)
	while world.occupancy.has(pc) or world.terrain.material_at(pc) == 0:
		pc += Vector2i(1, 0)
	var before: int = world.terrain.material_at(pc)
	var target := 4 if before != 4 else 3
	check(world.can_paint(pc, target), "se puede pintar una celda libre")
	world.terrain.set_cell_fast(pc, target)
	world.build_paint_commit([[pc.x, pc.y, before, target]])
	check(world.terrain.material_at(pc) == target, "el trazo de pincel cambia el terreno")
	h.undo()
	check(world.terrain.material_at(pc) == before, "deshacer el trazo")
	h.redo()
	check(not world.can_paint(house_cell, 0), "no se pinta debajo de un objeto")
	# guardado del mundo
	world.flush_save()
	var saved: Dictionary = LocalStore.load_json("user://world.json", {})
	check(saved.get("version", 0) == 2, "el mundo se guarda con versión")
	check((saved.get("objects", []) as Array).size() == world.objects.size(), "se guardan todos los objetos")
	check(String(saved["terrain"][pc.y])[pc.x] == char(48 + target), "se guarda el terreno pintado")
	check((saved.get("inventory", []) as Array).size() == world.inventory.size(), "se guarda el inventario")
	DirAccess.remove_absolute("user://world.json")
	DirAccess.remove_absolute("user://world.json.bak")
