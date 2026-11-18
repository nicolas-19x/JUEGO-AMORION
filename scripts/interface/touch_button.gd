class_name TouchButton
extends Control
## Botón táctil redondo que funciona con varios dedos a la vez
## (por ejemplo, moverse con el joystick y pulsar «Sentarse» al mismo tiempo).

signal pressed

enum Icon { NONE, MENU, HAND, EYE, SEAT, LIGHT, BUILD, UNDO, REDO, CHECK, CLOSE, ROTATE, MOVE, BOX, TRASH, BRUSH, PALETTE }

var label := ""
var icon := Icon.NONE
var fill := UiTheme.CREAM
var ink := UiTheme.INK
var radius := 60.0
var enabled := true:
	set(v):
		enabled = v
		queue_redraw()
## Si es mayor que 0, el botón es una píldora de este ancho (alto = radius * 2).
var pill_width := 0.0
var font_size := 22
var _down_index := -1
var _press_t := 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_fit()


func _fit() -> void:
	var w := radius * 2.0
	if pill_width > 0.0:
		# la píldora crece si el texto no cabe
		var tw := UiTheme.font(800).get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		w = maxf(pill_width, tw + (40.0 if icon != Icon.NONE else 0.0) + 56.0)
	custom_minimum_size = Vector2(w, radius * 2.0)
	size = custom_minimum_size


func set_look(new_label: String, new_icon: int, new_fill := fill, new_ink := ink) -> void:
	label = new_label
	icon = new_icon
	fill = new_fill
	ink = new_ink
	_fit()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or modulate.a < 0.5:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		var inside := _hit(t.position)
		if t.pressed and inside and _down_index == -1:
			if not enabled:
				get_viewport().set_input_as_handled()
				return
			_down_index = t.index
			_press_t = 1.0
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif not t.pressed and t.index == _down_index:
			_down_index = -1
			queue_redraw()
			if inside:
				AudioDirector.play("ui_tap", -8.0)
				pressed.emit()
			get_viewport().set_input_as_handled()


func owns_touch(index: int) -> bool:
	return _down_index == index


func _hit(p: Vector2) -> bool:
	if pill_width > 0.0:
		return get_global_rect().grow(8).has_point(p)
	var c := get_global_rect().get_center()
	return p.distance_to(c) <= radius * 1.15  # zona táctil algo mayor que el dibujo


func _process(delta: float) -> void:
	if _press_t > 0.0 and _down_index == -1:
		_press_t = maxf(0.0, _press_t - delta * 6.0)
		queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var press := 1.0 if _down_index != -1 else _press_t
	var a := 1.0 if enabled else 0.45
	var f := UiTheme.font(800)
	if pill_width > 0.0:
		var r := Rect2(Vector2.ZERO, size).grow(-2.0 * press)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(fill, fill.a * a)
		sb.set_corner_radius_all(int(size.y / 2.0))
		sb.shadow_color = Color(0.07, 0.05, 0.12, 0.22)
		sb.shadow_size = 6
		sb.shadow_offset = Vector2(0, 3)
		sb.anti_aliasing = true
		draw_style_box(sb, r)
		var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var has_icon := icon != Icon.NONE
		var total := tw + (40.0 if has_icon else 0.0)
		var x0 := c.x - total / 2.0
		if has_icon:
			_draw_icon(Vector2(x0 + 14.0, c.y), Color(ink, a))
		draw_string(f, Vector2(x0 + (40.0 if has_icon else 0.0), c.y + font_size * 0.36), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(ink, a))
		return
	var pr := radius * (1.0 - 0.06 * press)
	draw_circle(c + Vector2(0, 4), pr, Color(0.07, 0.05, 0.12, 0.25 * a))
	draw_circle(c, pr, Color(fill, fill.a * a))
	draw_arc(c, pr - 1.5, 0, TAU, 64, Color(1, 1, 1, 0.35 * a), 3.0, true)
	var ic := c + (Vector2(0, -12) if label != "" else Vector2.ZERO)
	_draw_icon(ic, Color(ink, a))
	if label != "":
		var fs := font_size if label.length() < 10 else font_size - 4
		var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(f, c + Vector2(-w / 2.0, 30), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(ink, a))


func _draw_icon(c: Vector2, col: Color = ink) -> void:
	match icon:
		Icon.MENU:
			for i in 3:
				draw_line(c + Vector2(-16, -10 + i * 10), c + Vector2(16, -10 + i * 10), col, 4.0, true)
		Icon.HAND:
			draw_circle(c, 13, Color(col, 0.15))
			draw_arc(c, 13, 0, TAU, 32, col, 3.0, true)
			draw_circle(c, 4, col)
		Icon.EYE:
			var pts := PackedVector2Array()
			for i in 33:
				var a := PI * i / 32.0
				pts.append(c + Vector2(cos(a) * -18, -sin(a) * 9))
			for i in 33:
				var a := PI * i / 32.0
				pts.append(c + Vector2(cos(a) * 18, sin(a) * 9))
			draw_polyline(pts, col, 3.0, true)
			draw_circle(c, 5, col)
		Icon.SEAT:
			draw_line(c + Vector2(-14, 4), c + Vector2(14, 4), col, 4.0, true)
			draw_line(c + Vector2(-14, -10), c + Vector2(-14, 12), col, 4.0, true)
			draw_line(c + Vector2(14, 4), c + Vector2(14, 12), col, 4.0, true)
		Icon.LIGHT:
			draw_circle(c, 9, col)
			for i in 8:
				var a := TAU * i / 8.0
				draw_line(c + Vector2(cos(a), sin(a)) * 13, c + Vector2(cos(a), sin(a)) * 18, col, 3.0, true)
		Icon.BUILD:  # paleta de jardinero con un brote
			draw_line(c + Vector2(-12, 12), c + Vector2(2, -2), col, 5.0, true)
			draw_circle(c + Vector2(6, -6), 8, col)
			draw_line(c + Vector2(6, -6), c + Vector2(14, -16), col, 3.0, true)
			draw_circle(c + Vector2(16, -14), 4, col)
		Icon.UNDO, Icon.REDO:
			var flip := -1.0 if icon == Icon.REDO else 1.0
			var pts := PackedVector2Array()
			for i in 13:
				var ang := lerpf(-PI * 0.95, PI * 0.15, i / 12.0)
				pts.append(c + Vector2(cos(ang) * 13 * flip, sin(ang) * 13 + 3))
			draw_polyline(pts, col, 4.0, true)
			var tip := pts[0]
			draw_line(tip, tip + Vector2(8 * flip, -7), col, 4.0, true)
			draw_line(tip, tip + Vector2(9 * flip, 4), col, 4.0, true)
		Icon.CHECK:
			draw_polyline(PackedVector2Array([c + Vector2(-13, 0), c + Vector2(-4, 9), c + Vector2(14, -10)]), col, 5.0, true)
		Icon.CLOSE:
			draw_line(c + Vector2(-10, -10), c + Vector2(10, 10), col, 4.5, true)
			draw_line(c + Vector2(10, -10), c + Vector2(-10, 10), col, 4.5, true)
		Icon.ROTATE:
			draw_arc(c, 12, -PI * 0.2, PI * 1.4, 32, col, 4.0, true)
			var tip2 := c + Vector2(cos(-PI * 0.2), sin(-PI * 0.2)) * 12
			draw_line(tip2, tip2 + Vector2(-9, -3), col, 4.0, true)
			draw_line(tip2, tip2 + Vector2(1, -10), col, 4.0, true)
		Icon.MOVE:
			for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				var tip3: Vector2 = c + d * 15
				draw_line(c, tip3, col, 3.5, true)
				var side := Vector2(-d.y, d.x)
				draw_line(tip3, tip3 - d * 6 + side * 5, col, 3.5, true)
				draw_line(tip3, tip3 - d * 6 - side * 5, col, 3.5, true)
		Icon.BOX:
			draw_rect(Rect2(c + Vector2(-13, -6), Vector2(26, 18)), col, false, 3.5)
			draw_line(c + Vector2(-15, -6), c + Vector2(15, -6), col, 4.0, true)
			draw_line(c + Vector2(-5, 1), c + Vector2(5, 1), col, 3.5, true)
			draw_line(c + Vector2(-10, -12), c + Vector2(10, -12), col, 3.0, true)
		Icon.TRASH:
			draw_rect(Rect2(c + Vector2(-10, -8), Vector2(20, 22)), col, false, 3.5)
			draw_line(c + Vector2(-14, -9), c + Vector2(14, -9), col, 4.0, true)
			draw_line(c + Vector2(-4, -14), c + Vector2(4, -14), col, 3.5, true)
			draw_line(c + Vector2(-3, -3), c + Vector2(-3, 9), col, 2.5, true)
			draw_line(c + Vector2(3, -3), c + Vector2(3, 9), col, 2.5, true)
		Icon.BRUSH:
			draw_line(c + Vector2(10, -14), c + Vector2(-2, 2), col, 5.0, true)
			draw_circle(c + Vector2(-6, 7), 7, col)
		Icon.PALETTE:
			draw_circle(c, 14, Color(col, 0.2))
			draw_arc(c, 14, 0, TAU, 32, col, 3.0, true)
			for k in 4:
				var ang2 := TAU * k / 4.0 - PI / 4.0
				draw_circle(c + Vector2(cos(ang2), sin(ang2)) * 7, 3, col)
