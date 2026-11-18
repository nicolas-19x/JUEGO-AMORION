class_name PlacedObject
extends Node2D
## Objeto colocado en el mundo, construido a partir de su definición del catálogo.
## Su origen es el centro inferior de la huella (para ordenar por profundidad).
## Con `preview = true` se usa como «fantasma» en el modo construcción.

const SWAY_SHADER := preload("res://shaders/sway.gdshader")
const LIGHT_TEX := "res://assets/fx/light_radial.png"
const TILE := 16

var uid := ""
var item: Dictionary = {}  # definición del catálogo
var def: Dictionary = {}  # definición con la variante aplicada
var variant := 0
var cell := Vector2i.ZERO
var meta: Dictionary = {}  # quién lo colocó, cuándo, nota, recuerdo...
var light_on := true
var preview := false

var sprite: Sprite2D
var light: PointLight2D
var night_overlay: Sprite2D
var _body: StaticBody2D
var _bob_phase := 0.0
var _highlight := false
var _hl_time := 0.0


func setup(base: Dictionary, at_cell: Vector2i, id: String, extra := {}, variant_index := 0, is_preview := false) -> void:
	item = base
	uid = id
	meta = extra
	preview = is_preview
	name = "%s_%s" % [base["id"], id]
	sprite = Sprite2D.new()
	sprite.centered = false
	add_child(sprite)
	set_variant(variant_index)
	set_cell(at_cell)
	if def.get("bob", false):
		_bob_phase = float(at_cell.x * 13 + at_cell.y * 7)
	if preview:
		return
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
	add_to_group("placed_objects")


## Aplica una variante (color u orientación): sprite, ancla, colisión y huella.
func set_variant(v: int) -> void:
	var variants: Array = item.get("variants", [])
	variant = clampi(v, 0, maxi(0, variants.size() - 1))
	def = Catalog.resolve(item, variant)
	sprite.texture = Catalog.texture(def["sprite"])
	var anchor := Vector2(def["anchor"][0], def["anchor"][1])
	sprite.offset = -Vector2(anchor.x, anchor.y + 1.0)
	if night_overlay:
		night_overlay.offset = sprite.offset
	sprite.material = null
	if def.has("sway") and not preview:
		var key: String = "sway_%s" % def["id"]
		sprite.material = Catalog.shared_material(key, func() -> Material:
			var m := ShaderMaterial.new()
			m.shader = SWAY_SHADER
			m.set_shader_parameter("strength", float(def["sway"]["strength"]))
			m.set_shader_parameter("height_px", float(def["sway"]["height_px"]))
			return m)
	z_index = -1 if def.get("flat", false) else 0
	if not preview:
		_rebuild_collision()
	_update_processing()


func set_cell(c: Vector2i) -> void:
	cell = c
	var fp := footprint()
	position = Vector2(cell.x * TILE + fp.x * TILE / 2.0, (cell.y + fp.y) * TILE)


func footprint() -> Vector2i:
	return Vector2i(int(def["footprint"][0]), int(def["footprint"][1]))


func footprint_cells() -> Array[Vector2i]:
	return Catalog.footprint_cells(def, cell)


func _process(_delta: float) -> void:
	if def.get("bob", false):
		sprite.position.y = roundf(sin(Time.get_ticks_msec() / 900.0 + _bob_phase) * 0.6)
	if _highlight:
		_hl_time += _delta
		sprite.position.y = -1.0 if fmod(_hl_time, 0.9) < 0.45 else 0.0
		var pulse := 0.12 + 0.08 * sin(_hl_time * 6.0)
		sprite.modulate = Color(1.0 + pulse, 1.0 + pulse, 1.0 + pulse * 0.6)
	if preview:
		return
	var night := WorldClock.night_factor()
	if light:
		light.enabled = light_on and night > 0.02
		light.energy = float(def["light"].get("energy", 1.0)) * night
	if night_overlay:
		night_overlay.visible = night > 0.02
		night_overlay.modulate.a = night * 0.9


func _update_processing() -> void:
	set_process(_highlight or def.get("bob", false) or light != null or night_overlay != null)


func set_highlight(on: bool) -> void:
	_highlight = on
	_hl_time = 0.0
	if not on:
		sprite.position.y = 0.0
		sprite.modulate = Color.WHITE
	_update_processing()


## Pequeño «salto» al aparecer: estira y vuelve, como si se acomodara en su sitio.
func play_pop() -> void:
	scale = Vector2(0.7, 1.25)
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2(1.12, 0.9), 0.09)
	tw.tween_property(self, "scale", Vector2.ONE, 0.18)


func interaction() -> Dictionary:
	return def.get("interaction", {})


## Distancia desde un punto a la zona ocupada por el objeto.
func distance_to_point(p: Vector2) -> float:
	var r := footprint_rect()
	var cx := clampf(p.x, r.position.x, r.end.x)
	var cy := clampf(p.y, r.position.y, r.end.y)
	return p.distance_to(Vector2(cx, cy))


func footprint_rect() -> Rect2:
	if def.has("collision"):
		var c: Array = def["collision"]
		return Rect2(global_position + Vector2(c[0], c[1]), Vector2(c[2], c[3]))
	return Rect2(global_position + Vector2(-6, -10), Vector2(12, 10))


## Rectángulo visible del sprite (para tocar objetos en el modo construcción).
func sprite_rect() -> Rect2:
	var size := sprite.texture.get_size()
	return Rect2(global_position + sprite.offset, size)


func toggle_light() -> void:
	light_on = not light_on


func to_data() -> Dictionary:
	return {"uid": uid, "item": item["id"], "cell": [cell.x, cell.y], "variant": variant,
			"meta": meta, "light_on": light_on}


func _rebuild_collision() -> void:
	if _body:
		_body.queue_free()
		_body = null
	if not def.has("collision"):
		return
	var rect: Array = def["collision"]
	_body = StaticBody2D.new()
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(rect[2], rect[3])
	cs.shape = shape
	cs.position = Vector2(rect[0] + rect[2] / 2.0, rect[1] + rect[3] / 2.0)
	_body.add_child(cs)
	add_child(_body)


func _add_light(cfg: Dictionary) -> void:
	light = PointLight2D.new()
	light.texture = Catalog.texture(LIGHT_TEX)
	light.texture_scale = float(cfg.get("scale", 1.0))
	light.color = Color(cfg.get("color", "#ffd890"))
	light.position = Vector2(cfg["offset"][0], cfg["offset"][1])
	light.shadow_enabled = false
	light.enabled = false
	add_child(light)
