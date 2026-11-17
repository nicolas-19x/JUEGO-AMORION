class_name TouchButton
extends Control
## Botón táctil redondo que funciona con varios dedos a la vez
## (por ejemplo, moverse con el joystick y pulsar «Sentarse» al mismo tiempo).

signal pressed

enum Icon { NONE, MENU, HAND, EYE, SEAT, LIGHT }

var label := ""
var icon := Icon.NONE
var fill := UiTheme.CREAM
var ink := UiTheme.INK
var radius := 60.0
var enabled := true
var _down_index := -1
var _press_t := 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(radius * 2.0, radius * 2.0)
	size = custom_minimum_size


func _input(event: InputEvent) -> void:
	if not enabled or not is_visible_in_tree() or modulate.a < 0.5:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		var inside := _hit(t.position)
		if t.pressed and inside and _down_index == -1:
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
	var c := get_global_rect().get_center()
	return p.distance_to(c) <= radius * 1.15  # zona táctil algo mayor que el dibujo


func _process(delta: float) -> void:
	if _press_t > 0.0 and _down_index == -1:
		_press_t = maxf(0.0, _press_t - delta * 6.0)
		queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var pr := radius * (1.0 - 0.06 * (1.0 if _down_index != -1 else _press_t))
	draw_circle(c + Vector2(0, 4), pr, Color(0.07, 0.05, 0.12, 0.25))
	draw_circle(c, pr, fill)
	draw_arc(c, pr - 1.5, 0, TAU, 64, Color(1, 1, 1, 0.35), 3.0, true)
	var ic := c + (Vector2(0, -12) if label != "" else Vector2.ZERO)
	_draw_icon(ic)
	if label != "":
		var f := UiTheme.font(800)
		var fs := 22 if label.length() < 10 else 18
		var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(f, c + Vector2(-w / 2.0, 30), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)


func _draw_icon(c: Vector2) -> void:
	var col := ink
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
