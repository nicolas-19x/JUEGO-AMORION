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
	if _frame == 6:
		print("Pruebas: %d comprobaciones, %d fallos" % [_checks, _failures])
		quit(1 if _failures > 0 else 0)
		return true
	return false


func _test_catalog() -> void:
	print("· catálogo")
	var cat := root.get_node("Catalog")
	check(cat.items.size() >= 25, "el catálogo tiene objetos (%d)" % cat.items.size())
	for id in cat.items:
		var it: Dictionary = cat.items[id]
		for k in ["id", "name", "category", "sprite", "anchor", "footprint", "surfaces"]:
			check(it.has(k), "%s tiene '%s'" % [id, k])
		check(ResourceLoader.exists(it.get("sprite", "")), "%s: existe el sprite" % id)
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
