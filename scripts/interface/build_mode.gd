class_name BuildMode
extends Control
## Modo construcción: una sola capa clara sobre el mundo.
##
## Estados:
##   BROWSE    explorar: arrastrar mueve la vista, tocar un objeto lo selecciona
##   PLACING   colocar: un objeto «fantasma» sigue al dedo (verde si cabe)
##   SELECTED  objeto elegido: girar, mover, guardar o borrar; arrastrarlo lo mueve
##   PAINTING  pintar terreno con el dedo
## Nada pide confirmación: todo se puede deshacer.

signal finished(changes: int)

enum S { BROWSE, PLACING, SELECTED, PAINTING }

const TAP_SLOP := 14.0
const BRUSH_SIZES := [1, 2]

var world: World
var stage: PixelStage
var hud: Node

var state := S.BROWSE
var drawer: BuildDrawer
var top_bar: HBoxContainer
var context_bar: HBoxContainer
var info_card: PanelContainer
var info_title: Label
var info_note: Label
var hint: PanelContainer
var hint_label: Label
var reason: PanelContainer
var reason_label: Label
var undo_btn: TouchButton
var redo_btn: TouchButton
var done_btn: TouchButton

# colocar / mover
var ghost: PlacedObject
var ghost_item := ""
var ghost_variant := 0
var ghost_cell := Vector2i.ZERO
var ghost_ok := false
var from_inventory_uid := ""
var moving_uid := ""  # si el fantasma representa un objeto ya colocado
# selección
var selected: PlacedObject
# pintar
var paint_material := 2
var brush := 1
var _stroke: Array = []
var _stroke_cells: Dictionary = {}

var _touches: Dictionary = {}  # índice -> posición
var _gesture := {}  # gesto de un dedo en curso
var _pinch_d0 := 0.0
var _pinch_mid := Vector2.ZERO
var _session_ops := 0
var _reason_t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	theme = UiTheme.get_theme()
	_build_top_bar()
	drawer = BuildDrawer.new()
	drawer.world = world
	drawer.anchor_left = 0.0
	drawer.anchor_right = 1.0
	drawer.anchor_top = 1.0
	drawer.anchor_bottom = 1.0
	drawer.grow_vertical = GROW_DIRECTION_BEGIN
	drawer.item_chosen.connect(start_placing)
	drawer.inventory_chosen.connect(_start_from_inventory)
	drawer.material_chosen.connect(start_painting)
	add_child(drawer)
	_build_context_bar()
	_build_info()
	world.history.changed.connect(_refresh_history)
	_refresh_history()
	_enter(S.BROWSE)


func open() -> void:
	visible = true
	_session_ops = world.history.size()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)
	_enter(S.BROWSE)


func close() -> void:
	_cancel_current()
	var changes := world.history.size() - _session_ops
	visible = false
	finished.emit(maxi(0, changes))


## Botón atrás: vuelve un paso (de colocar/seleccionar a explorar, o sale).
func back() -> void:
	if state != S.BROWSE:
		_cancel_current()
		_enter(S.BROWSE)
	else:
		close()


# ------------------------------------------------------------------ estados
func _enter(s: int) -> void:
	state = s
	world.overlay.cells = []
	world.overlay.brush_cells = []
	world.overlay.select_cells = []
	for c in context_bar.get_children():
		c.queue_free()
	info_card.visible = false
	match s:
		S.BROWSE:
			drawer.clear_selection()
			_set_hint("Elige algo abajo para colocarlo · toca un objeto de la isla para editarlo")
		S.PLACING:
			_ctx_button("", TouchButton.Icon.CLOSE, UiTheme.CREAM, UiTheme.INK, func() -> void:
				_cancel_current()
				_enter(S.BROWSE))
			var base := Catalog.get_item(ghost_item)
			if Catalog.variant_count(base) > 1:
				var rot: bool = base.get("rotates", false)
				_ctx_button("Girar" if rot else "Variante", TouchButton.Icon.ROTATE if rot else TouchButton.Icon.PALETTE,
						UiTheme.CREAM, UiTheme.INK, _cycle_ghost_variant)
			_ctx_pill("Colocar" if moving_uid == "" else "Aquí", TouchButton.Icon.CHECK, _confirm_ghost)
			_set_hint("Arrastra el objeto o toca donde lo quieras")
			_update_ghost()
		S.SELECTED:
			var base2 := selected.item
			_ctx_button("", TouchButton.Icon.CLOSE, UiTheme.CREAM, UiTheme.INK, func() -> void: _enter(S.BROWSE))
			_ctx_button("Mover", TouchButton.Icon.MOVE, UiTheme.CREAM, UiTheme.INK, _start_move_selected)
			if Catalog.variant_count(base2) > 1:
				var rot2: bool = base2.get("rotates", false)
				_ctx_button("Girar" if rot2 else "Variante", TouchButton.Icon.ROTATE if rot2 else TouchButton.Icon.PALETTE,
						UiTheme.CREAM, UiTheme.INK, _cycle_selected_variant)
			if not base2.get("unique", false):
				_ctx_button("Guardar", TouchButton.Icon.BOX, UiTheme.CREAM, UiTheme.INK, func() -> void: _remove_selected(true))
				_ctx_button("Quitar", TouchButton.Icon.TRASH, Color("#f3d2c8"), UiTheme.ACCENT_DEEP, func() -> void: _remove_selected(false))
			_show_info(selected)
			world.overlay.select_cells = selected.footprint_cells()
			_set_hint("Arrástralo para moverlo")
		S.PAINTING:
			_ctx_button("", TouchButton.Icon.CLOSE, UiTheme.CREAM, UiTheme.INK, func() -> void: _enter(S.BROWSE))
			_ctx_pill("Pincel %s" % ("pequeño" if brush == 1 else "grande"), TouchButton.Icon.BRUSH, func() -> void:
				brush = 2 if brush == 1 else 1
				_enter(S.PAINTING))
			_set_hint("Arrastra un dedo para pintar · dos dedos para moverte")
	_layout_context()


func _cancel_current() -> void:
	if ghost:
		ghost.queue_free()
		ghost = null
	if moving_uid != "" and world.objects.has(moving_uid):
		(world.objects[moving_uid] as PlacedObject).visible = true
	moving_uid = ""
	from_inventory_uid = ""
	if selected and is_instance_valid(selected):
		selected.set_highlight(false)
	selected = null
	if not _stroke.is_empty():
		_commit_stroke()


# --------------------------------------------------------------- colocar
func start_placing(item_id: String, variant: int) -> void:
	_cancel_current()
	ghost_item = item_id
	ghost_variant = variant
	_spawn_ghost(_center_cell())
	_enter(S.PLACING)


func _start_from_inventory(uid: String) -> void:
	for d in world.inventory:
		if d["uid"] == uid:
			start_placing(String(d["item"]), int(d.get("variant", 0)))
			from_inventory_uid = uid
			return


func _start_move_selected() -> void:
	if selected == null:
		return
	var obj := selected
	_cancel_current()
	moving_uid = obj.uid
	ghost_item = obj.item["id"]
	ghost_variant = obj.variant
	obj.visible = false
	_spawn_ghost(obj.cell)
	_enter(S.PLACING)


func _spawn_ghost(at: Vector2i) -> void:
	if ghost:
		ghost.queue_free()
	ghost = PlacedObject.new()
	ghost.setup(Catalog.get_item(ghost_item), at, "ghost", {}, ghost_variant, true)
	ghost.z_index = 15
	world.entities.add_child(ghost)
	ghost_cell = at
	_update_ghost()
	AudioDirector.play("build_pickup", -12.0)


func _move_ghost_to(c: Vector2i) -> void:
	if c == ghost_cell:
		return
	ghost_cell = c
	ghost.set_cell(c)
	_update_ghost()
	AudioDirector.play("ui_tap", -22.0, 1.4)


func _update_ghost() -> void:
	if ghost == null:
		return
	var check := world.can_place(ghost_item, ghost_variant, ghost_cell, moving_uid)
	ghost_ok = check["ok"]
	ghost.sprite.position.y = -3.0  # «levantado» mientras se coloca
	ghost.modulate = Color(1, 1, 1, 0.9) if ghost_ok else Color(1.0, 0.68, 0.64, 0.8)
	world.overlay.cells = ghost.footprint_cells()
	world.overlay.cells_ok = ghost_ok
	if not ghost_ok:
		_show_reason(String(check["reason"]))
	else:
		_hide_reason()


func _cycle_ghost_variant() -> void:
	var n := Catalog.variant_count(Catalog.get_item(ghost_item))
	ghost_variant = (ghost_variant + 1) % n
	ghost.set_variant(ghost_variant)
	ghost.set_cell(ghost_cell)
	ghost.play_pop()
	_update_ghost()


func _confirm_ghost() -> void:
	if ghost == null:
		return
	if not ghost_ok:
		AudioDirector.play("build_boop", -6.0)
		_shake(ghost)
		return
	if moving_uid != "":
		var uid := moving_uid
		var obj: PlacedObject = world.objects.get(uid)
		ghost.queue_free()
		ghost = null
		moving_uid = ""
		if obj:
			obj.visible = true
			world.build_move(uid, ghost_cell)
			AudioDirector.play("build_pop", -6.0)
			_select(obj)
		return
	if world.build_place(ghost_item, ghost_variant, ghost_cell, from_inventory_uid):
		AudioDirector.play("build_pop", -6.0, randf_range(0.95, 1.08))
		if from_inventory_uid != "":
			from_inventory_uid = ""
			_cancel_current()
			_enter(S.BROWSE)
			return
		_update_ghost()  # modo sello: el fantasma sigue para colocar otro igual


# ------------------------------------------------------------- selección
func _select(obj: PlacedObject) -> void:
	if selected and is_instance_valid(selected):
		selected.set_highlight(false)
	selected = obj
	obj.set_highlight(true)
	AudioDirector.play("ui_tap", -10.0, 1.2)
	_enter(S.SELECTED)


func _cycle_selected_variant() -> void:
	if selected and world.build_cycle_variant(selected.uid):
		AudioDirector.play("build_pop", -8.0, 1.1)
		_show_info(selected)
		world.overlay.select_cells = selected.footprint_cells()
	else:
		AudioDirector.play("build_boop", -6.0)
		_show_reason("No hay sitio para girarlo aquí")


func _remove_selected(to_inventory: bool) -> void:
	if selected == null:
		return
	var uid := selected.uid
	selected.set_highlight(false)
	selected = null
	world.build_remove(uid, to_inventory)
	AudioDirector.play("build_pickup", -6.0)
	hud.toast("Guardado en «Guardado»" if to_inventory else "Quitado · puedes deshacerlo")
	_enter(S.BROWSE)


func _show_info(obj: PlacedObject) -> void:
	info_card.visible = true
	var vname := Catalog.variant_name(obj.item, obj.variant)
	info_title.text = String(obj.item["name"]) + (("  ·  " + vname) if vname != "" and Catalog.variant_count(obj.item) > 1 else "")
	var note := String(obj.item.get("description", ""))
	var by := String(obj.meta.get("placed_by", ""))
	if by != "":
		note = ("Lo puso %s · %s" % [by, _ago(int(obj.meta.get("placed_at", 0)))]) + ("\n" + note if note != "" else "")
	info_note.text = note
	info_note.visible = note != ""


func _ago(t: int) -> String:
	var d := int(Time.get_unix_time_from_system()) - t
	if d < 90:
		return "hace un momento"
	if d < 3600:
		return "hace %d min" % (d / 60)
	if d < 86400:
		return "hace %d h" % (d / 3600)
	var days := d / 86400
	return "ayer" if days == 1 else "hace %d días" % days


# ---------------------------------------------------------------- pintar
func start_painting(material: int) -> void:
	_cancel_current()
	paint_material = material
	_enter(S.PAINTING)


func _paint_at(world_pos: Vector2) -> void:
	var c := world.terrain.world_to_cell(world_pos)
	var cells: Array[Vector2i] = []
	for dy in brush:
		for dx in brush:
			cells.append(c + Vector2i(dx, dy))
	world.overlay.brush_cells = cells
	world.overlay.brush_color = Color(0.95, 0.9, 0.7)
	var painted := false
	for cc in cells:
		if _stroke_cells.has(cc) or not world.can_paint(cc, paint_material):
			continue
		var old := world.terrain.material_at(cc)
		if world.terrain.set_cell_fast(cc, paint_material):
			_stroke.append([cc.x, cc.y, old, paint_material])
			_stroke_cells[cc] = true
			painted = true
	if painted:
		AudioDirector.play("build_swish", -14.0, randf_range(0.9, 1.15))


func _commit_stroke() -> void:
	var changes := _stroke
	_stroke = []
	_stroke_cells.clear()
	world.overlay.brush_cells = []
	world.build_paint_commit(changes)


# ---------------------------------------------------------------- gestos
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if _over_ui(t.position) and _touches.is_empty():
				return
			_touches[t.index] = t.position
			if _touches.size() == 1:
				_begin_gesture(t.index, t.position)
			elif _touches.size() == 2:
				_end_gesture(false)
				_pinch_d0 = _pinch_dist()
				_pinch_mid = _pinch_center()
			get_viewport().set_input_as_handled()
		elif _touches.has(t.index):
			_touches.erase(t.index)
			if _gesture.get("index", -1) == t.index:
				_end_gesture(true)
			if _touches.size() < 2:
				_pinch_d0 = 0.0
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if not _touches.has(d.index):
			return
		_touches[d.index] = d.position
		if _touches.size() >= 2:
			_handle_pinch()
		elif _gesture.get("index", -1) == d.index:
			_drag_gesture(d.position, d.relative)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:  # rueda (pruebas en el editor)
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			stage.zoom_step(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			stage.zoom_step(-1)


func _begin_gesture(index: int, pos: Vector2) -> void:
	var wp := stage.screen_to_world(pos)
	_gesture = {"index": index, "start": pos, "mode": "pending"}
	match state:
		S.PLACING:
			if ghost and (ghost.sprite_rect().grow(4).has_point(wp) or _in_cells(wp, ghost.footprint_cells())):
				_gesture["mode"] = "ghost"
				_gesture["grab"] = Vector2(ghost_cell * 16) - wp
		S.SELECTED:
			if selected and world.object_at(wp) == selected:
				_gesture["mode"] = "press_selected"
		S.PAINTING:
			_gesture["mode"] = "paint"
			_paint_at(wp)


func _drag_gesture(pos: Vector2, rel: Vector2) -> void:
	var moved: float = pos.distance_to(_gesture["start"])
	var mode: String = _gesture["mode"]
	if mode == "pending" and moved > TAP_SLOP:
		mode = "pan"
	elif mode == "press_selected" and moved > TAP_SLOP:
		# arrastrar el objeto seleccionado lo «levanta» directamente
		_start_move_selected()
		_gesture["grab"] = Vector2(ghost_cell * 16) - stage.screen_to_world(pos)
		mode = "ghost"
	_gesture["mode"] = mode
	match mode:
		"pan":
			world.camera.pan(-rel * stage.ui_to_world_scale(), Vector2(stage.viewport.size))
		"ghost":
			var wp: Vector2 = stage.screen_to_world(pos) + _gesture["grab"]
			_move_ghost_to(Vector2i(roundi(wp.x / 16.0), roundi(wp.y / 16.0)))
		"paint":
			_paint_at(stage.screen_to_world(pos))


func _end_gesture(released: bool) -> void:
	if _gesture.is_empty():
		return
	var mode: String = _gesture["mode"]
	var start: Vector2 = _gesture["start"]
	_gesture = {}
	if mode == "paint":
		_commit_stroke()
		return
	if not released:
		return
	if mode == "pending" or mode == "press_selected":
		_tap(stage.screen_to_world(start))
	elif mode == "ghost" and moving_uid != "" and state == S.PLACING:
		# arrastrar y soltar: si cabe, se queda; si no, vuelve a su sitio
		if ghost_ok:
			_confirm_ghost()
		else:
			AudioDirector.play("build_boop", -6.0)
			var obj: PlacedObject = world.objects.get(moving_uid)
			_cancel_current()
			if obj:
				_select(obj)
			else:
				_enter(S.BROWSE)


func _tap(wp: Vector2) -> void:
	match state:
		S.PLACING:
			var c := world.terrain.world_to_cell(wp)
			var fp := ghost.footprint()
			_move_ghost_to(c - Vector2i(fp.x / 2, fp.y - 1))
		S.BROWSE, S.SELECTED:
			var obj := world.object_at(wp)
			if obj:
				if obj != selected:
					_select(obj)
			elif state == S.SELECTED:
				_cancel_current()
				_enter(S.BROWSE)


func _handle_pinch() -> void:
	var mid := _pinch_center()
	world.camera.pan(-(mid - _pinch_mid) * stage.ui_to_world_scale(), Vector2(stage.viewport.size))
	_pinch_mid = mid
	if _pinch_d0 <= 0.0:
		return
	var ratio := _pinch_dist() / _pinch_d0
	if ratio > 1.3:
		stage.zoom_step(1)
		_pinch_d0 = _pinch_dist()
	elif ratio < 0.77:
		stage.zoom_step(-1)
		_pinch_d0 = _pinch_dist()


func _pinch_dist() -> float:
	var p := _touches.values()
	return (p[0] as Vector2).distance_to(p[1]) if p.size() >= 2 else 0.0


func _pinch_center() -> Vector2:
	var p := _touches.values()
	return ((p[0] as Vector2) + (p[1] as Vector2)) / 2.0 if p.size() >= 2 else Vector2.ZERO


func _over_ui(p: Vector2) -> bool:
	for c in [drawer, top_bar, context_bar, info_card]:
		var ctl := c as Control
		if ctl.visible and ctl.get_global_rect().grow(6).has_point(p):
			return true
	return false


func _in_cells(wp: Vector2, cells: Array[Vector2i]) -> bool:
	return cells.has(world.terrain.world_to_cell(wp))


## Celda en el centro de la zona libre de la pantalla (entre la barra superior
## y los botones de abajo), para que el objeto nuevo se vea al aparecer.
func _center_cell() -> Vector2i:
	var r := get_viewport_rect()
	var top := top_bar.get_global_rect().end.y
	var bottom := drawer.get_global_rect().position.y - 20.0
	var p := stage.screen_to_world(Vector2(r.size.x * 0.42, (top + bottom) / 2.0))
	var base := Catalog.get_item(ghost_item)
	var fp := Vector2i(int(base["footprint"][0]), int(base["footprint"][1]))
	return world.terrain.world_to_cell(p) - Vector2i(fp.x / 2, fp.y - 1)


# ----------------------------------------------------------------- interfaz
func _build_top_bar() -> void:
	top_bar = HBoxContainer.new()
	top_bar.anchor_left = 0.0
	top_bar.anchor_right = 1.0
	top_bar.offset_left = 28
	top_bar.offset_right = -28
	top_bar.offset_top = 20
	top_bar.add_theme_constant_override("separation", 14)
	add_child(top_bar)
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UiTheme.panel_box(Color(UiTheme.SAGE, 0.95), 24, 12))
	var chip_row := HBoxContainer.new()
	chip_row.add_theme_constant_override("separation", 10)
	chip_row.add_child(UiTheme.pixel_icon("res://assets/interface/flower.png", 3))
	var cl := Label.new()
	cl.text = "Construyendo"
	cl.add_theme_color_override("font_color", UiTheme.CREAM)
	cl.add_theme_font_size_override("font_size", 22)
	chip_row.add_child(cl)
	chip.add_child(chip_row)
	top_bar.add_child(chip)
	hint = PanelContainer.new()
	hint.add_theme_stylebox_override("panel", UiTheme.panel_box(Color(UiTheme.CREAM, 0.85), 22, 12))
	hint.size_flags_horizontal = SIZE_SHRINK_CENTER | SIZE_EXPAND
	hint_label = Label.new()
	hint_label.add_theme_font_override("font", UiTheme.font(400))
	hint_label.add_theme_font_size_override("font_size", 19)
	hint_label.add_theme_color_override("font_color", UiTheme.INK)
	hint.add_child(hint_label)
	top_bar.add_child(hint)
	undo_btn = TouchButton.new()
	undo_btn.radius = 34.0
	undo_btn.icon = TouchButton.Icon.UNDO
	undo_btn.pressed.connect(_undo)
	top_bar.add_child(undo_btn)
	redo_btn = TouchButton.new()
	redo_btn.radius = 34.0
	redo_btn.icon = TouchButton.Icon.REDO
	redo_btn.pressed.connect(_redo)
	top_bar.add_child(redo_btn)
	done_btn = TouchButton.new()
	done_btn.radius = 34.0
	done_btn.pill_width = 150.0
	done_btn.set_look("Listo", TouchButton.Icon.CHECK, UiTheme.ACCENT, UiTheme.CREAM)
	done_btn.pressed.connect(close)
	top_bar.add_child(done_btn)
	# aviso de por qué algo no cabe
	reason = PanelContainer.new()
	reason.add_theme_stylebox_override("panel", UiTheme.panel_box(Color("#fbe3dc"), 20, 12))
	reason.anchor_left = 0.5
	reason.anchor_right = 0.5
	reason.grow_horizontal = GROW_DIRECTION_BOTH
	reason.offset_top = 100
	reason.mouse_filter = MOUSE_FILTER_IGNORE
	reason.modulate.a = 0.0
	reason_label = Label.new()
	reason_label.add_theme_font_size_override("font_size", 20)
	reason_label.add_theme_color_override("font_color", UiTheme.ACCENT_DEEP)
	reason.add_child(reason_label)
	add_child(reason)


func _build_context_bar() -> void:
	# a la derecha, al alcance del pulgar, sin tapar el centro de la vista
	context_bar = HBoxContainer.new()
	context_bar.anchor_left = 1.0
	context_bar.anchor_right = 1.0
	context_bar.anchor_top = 1.0
	context_bar.anchor_bottom = 1.0
	context_bar.grow_horizontal = GROW_DIRECTION_BEGIN
	context_bar.grow_vertical = GROW_DIRECTION_BEGIN
	context_bar.offset_right = -32
	context_bar.alignment = BoxContainer.ALIGNMENT_END
	context_bar.add_theme_constant_override("separation", 18)
	add_child(context_bar)
	drawer.collapsed_changed.connect(func(_c: bool) -> void: _layout_context.call_deferred())


func _build_info() -> void:
	info_card = PanelContainer.new()
	info_card.add_theme_stylebox_override("panel", UiTheme.panel_box(Color(UiTheme.CREAM, 0.95), 22, 18))
	info_card.anchor_left = 0.0
	info_card.anchor_top = 0.0
	info_card.offset_left = 28
	info_card.offset_top = 104
	info_card.custom_minimum_size = Vector2(360, 0)
	info_card.visible = false
	var v := VBoxContainer.new()
	info_card.add_child(v)
	info_title = Label.new()
	info_title.add_theme_font_override("font", UiTheme.font(800))
	info_title.add_theme_font_size_override("font_size", 24)
	v.add_child(info_title)
	info_note = Label.new()
	info_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_note.custom_minimum_size = Vector2(340, 0)
	info_note.add_theme_font_override("font", UiTheme.font(400))
	info_note.add_theme_font_size_override("font_size", 18)
	info_note.add_theme_color_override("font_color", UiTheme.INK_SOFT)
	v.add_child(info_note)
	add_child(info_card)


func _ctx_button(text: String, icon: int, fill: Color, ink: Color, cb: Callable) -> void:
	var b := TouchButton.new()
	b.radius = 46.0 if text == "" else 52.0
	b.font_size = 17
	b.set_look(text, icon, fill, ink)
	b.pressed.connect(cb)
	context_bar.add_child(b)


func _ctx_pill(text: String, icon: int, cb: Callable) -> void:
	var b := TouchButton.new()
	b.radius = 40.0
	b.pill_width = 220.0
	b.font_size = 24
	b.set_look(text, icon, UiTheme.ACCENT, UiTheme.CREAM)
	b.pressed.connect(cb)
	context_bar.add_child(b)


func _layout_context() -> void:
	var drawer_h := drawer.get_combined_minimum_size().y
	context_bar.offset_bottom = -drawer_h - 18
	context_bar.offset_top = context_bar.offset_bottom - 110


func _set_hint(text: String) -> void:
	hint_label.text = text


func _show_reason(text: String) -> void:
	reason_label.text = text
	_reason_t = 2.0
	reason.modulate.a = 1.0


func _hide_reason() -> void:
	_reason_t = 0.0


func _process(delta: float) -> void:
	if _reason_t > 0.0:
		_reason_t -= delta
	reason.modulate.a = move_toward(reason.modulate.a, 1.0 if _reason_t > 0.0 else 0.0, delta * 5.0)


func _shake(n: Node2D) -> void:
	var x0 := n.position.x
	var tw := n.create_tween()
	for i in 4:
		tw.tween_property(n, "position:x", x0 + (2.0 if i % 2 == 0 else -2.0), 0.04)
	tw.tween_property(n, "position:x", x0, 0.04)


func _undo() -> void:
	_cancel_current()
	if not world.history.undo().is_empty():
		AudioDirector.play("build_undo", -8.0)
	_enter(S.BROWSE)


func _redo() -> void:
	_cancel_current()
	if not world.history.redo().is_empty():
		AudioDirector.play("build_undo", -8.0, 1.2)
	_enter(S.BROWSE)


func _refresh_history() -> void:
	undo_btn.enabled = world.history.can_undo()
	redo_btn.enabled = world.history.can_redo()
