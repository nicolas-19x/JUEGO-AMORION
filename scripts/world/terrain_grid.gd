class_name TerrainGrid
extends Node2D
## Terreno por celdas con autotiling «dual-grid».
##
## Cada celda guarda un material (agua, arena, césped, tierra, adoquín, madera).
## Cada material con atlas se dibuja en su propia capa TileMapLayer, desplazada
## medio tile; cada tile visible mira las 4 celdas que toca y elige una de las
## 16 combinaciones. Así las transiciones siempre encajan y pintar una celda solo
## actualiza 4 tiles por capa. El agua es un shader debajo de todo.

signal changed(cell: Vector2i)

const TILE := 16
const SEA_MARGIN := 24  # celdas de mar alrededor del mapa
const WATER_SHADER := preload("res://shaders/water.gdshader")

var size := Vector2i.ZERO
var cells := PackedByteArray()
var water: ColorRect

var _layers: Dictionary = {}  # índice de material -> TileMapLayer
var _implied: Array = []  # por material: índices de capas que lleva debajo
var _walkable: Array = []
var _footstep: Array = []
var _decorated_chance: Array = []
var _dist_image: Image
var _dist_texture: ImageTexture
var _collision: StaticBody2D
var _dirty := false


func build(map: Dictionary) -> void:
	size = Vector2i(int(map["size"][0]), int(map["size"][1]))
	cells.resize(size.x * size.y)
	var rows: Array = map["terrain"]
	for y in size.y:
		var row: String = rows[y]
		for x in size.x:
			cells[y * size.x + x] = row.unicode_at(x) - 48
	_read_materials()
	_build_water()
	for mi in Catalog.materials.size():
		var m: Dictionary = Catalog.materials[mi]
		if m.has("atlas"):
			_layers[mi] = _make_layer(m["atlas"], mi)
	for j in size.y + 1:
		for i in size.x + 1:
			_refresh_display_cell(i, j)
	_rebuild_water_distance()
	_rebuild_collision()


# ------------------------------------------------------------------ consultas
func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y


func material_at(c: Vector2i) -> int:
	if not in_bounds(c):
		return 0
	return cells[c.y * size.x + c.x]


func material_id_at(world_pos: Vector2) -> String:
	return Catalog.material_ids[material_at(world_to_cell(world_pos))]


func is_walkable(c: Vector2i) -> bool:
	return _walkable[material_at(c)]


func footstep_at(world_pos: Vector2) -> String:
	return _footstep[material_at(world_to_cell(world_pos))]


func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.y / TILE))


func pixel_size() -> Vector2:
	return Vector2(size * TILE)


# ------------------------------------------------------------------ edición
## Cambia el material de una celda (base de la herramienta de terreno, Fase 2).
func paint(c: Vector2i, material: int) -> void:
	if set_cell_fast(c, material):
		finalize_changes()
		changed.emit(c)


## Cambia una celda y sus tiles visibles al instante (para pintar con el dedo).
## El agua y las colisiones se recalculan al final con finalize_changes().
func set_cell_fast(c: Vector2i, material: int) -> bool:
	if not in_bounds(c) or material_at(c) == material:
		return false
	cells[c.y * size.x + c.x] = material
	for dj in 2:
		for di in 2:
			_refresh_display_cell(c.x + di, c.y + dj)
	_dirty = true
	return true


func finalize_changes() -> void:
	if not _dirty:
		return
	_dirty = false
	_rebuild_water_distance()
	_rebuild_collision()


func load_rows(rows: Array) -> void:
	for y in mini(size.y, rows.size()):
		var row: String = rows[y]
		for x in mini(size.x, row.length()):
			cells[y * size.x + x] = row.unicode_at(x) - 48
	for j in size.y + 1:
		for i in size.x + 1:
			_refresh_display_cell(i, j)
	_dirty = true
	finalize_changes()


## Datos serializables (guardado local y sincronización futura).
func to_rows() -> Array:
	var out := []
	for y in size.y:
		var s := ""
		for x in size.x:
			s += char(48 + cells[y * size.x + x])
		out.append(s)
	return out


# ------------------------------------------------------------------ interno
func _read_materials() -> void:
	_implied.clear()
	_walkable.clear()
	_footstep.clear()
	_decorated_chance.clear()
	for m in Catalog.materials:
		var under: Array = []
		for u in m.get("under", []):
			under.append(Catalog.material_index(u))
		_implied.append(under)
		_walkable.append(bool(m.get("walkable", true)))
		_footstep.append(String(m.get("footstep", "grass")))
		_decorated_chance.append(float(m.get("decorated_chance", 0.0)))


func _make_layer(atlas_path: String, mi: int) -> TileMapLayer:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	var src := TileSetAtlasSource.new()
	src.texture = Catalog.texture(atlas_path)
	src.texture_region_size = Vector2i(TILE, TILE)
	var cols := src.texture.get_width() / TILE
	var rows := src.texture.get_height() / TILE
	for cy in rows:
		for cx in cols:
			src.create_tile(Vector2i(cx, cy))
	ts.add_source(src, 0)
	var layer := TileMapLayer.new()
	layer.name = "Terrain_%s" % Catalog.material_ids[mi]
	layer.tile_set = ts
	layer.position = Vector2(-TILE / 2.0, -TILE / 2.0)
	layer.z_index = -12 + mi
	layer.collision_enabled = false
	add_child(layer)
	return layer


func _has_layer(c: Vector2i, mi: int) -> bool:
	var m := material_at(c)
	return m == mi or (_implied[m] as Array).has(mi)


func _refresh_display_cell(i: int, j: int) -> void:
	for mi in _layers:
		var cfg := 0
		if _has_layer(Vector2i(i - 1, j - 1), mi):
			cfg |= 1
		if _has_layer(Vector2i(i, j - 1), mi):
			cfg |= 2
		if _has_layer(Vector2i(i - 1, j), mi):
			cfg |= 4
		if _has_layer(Vector2i(i, j), mi):
			cfg |= 8
		var layer: TileMapLayer = _layers[mi]
		if cfg == 0:
			layer.erase_cell(Vector2i(i, j))
			continue
		var phase := (i % 2) + 2 * (j % 2)
		var col := cfg
		if cfg == 15:
			var h := _hash(i, j)
			if float(h % 1000) / 1000.0 < _decorated_chance[mi]:
				col = 16 + (h / 1000) % 4
		layer.set_cell(Vector2i(i, j), 0, Vector2i(col, phase))


func _hash(i: int, j: int) -> int:
	var h := (i * 73856093) ^ (j * 19349663)
	return absi(h) % 1000003


func _build_water() -> void:
	water = ColorRect.new()
	water.name = "Water"
	water.mouse_filter = Control.MOUSE_FILTER_IGNORE
	water.position = Vector2(-SEA_MARGIN * TILE, -SEA_MARGIN * TILE)
	water.size = Vector2((size + Vector2i(SEA_MARGIN * 2, SEA_MARGIN * 2)) * TILE)
	water.z_index = -20
	var mat := ShaderMaterial.new()
	mat.shader = WATER_SHADER
	water.material = mat
	add_child(water)


## Distancia (en celdas) de cada celda de agua a la tierra más cercana.
## El shader la usa para profundidad, espuma y oleaje de orilla.
func _rebuild_water_distance() -> void:
	var w := size.x + SEA_MARGIN * 2
	var h := size.y + SEA_MARGIN * 2
	var INF := 99.0
	var d := PackedFloat32Array()
	d.resize(w * h)
	for y in h:
		for x in w:
			var c := Vector2i(x - SEA_MARGIN, y - SEA_MARGIN)
			d[y * w + x] = 0.0 if material_at(c) != 0 else INF
	# distancia chaflán (dos pasadas)
	var diag := 1.4142
	for y in h:
		for x in w:
			var v := d[y * w + x]
			if x > 0:
				v = minf(v, d[y * w + x - 1] + 1.0)
			if y > 0:
				v = minf(v, d[(y - 1) * w + x] + 1.0)
				if x > 0:
					v = minf(v, d[(y - 1) * w + x - 1] + diag)
				if x < w - 1:
					v = minf(v, d[(y - 1) * w + x + 1] + diag)
			d[y * w + x] = v
	for y in range(h - 1, -1, -1):
		for x in range(w - 1, -1, -1):
			var v := d[y * w + x]
			if x < w - 1:
				v = minf(v, d[y * w + x + 1] + 1.0)
			if y < h - 1:
				v = minf(v, d[(y + 1) * w + x] + 1.0)
				if x < w - 1:
					v = minf(v, d[(y + 1) * w + x + 1] + diag)
				if x > 0:
					v = minf(v, d[(y + 1) * w + x - 1] + diag)
			d[y * w + x] = v
	if _dist_image == null:
		_dist_image = Image.create(w, h, false, Image.FORMAT_L8)
	for y in h:
		for x in w:
			var v := clampf(d[y * w + x] / 8.0, 0.0, 1.0)
			_dist_image.set_pixel(x, y, Color(v, v, v))
	if _dist_texture == null:
		_dist_texture = ImageTexture.create_from_image(_dist_image)
	else:
		_dist_texture.update(_dist_image)
	var mat := water.material as ShaderMaterial
	mat.set_shader_parameter("land_dist", _dist_texture)
	mat.set_shader_parameter("map_px_size", Vector2(w, h) * TILE)
	mat.set_shader_parameter("map_origin", water.position)


## Colisiones: rectángulos sobre las celdas no caminables que tocan tierra,
## agrupados por filas para tener pocas formas.
func _rebuild_collision() -> void:
	if _collision:
		_collision.queue_free()
	_collision = StaticBody2D.new()
	_collision.name = "TerrainCollision"
	add_child(_collision)
	var inset := 0.0
	for y in range(-1, size.y + 1):
		var run_start := -999
		for x in range(-1, size.x + 2):
			var c := Vector2i(x, y)
			var block := x <= size.x and not is_walkable(c) and _touches_walkable(c)
			if block and run_start == -999:
				run_start = x
			elif not block and run_start != -999:
				var shape := RectangleShape2D.new()
				var w_px := (x - run_start) * TILE
				shape.size = Vector2(w_px, TILE - inset * 2)
				var cs := CollisionShape2D.new()
				cs.shape = shape
				cs.position = Vector2(run_start * TILE + w_px / 2.0, y * TILE + TILE / 2.0)
				_collision.add_child(cs)
				run_start = -999


func _touches_walkable(c: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var n := c + Vector2i(dx, dy)
			if in_bounds(n) and is_walkable(n):
				return true
	return false
