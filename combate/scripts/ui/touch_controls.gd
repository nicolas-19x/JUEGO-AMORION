class_name TouchControls
extends Control
## Controles táctiles minimalistas y multitáctiles.
##  · Mitad izquierda: joystick flotante (aparece donde se apoya el pulgar).
##  · GOLPE: puños (machacar encadena la serie). PATADA: patadas (en mitad de una
##    serie, remata). DEFENSA: mantener = guardia, a tiempo = parada.
##    ESQUIVA: con dirección esquiva hacia allí; sin dirección, quiebro lateral.
##  · REMATE: solo aparece cuando hay un remate posible.

signal attack_down
signal attack_up
signal kick_down
signal kick_up
signal dodge_down
signal guard_down
signal guard_up
signal special_down
signal pause_down

const STICK_R := 78.0

var stick := Vector2.ZERO
var special_visible := false
var counter_glow := false
var enabled := true
var _touches := {}       # índice → rol
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _pressed := {"attack": false, "kick": false, "guard": false, "dodge": false, "special": false}
const ROLES := ["attack", "kick", "guard", "dodge", "special", "pause"]
var _pulse := 0.0
var _special_alpha := 0.0
var _safe := Rect2()
var _font: Font


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	get_viewport().size_changed.connect(_update_safe)
	_update_safe()


func _update_safe() -> void:
	var vp := get_viewport_rect().size
	_safe = Rect2(Vector2.ZERO, vp)
	if OS.has_feature("mobile"):
		var scr := Vector2(DisplayServer.screen_get_size())
		var sa := DisplayServer.get_display_safe_area()
		if scr.x > 0 and scr.y > 0:
			var k := vp / scr
			_safe = Rect2(Vector2(sa.position) * k, Vector2(sa.size) * k)


func _center(role: String) -> Vector2:
	var br := _safe.end
	match role:
		"attack":
			return br + Vector2(-138, -142)
		"kick":
			return br + Vector2(-300, -84)
		"guard":
			return br + Vector2(-112, -306)
		"dodge":
			return br + Vector2(-276, -246)
		"special":
			return br + Vector2(-430, -176)
		"pause":
			return Vector2(_safe.end.x - 52, _safe.position.y + 46)
	return Vector2.ZERO


func _radius(role: String) -> float:
	match role:
		"attack":
			return 72.0
		"kick":
			return 62.0
		"guard":
			return 50.0
		"dodge":
			return 47.0
		"special":
			return 50.0
		"pause":
			return 26.0
	return 0.0


func _hit_role(p: Vector2) -> String:
	# zonas táctiles algo más grandes que el dibujo, para dedos reales
	# el botón más cercano gana (zonas generosas pero sin solaparse)
	var best := ""
	var best_d := 1e9
	for role in ROLES:
		if role == "special" and not special_visible:
			continue
		var d := p.distance_to(_center(role))
		if d <= _radius(role) * 1.25 + 8.0 and d / _radius(role) < best_d:
			best_d = d / _radius(role)
			best = role
	if best != "":
		return best
	if p.x < _safe.position.x + _safe.size.x * 0.5:
		return "stick"
	return ""


func _input(event: InputEvent) -> void:
	if not enabled or not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			var role := _hit_role(e.position)
			if role == "":
				return
			_touches[e.index] = role
			match role:
				"stick":
					_stick_origin = e.position
					_stick_pos = e.position
					stick = Vector2.ZERO
				"attack":
					_pressed.attack = true
					attack_down.emit()
				"kick":
					_pressed.kick = true
					kick_down.emit()
				"dodge":
					_pressed.dodge = true
					dodge_down.emit()
				"guard":
					_pressed.guard = true
					guard_down.emit()
				"special":
					_pressed.special = true
					special_down.emit()
				"pause":
					pause_down.emit()
			get_viewport().set_input_as_handled()
		else:
			var role: String = _touches.get(e.index, "")
			_touches.erase(e.index)
			match role:
				"stick":
					stick = Vector2.ZERO
				"attack":
					_pressed.attack = false
					attack_up.emit()
				"kick":
					_pressed.kick = false
					kick_up.emit()
				"dodge":
					_pressed.dodge = false
				"guard":
					_pressed.guard = false
					guard_up.emit()
				"special":
					_pressed.special = false
		queue_redraw()
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		if _touches.get(e.index, "") == "stick":
			var d := e.position - _stick_origin
			if d.length() > STICK_R:
				# el joystick sigue al pulgar si se aleja demasiado
				_stick_origin = e.position - d.normalized() * STICK_R
				d = d.normalized() * STICK_R
			_stick_pos = _stick_origin + d
			var v := d / STICK_R
			var dz := 0.12
			stick = Vector2.ZERO if v.length() < dz else v.normalized() * ((v.length() - dz) / (1.0 - dz))
			queue_redraw()


func release_all() -> void:
	_touches.clear()
	stick = Vector2.ZERO
	for k in _pressed:
		_pressed[k] = false


func _process(delta: float) -> void:
	_pulse += delta
	_special_alpha = move_toward(_special_alpha, 1.0 if special_visible else 0.0, delta * 6.0)
	queue_redraw()


func _draw() -> void:
	if not enabled:
		return
	var rim := Color(1.0, 0.86, 0.68, 0.55)
	var fill := Color(0.06, 0.05, 0.08, 0.32)
	# joystick
	var has_stick := _touches.values().has("stick")
	var base := _stick_origin if has_stick else _safe.position + Vector2(170, _safe.size.y - 150)
	var a := 1.0 if has_stick else 0.35
	draw_circle(base, STICK_R, Color(fill.r, fill.g, fill.b, fill.a * a))
	draw_arc(base, STICK_R, 0, TAU, 48, Color(rim.r, rim.g, rim.b, rim.a * a), 2.0, true)
	var knob := _stick_pos if has_stick else base
	draw_circle(knob, 30, Color(1.0, 0.9, 0.78, 0.42 * a + 0.1))
	# botones
	if counter_glow:
		var c := _center("attack")
		var k := 0.5 + 0.5 * sin(_pulse * 22.0)
		draw_circle(c, _radius("attack") * (1.15 + 0.08 * k), Color(1.0, 0.82, 0.3, 0.25 + 0.2 * k))
	_button("attack", "CONTRA" if counter_glow else "GOLPE", Color(1.0, 0.85, 0.3) if counter_glow else Color(1.0, 0.62, 0.35))
	_button("kick", "PATADA", Color(1.0, 0.45, 0.32))
	_button("guard", "DEFENSA", Color(0.55, 0.8, 0.95))
	_button("dodge", "ESQUIVA", Color(0.6, 0.95, 0.7))
	if _special_alpha > 0.01:
		_button("special", "REMATE", Color(1.0, 0.85, 0.4), _special_alpha)
	var pc := _center("pause")
	draw_circle(pc, 22, Color(0.06, 0.05, 0.08, 0.35))
	draw_rect(Rect2(pc + Vector2(-7, -8), Vector2(4, 16)), Color(1, 0.92, 0.82, 0.7))
	draw_rect(Rect2(pc + Vector2(3, -8), Vector2(4, 16)), Color(1, 0.92, 0.82, 0.7))


func _button(role: String, label: String, accent: Color, alpha := 1.0) -> void:
	var c := _center(role)
	var r := _radius(role)
	var down: bool = _pressed.get(role, false)
	if role == "special":
		r *= 1.0 + sin(_pulse * 7.0) * 0.05
	var rr := r * (0.93 if down else 1.0)
	draw_circle(c, rr, Color(0.06, 0.05, 0.08, (0.5 if down else 0.3) * alpha))
	if down:
		draw_circle(c, rr, Color(accent.r, accent.g, accent.b, 0.28 * alpha))
	draw_arc(c, rr, 0, TAU, 56, Color(accent.r, accent.g, accent.b, 0.85 * alpha), 3.0, true)
	var ic := Color(1, 0.95, 0.88, 0.9 * alpha)
	match role:
		"attack":
			# tres trazos de impacto
			for k in 3:
				var ang := -PI * 0.75 + k * 0.35
				var d := Vector2(cos(ang), sin(ang))
				draw_line(c + d * rr * 0.12, c + d * rr * 0.48, ic, 5.0, true)
			draw_circle(c + Vector2(6, 6), rr * 0.17, ic)
		"kick":
			# pie estilizado con estela
			draw_line(c + Vector2(-rr * 0.38, -rr * 0.3), c + Vector2(rr * 0.1, rr * 0.1), ic, 7.0, true)
			draw_line(c + Vector2(rr * 0.1, rr * 0.1), c + Vector2(rr * 0.42, rr * 0.06), ic, 7.0, true)
			for k in 3:
				draw_line(c + Vector2(-rr * 0.42, -rr * 0.05 + k * rr * 0.14), c + Vector2(-rr * 0.2, -rr * 0.05 + k * rr * 0.14), Color(ic.r, ic.g, ic.b, ic.a * 0.6), 3.0, true)
		"dodge":
			# flecha curva
			draw_arc(c + Vector2(0, rr * 0.1), rr * 0.36, PI * 1.1, PI * 1.9, 16, ic, 4.0, true)
			var tip := c + Vector2(rr * 0.34, -rr * 0.05)
			draw_line(tip, tip + Vector2(-rr * 0.16, -rr * 0.05), ic, 4.0, true)
			draw_line(tip, tip + Vector2(-rr * 0.02, rr * 0.16), ic, 4.0, true)
		"guard":
			var pts := PackedVector2Array([c + Vector2(0, -rr * 0.42), c + Vector2(rr * 0.34, -rr * 0.28),
				c + Vector2(rr * 0.28, rr * 0.12), c + Vector2(0, rr * 0.42), c + Vector2(-rr * 0.28, rr * 0.12),
				c + Vector2(-rr * 0.34, -rr * 0.28), c + Vector2(0, -rr * 0.42)])
			draw_polyline(pts, ic, 4.0, true)
		"special":
			draw_circle(c, rr * 0.2, ic)
			draw_arc(c, rr * 0.4, 0, TAU, 24, ic, 3.0, true)
	var fs := 15
	var w := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
	draw_string(_font, c + Vector2(-w * 0.5, rr + 20), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.93, 0.85, 0.55 * alpha))
