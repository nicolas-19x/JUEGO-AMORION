class_name PixelStage
extends Control
## Escenario pixel-perfect.
##
## El mundo se dibuja en un SubViewport de baja resolución y se amplía con un
## factor ENTERO (cada píxel del arte = N×N píxeles de la pantalla, sin
## difuminar). La interfaz se dibuja aparte a resolución nativa, nítida.
## El zoom con dos dedos cambia ese factor entero, así nunca se deforma el arte.

signal zoom_changed(level: int)

## Alturas visibles del mundo (en píxeles de arte) para cada nivel de zoom.
const ZOOM_HEIGHTS := [360.0, 270.0, 200.0]

var viewport: SubViewport
var display: TextureRect
var world: Node
var pixel_scale := 4
var zoom_level := 1
var _temp_zoom := -1
var _k := 1.0  # píxeles físicos por unidad lógica de la interfaz


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	zoom_level = clampi(int(Settings.get_value("zoom_index")), 0, ZOOM_HEIGHTS.size() - 1)
	viewport = SubViewport.new()
	viewport.name = "WorldViewport"
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.snap_2d_transforms_to_pixel = true
	viewport.snap_2d_vertices_to_pixel = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.audio_listener_enable_2d = true
	add_child(viewport)
	display = TextureRect.new()
	display.name = "WorldDisplay"
	display.texture = viewport.get_texture()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_SCALE
	display.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(display)
	get_viewport().size_changed.connect(_relayout)
	_relayout()


func mount(world_node: Node) -> void:
	world = world_node
	viewport.add_child(world_node)


func set_zoom(level: int, persist := true) -> void:
	level = clampi(level, 0, ZOOM_HEIGHTS.size() - 1)
	if level == zoom_level:
		return
	zoom_level = level
	if persist:
		Settings.set_value("zoom_index", level)
	_relayout()
	zoom_changed.emit(level)


func zoom_step(delta: int) -> void:
	set_zoom(zoom_level + delta)


## Zoom temporal (cinemáticas) sin cambiar la preferencia guardada.
func push_temp_zoom(level: int) -> void:
	_temp_zoom = clampi(level, 0, ZOOM_HEIGHTS.size() - 1)
	_relayout()


func pop_temp_zoom() -> void:
	_temp_zoom = -1
	_relayout()


func _relayout() -> void:
	var phys := Vector2(get_window().size)
	var logical := get_viewport_rect().size
	if logical.y <= 0.0 or phys.y <= 0.0:
		return
	_k = phys.y / logical.y
	var level := _temp_zoom if _temp_zoom >= 0 else zoom_level
	pixel_scale = maxi(1, roundi(phys.y / ZOOM_HEIGHTS[level]))
	var vp := Vector2i(ceili(phys.x / pixel_scale), ceili(phys.y / pixel_scale))
	viewport.size = vp
	display.position = Vector2.ZERO
	display.size = Vector2(vp) * pixel_scale / _k


## Cuántos píxeles del mundo equivalen a una unidad de la interfaz.
func ui_to_world_scale() -> float:
	return _k / pixel_scale


## Convierte una posición de la interfaz en coordenadas del mundo.
func screen_to_world(ui_pos: Vector2) -> Vector2:
	var vp_pos := ui_pos * _k / pixel_scale
	return viewport.canvas_transform.affine_inverse() * vp_pos
