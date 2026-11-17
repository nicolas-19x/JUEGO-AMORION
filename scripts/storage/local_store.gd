class_name LocalStore
extends RefCounted
## Guardado local seguro en user://.
## Escribe primero en un archivo temporal, conserva la versión anterior como
## copia (.bak) y solo entonces reemplaza el archivo. Si un guardado queda
## incompleto (cierre inesperado), la carga recurre a la copia.


static func save_json(path: String, data: Variant) -> bool:
	var text := JSON.stringify(data, "\t")
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("LocalStore: no se pudo escribir %s (%s)" % [tmp, FileAccess.get_open_error()])
		return false
	f.store_string(text)
	f.flush()
	f.close()
	# verificación: lo escrito debe poder leerse completo
	if _parse(FileAccess.get_file_as_string(tmp)) == null:
		push_error("LocalStore: verificación fallida en %s" % tmp)
		return false
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path + ".bak")
		DirAccess.rename_absolute(path, path + ".bak")
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_error("LocalStore: no se pudo reemplazar %s (%d)" % [path, err])
		return false
	return true


static func load_json(path: String, fallback: Variant = null) -> Variant:
	for candidate in [path, path + ".bak"]:
		if FileAccess.file_exists(candidate):
			var parsed: Variant = _parse(FileAccess.get_file_as_string(candidate))
			if parsed != null:
				if candidate != path:
					push_warning("LocalStore: %s dañado, se usó la copia de seguridad" % path)
				return parsed
	return fallback


static func _parse(text: String) -> Variant:
	if text.is_empty():
		return null
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data
