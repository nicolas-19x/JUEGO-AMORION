extends Node
## Catálogo de objetos y materiales, cargado desde data/ (JSON).
## Añadir un mueble o una planta = añadir una entrada JSON y su sprite.

const ITEMS_DIR := "res://data/items/"
const MATERIALS_PATH := "res://data/world/materials.json"
const APPEARANCE_PATH := "res://data/characters/appearance.json"
const TABS_PATH := "res://data/catalog/tabs.json"

var items: Dictionary = {}
var materials: Array = []
var material_ids: PackedStringArray = []
var appearance: Dictionary = {}
var tabs: Array = []
var milestones: Dictionary = {}

var _textures: Dictionary = {}
var _images: Dictionary = {}
var _materials_cache: Dictionary = {}


func _ready() -> void:
	_load_items()
	materials = read_json(MATERIALS_PATH).get("materials", [])
	for m in materials:
		material_ids.append(m["id"])
	appearance = read_json(APPEARANCE_PATH)
	var t := read_json(TABS_PATH)
	tabs = t.get("tabs", [])
	milestones = t.get("milestones", {})


func _load_items() -> void:
	var dir := DirAccess.open(ITEMS_DIR)
	if dir == null:
		push_error("Catalog: no existe %s" % ITEMS_DIR)
		return
	for file in dir.get_files():
		if not file.ends_with(".json"):
			continue
		var data: Dictionary = read_json(ITEMS_DIR + file)
		for it in data.get("items", []):
			if items.has(it["id"]):
				push_warning("Catalog: id duplicado %s" % it["id"])
			items[it["id"]] = it


func get_item(id: String) -> Dictionary:
	return items.get(id, {})


## Definición con una variante aplicada (sprite, ancla, colisión, huella).
func resolve(base: Dictionary, variant: int) -> Dictionary:
	var d := base.duplicate()
	var variants: Array = base.get("variants", [])
	if variant > 0 and variant < variants.size():
		var v: Dictionary = variants[variant]
		for k in v:
			if k != "name":
				d[k] = v[k]
	return d


func variant_count(base: Dictionary) -> int:
	return maxi(1, (base.get("variants", []) as Array).size())


func variant_name(base: Dictionary, variant: int) -> String:
	var variants: Array = base.get("variants", [])
	if variant < variants.size():
		return String(variants[variant].get("name", ""))
	return ""


## Objetos que se muestran en una pestaña del catálogo, en orden.
func items_in_tab(tab_id: String) -> Array:
	var out := []
	for id in items:
		var it: Dictionary = items[id]
		if it.get("tab", "") == tab_id and it.get("in_catalog", true):
			out.append(it)
	return out


static func footprint_cells(d: Dictionary, at: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in int(d["footprint"][1]):
		for x in int(d["footprint"][0]):
			out.append(at + Vector2i(x, y))
	return out


func material_index(id: String) -> int:
	return material_ids.find(id)


func texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path)
	return _textures[path]


## Imagen en memoria de un sprite (para saber si un toque cae en un píxel visible).
func image(path: String) -> Image:
	if not _images.has(path):
		var tex := texture(path)
		_images[path] = tex.get_image() if tex else null
	return _images[path]


## Material compartido por tipo de objeto (permite agrupar el dibujo).
func shared_material(key: String, factory: Callable) -> Material:
	if not _materials_cache.has(key):
		_materials_cache[key] = factory.call()
	return _materials_cache[key]


static func read_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("Catalog: no se pudo leer %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	push_error("Catalog: JSON inválido en %s" % path)
	return {}
