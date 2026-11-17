class_name VirtualJoystick
extends Control
## Joystick flotante: aparece donde apoyas el pulgar, en la mitad izquierda.

const RADIUS := 92.0
const KNOB := 40.0
const DEADZONE := 0.12

var enabled := true
var _index := -1
var _center := Vector2.ZERO
var _knob := Vector2.ZERO
var _rest_center := Vector2.ZERO
var _alpha := 0.35


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func owns_touch(index: int) -> bool:
	return index == _index


func release() -> void:
	_index = -1
	_knob = Vector2.ZERO
	InputHub.touch_vector = Vector2.ZERO
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not enabled:
		if _index != -1:
			release()
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _index == -1 and get_global_rect().has_point(t.position):
			_index = t.index
			_center = t.position - global_position
			_knob = Vector2.ZERO
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif not t.pressed and t.index == _index:
			release()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _index:
			var v := d.position - global_position - _center
			if v.length() > RADIUS * 1.4:  # el centro sigue al pulgar si se aleja mucho
				_center += v - v.normalized() * RADIUS * 1.4
				v = d.position - global_position - _center
			_knob = v.limit_length(RADIUS)
			var amount := _knob.length() / RADIUS
			InputHub.touch_vector = Vector2.ZERO if amount < DEADZONE else _knob.normalized() * remap(amount, DEADZONE, 1.0, 0.0, 1.0)
			queue_redraw()
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var target := 0.9 if _index != -1 else 0.32
	if absf(_alpha - target) > 0.01:
		_alpha = lerpf(_alpha, target, 1.0 - exp(-delta * 10.0))
		queue_redraw()


func _draw() -> void:
	_rest_center = Vector2(RADIUS + 46.0, size.y - RADIUS - 46.0)
	var c := _center if _index != -1 else _rest_center
	draw_circle(c, RADIUS, Color(UiTheme.CREAM, 0.22 * _alpha))
	draw_arc(c, RADIUS, 0, TAU, 72, Color(UiTheme.CREAM, 0.8 * _alpha), 3.0, true)
	draw_circle(c + _knob + Vector2(0, 3), KNOB, Color(0.07, 0.05, 0.12, 0.25 * _alpha))
	draw_circle(c + _knob, KNOB, Color(UiTheme.CREAM, 0.95 * _alpha))
