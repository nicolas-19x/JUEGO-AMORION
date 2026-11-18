class_name BuildOverlay
extends Node2D
## Capa visual del modo construcción: cuadrícula suave, huella del objeto
## (verde si cabe, coral si no) y cursor del pincel de terreno.

const TILE := 16
const OK_COLOR := Color(0.62, 0.95, 0.66)
const BAD_COLOR := Color(1.0, 0.55, 0.52)
const SELECT_COLOR := Color(1.0, 0.93, 0.62)

var world: Node
var active := false:
	set(v):
		active = v
		visible = v
		queue_redraw()
var cells: Array[Vector2i] = []
var cells_ok := true
var select_cells: Array[Vector2i] = []
var brush_cells: Array[Vector2i] = []
var brush_color := Color.WHITE
var _t := 0.0


func _ready() -> void:
	z_index = -2  # sobre el terreno, bajo los objetos: es una marca en el suelo
	visible = false


func _process(delta: float) -> void:
	if not active:
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	if not active or world == null:
		return
	var cam: Camera2D = world.camera
	var vp := get_viewport_rect().size
	var tl := cam.get_screen_center_position() - vp / 2.0
	var c0 := Vector2i(floori(tl.x / TILE), floori(tl.y / TILE))
	var c1 := Vector2i(ceili((tl.x + vp.x) / TILE), ceili((tl.y + vp.y) / TILE))
	var size: Vector2i = world.terrain.size
	# cuadrícula de puntitos en las esquinas de las celdas (discreta)
	var dot := Color(1, 1, 1, 0.22)
	for y in range(maxi(0, c0.y), mini(size.y, c1.y) + 1):
		for x in range(maxi(0, c0.x), mini(size.x, c1.x) + 1):
			draw_rect(Rect2(x * TILE, y * TILE, 1, 1), dot)
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	for c in select_cells:
		_cell(c, SELECT_COLOR, 0.18 + 0.1 * pulse)
	var col := OK_COLOR if cells_ok else BAD_COLOR
	for c in cells:
		_cell(c, col, 0.26 + 0.12 * pulse)
	for c in brush_cells:
		_cell(c, brush_color, 0.35 + 0.15 * pulse)


func _cell(c: Vector2i, col: Color, alpha: float) -> void:
	var r := Rect2(c.x * TILE + 1, c.y * TILE + 1, TILE - 2, TILE - 2)
	draw_rect(r, Color(col, alpha))
	# borde con esquinas redondeadas a base de píxeles
	var e := Color(col, minf(1.0, alpha + 0.45))
	draw_rect(Rect2(r.position.x + 1, r.position.y, r.size.x - 2, 1), e)
	draw_rect(Rect2(r.position.x + 1, r.end.y - 1, r.size.x - 2, 1), e)
	draw_rect(Rect2(r.position.x, r.position.y + 1, 1, r.size.y - 2), e)
	draw_rect(Rect2(r.end.x - 1, r.position.y + 1, 1, r.size.y - 2), e)
