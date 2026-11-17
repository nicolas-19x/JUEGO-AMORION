class_name PlacedObject
extends Node2D
## Objeto colocado en el mundo, construido a partir de su definición del catálogo.
## Su origen es el centro inferior de la huella (para ordenar por profundidad).

const SWAY_SHADER := preload("res://shaders/sway.gdshader")
const LIGHT_TEX := "res://assets/fx/light_radial.png"
const TILE := 16

var uid := ""
var item: Dictionary = {}
var cell := Vector2i.ZERO
var meta: Dictionary = {}  # quién lo colocó, cuándo, nota, recuerdo... (Fase 2+)
var light_on := true

var sprite: Sprite2D
var light: PointLight2D
var night_overlay: Sprite2D
var _bob_phase := 0.0


func setup(def: Dictionary, at_cell: Vector2i, id: String, extra := {}) -> void:
	item = def
	cell = at_cell
	uid = id
	meta = extra
	name = "%s_%s" % [def["id"], id]
	var fp := Vector2i(int(def["footprint"][0]), int(def["footprint"][1]))
	position = Vector2(cell.x * TILE + fp.x * TILE / 2.0, (cell.y + fp.y) * TILE)
	var anchor := Vector2(def["anchor"][0], def["anchor"][1])
	sprite = Sprite2D.new()
	sprite.texture = Catalog.texture(def["sprite"])
	sprite.centered = false
	sprite.offset = -Vector2(anchor.x, anchor.y + 1.0)
	add_child(sprite)
	if def.has("sway"):
		sprite.material = Catalog.shared_material("sway_" + def["id"], func() -> Material:
			var m := ShaderMaterial.new()
			m.shader = SWAY_SHADER
			m.set_shader_parameter("strength", float(def["sway"]["strength"]))
			m.set_shader_parameter("height_px", float(def["sway"]["height_px"]))
			return m)
	if def.get("bob", false) or def.get("category") == "playa":
		z_index = -1  # objetos planos: siempre por debajo de los personajes
	if def.get("bob", false):
		_bob_phase = float(cell.x * 13 + cell.y * 7)
	if def.has("collision"):
		_add_collision(def["collision"])
	if def.has("light"):
		_add_light(def["light"])
	if def.has("night_overlay"):
		night_overlay = Sprite2D.new()
		night_overlay.texture = Catalog.texture(def["night_overlay"])
		night_overlay.centered = false
		night_overlay.offset = sprite.offset
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		night_overlay.material = add
		add_child(night_overlay)
	if def.has("interaction"):
		add_to_group("interactables")
	set_process(def.get("bob", false) or light != null or night_overlay != null)


func _process(_delta: float) -> void:
	if item.get("bob", false):
		sprite.position.y = roundf(sin(Time.get_ticks_msec() / 900.0 + _bob_phase) * 0.6)
	var night := WorldClock.night_factor()
	if light:
		light.enabled = light_on and night > 0.02
		light.energy = float(item["light"].get("energy", 1.0)) * night
	if night_overlay:
		night_overlay.visible = night > 0.02
		night_overlay.modulate.a = night * 0.9


func interaction() -> Dictionary:
	return item.get("interaction", {})


## Distancia desde un punto a la zona ocupada por el objeto.
func distance_to_point(p: Vector2) -> float:
	var r := footprint_rect()
	var cx := clampf(p.x, r.position.x, r.end.x)
	var cy := clampf(p.y, r.position.y, r.end.y)
	return p.distance_to(Vector2(cx, cy))


func footprint_rect() -> Rect2:
	if item.has("collision"):
		var c: Array = item["collision"]
		return Rect2(global_position + Vector2(c[0], c[1]), Vector2(c[2], c[3]))
	return Rect2(global_position + Vector2(-6, -10), Vector2(12, 10))


func toggle_light() -> void:
	light_on = not light_on


func to_data() -> Dictionary:
	return {"uid": uid, "item": item["id"], "cell": [cell.x, cell.y], "meta": meta, "light_on": light_on}


func _add_collision(rect: Array) -> void:
	var body := StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(rect[2], rect[3])
	cs.shape = shape
	cs.position = Vector2(rect[0] + rect[2] / 2.0, rect[1] + rect[3] / 2.0)
	body.add_child(cs)
	add_child(body)


func _add_light(cfg: Dictionary) -> void:
	light = PointLight2D.new()
	light.texture = Catalog.texture(LIGHT_TEX)
	light.texture_scale = float(cfg.get("scale", 1.0))
	light.color = Color(cfg.get("color", "#ffd890"))
	light.position = Vector2(cfg["offset"][0], cfg["offset"][1])
	light.shadow_enabled = false
	light.enabled = false
	add_child(light)
