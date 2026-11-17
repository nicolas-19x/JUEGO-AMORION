class_name CharacterAppearance
extends Node2D
## Personaje compuesto por capas (cuerpo, ojos, ropa, pelo) que comparten frame.
## Cada capa se colorea con una rampa mediante el shader palette_swap, así
## cambiar de ropa o color de pelo no requiere nuevas imágenes.

const PALETTE_SHADER := preload("res://shaders/palette_swap.gdshader")
const BASE := "res://assets/characters/"
const COLS := 7
const ROWS := 4
const DIR_ROW := {"down": 0, "up": 1, "left": 2, "right": 3}

var _layers: Dictionary = {}  # nombre de capa -> Sprite2D


func apply(preset: Dictionary) -> void:
	for c in get_children():
		c.queue_free()
	_layers.clear()
	var order: Array = Catalog.appearance.get("layer_order", ["body", "eyes", "pants", "shoes", "shirt", "hair"])
	var colors: Dictionary = preset.get("layers", {})
	for layer_name in order:
		var tex_name: String = "char_%s.png" % layer_name
		if layer_name == "hair":
			tex_name = "char_hair_%s.png" % preset.get("hair_style", "short")
		var s := Sprite2D.new()
		s.texture = load(BASE + tex_name)
		s.hframes = COLS
		s.vframes = ROWS
		s.centered = false
		s.offset = Vector2(-8, -31)
		var mat := ShaderMaterial.new()
		mat.shader = PALETTE_SHADER
		mat.set_shader_parameter("ramp", load(BASE + "ramps/%s.png" % colors.get(layer_name, "skin_a")))
		s.material = mat
		add_child(s)
		_layers[layer_name] = s


func set_frame(direction: String, column: int) -> void:
	var f: int = DIR_ROW.get(direction, 0) * COLS + column
	for s in _layers.values():
		(s as Sprite2D).frame = f
