extends Node
## Catálogo de objetos y materiales, cargado desde data/ (JSON).
## Añadir un mueble o una planta = añadir una entrada JSON y su sprite.

const ITEMS_DIR := "res://data/items/"
const MATERIALS_PATH := "res://data/world/materials.json"
const APPEARANCE_PATH := "res://data/characters/appearance.json"

var items: Dictionary = {}
var materials: Array = []
var material_ids: PackedStringArray = []
var appearance: Dictionary = {}

var _textures: Dictionary = {}
var _materials_cache: Dictionary = {}


func _ready() -> void:
	_load_items()
	materials = read_json(MATERIALS_PATH).get("materials", [])
	for m in materials:
		material_ids.append(m["id"])
	appearance = read_json(APPEARANCE_PATH)


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


func material_index(id: String) -> int:
	return material_ids.find(id)


func texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path)
	return _textures[path]


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
