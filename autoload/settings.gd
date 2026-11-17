extends Node
## Preferencias locales del dispositivo (no se sincronizan).

signal changed(key: String)

const PATH := "user://settings.json"
const DEFAULTS := {
	"volume_music": 0.7,
	"volume_sfx": 0.8,
	"volume_ambient": 0.8,
	"mute_music": false,
	"mute_sfx": false,
	"mute_ambient": false,
	"time_mode": "real",  # real | dawn | day | sunset | night | cycle
	"character": "a",
	"zoom_index": 1,
	"last_position": [],
}

var data: Dictionary = {}


func _ready() -> void:
	data = DEFAULTS.duplicate(true)
	var stored: Variant = LocalStore.load_json(PATH, {})
	if stored is Dictionary:
		for k in stored:
			data[k] = stored[k]


func get_value(key: String) -> Variant:
	return data.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant, persist := true) -> void:
	data[key] = value
	changed.emit(key)
	if persist:
		save()


func save() -> void:
	LocalStore.save_json(PATH, data)


func character_preset() -> Dictionary:
	var id: String = get_value("character")
	for p in Catalog.appearance.get("presets", []):
		if p["id"] == id:
			return p
	return Catalog.appearance.get("presets", [{}])[0]
