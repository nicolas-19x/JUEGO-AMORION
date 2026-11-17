class_name Hud
extends CanvasLayer
## Interfaz sobre el mundo: joystick, botón de acción contextual, menú, reloj,
## textos de los objetos, modo contemplación y zoom con dos dedos.
## Todo respeta el área segura de la pantalla (muescas y bordes curvos).

var world: World
var stage: PixelStage

var root: Control
var safe: MarginContainer
var joystick: VirtualJoystick
var action: TouchButton
var menu: TouchButton
var clock_label: Label
var clock_chip: PanelContainer
var caption: PanelContainer
var caption_label: Label
var cine_top: ColorRect
var cine_bottom: ColorRect
var cine_label: Label
var cine_hint: Label
var title_card: Control
var settings: SettingsPanel

var _caption_time := 0.0
var _pinch: Dictionary = {}  # índice de dedo -> posición
var _pinch_start := 0.0
var _clock_t := 0.0
var _action_visible := false
var _cinematic := false


func setup(w: World, s: PixelStage) -> void:
	world = w
	stage = s
	world.interactable_changed.connect(_on_target)
	world.caption_requested.connect(show_caption)
	world.cinematic_started.connect(_on_cinematic_started)
	world.cinematic_finished.connect(_on_cinematic_finished)


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.get_theme()
	add_child(root)

	joystick = VirtualJoystick.new()
	joystick.anchor_right = 0.45
	joystick.anchor_bottom = 1.0
	joystick.anchor_top = 0.25
	root.add_child(joystick)

	safe = MarginContainer.new()
	safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(safe)
	var layout := Control.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(layout)

	# reloj discreto (arriba a la izquierda)
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UiTheme.panel_box(Color(UiTheme.CREAM, 0.88), 22, 12))
	chip.position = Vector2(28, 24)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clock_label = Label.new()
	clock_label.add_theme_font_size_override("font_size", 22)
	clock_label.add_theme_color_override("font_color", UiTheme.INK)
	chip.add_child(clock_label)
	layout.add_child(chip)
	clock_chip = chip

	# menú (arriba a la derecha)
	menu = TouchButton.new()
	menu.radius = 40.0
	menu.icon = TouchButton.Icon.MENU
	menu.anchor_left = 1.0
	menu.anchor_right = 1.0
	menu.offset_left = -112
	menu.offset_top = 20
	menu.pressed.connect(open_settings)
	layout.add_child(menu)

	# acción contextual (abajo a la derecha, al alcance del pulgar)
	action = TouchButton.new()
	action.radius = 74.0
	action.fill = UiTheme.ACCENT
	action.ink = UiTheme.CREAM
	action.anchor_left = 1.0
	action.anchor_right = 1.0
	action.anchor_top = 1.0
	action.anchor_bottom = 1.0
	action.offset_left = -226
	action.offset_top = -226
	action.modulate.a = 0.0
	action.pressed.connect(func() -> void: world.interact())
	layout.add_child(action)

	# texto de objetos
	caption = PanelContainer.new()
	caption.add_theme_stylebox_override("panel", UiTheme.panel_box(Color(UiTheme.CREAM, 0.96), 24, 26))
	caption.anchor_left = 0.5
	caption.anchor_right = 0.5
	caption.anchor_top = 1.0
	caption.anchor_bottom = 1.0
	caption.custom_minimum_size = Vector2(640, 0)
	caption.grow_horizontal = Control.GROW_DIRECTION_BOTH
	caption.grow_vertical = Control.GROW_DIRECTION_BEGIN
	caption.offset_bottom = -36
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.modulate.a = 0.0
	caption.visible = false
	caption_label = Label.new()
	caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption_label.custom_minimum_size = Vector2(580, 0)
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.add_theme_font_override("font", UiTheme.font(400))
	caption_label.add_theme_font_size_override("font_size", 27)
	caption.add_child(caption_label)
	layout.add_child(caption)

	# franjas de contemplación
	cine_top = _bar(true)
	cine_bottom = _bar(false)
	cine_label = Label.new()
	cine_label.anchor_left = 0.0
	cine_label.anchor_right = 1.0
	cine_label.anchor_top = 1.0
	cine_label.anchor_bottom = 1.0
	cine_label.offset_top = -84
	cine_label.offset_bottom = -34
	cine_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cine_label.add_theme_font_override("font", UiTheme.font(400))
	cine_label.add_theme_font_size_override("font_size", 28)
	cine_label.add_theme_color_override("font_color", UiTheme.CREAM)
	cine_label.modulate.a = 0.0
	root.add_child(cine_label)
	cine_hint = Label.new()
	cine_hint.text = "Toca para volver"
	cine_hint.anchor_left = 0.0
	cine_hint.anchor_right = 1.0
	cine_hint.offset_top = 30
	cine_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cine_hint.add_theme_font_size_override("font_size", 20)
	cine_hint.add_theme_color_override("font_color", Color(UiTheme.CREAM, 0.7))
	cine_hint.modulate.a = 0.0
	root.add_child(cine_hint)

	_build_title_card()
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	_update_clock()


func _process(delta: float) -> void:
	_clock_t -= delta
	if _clock_t <= 0.0:
		_clock_t = 1.0
		_update_clock()
	if caption.visible and _caption_time > 0.0:
		_caption_time -= delta
		if _caption_time <= 0.0:
			hide_caption()
	if _action_visible and world:
		var label := world.interaction_label()
		if label != action.label:
			action.label = label
			action.queue_redraw()


func _input(event: InputEvent) -> void:
	if _cinematic:
		if event is InputEventScreenTouch and event.pressed:
			world.end_view()
			get_viewport().set_input_as_handled()
		return
	if title_card and event is InputEventScreenTouch and event.pressed:
		_dismiss_title()
		get_viewport().set_input_as_handled()
		return
	if caption.visible and event is InputEventScreenTouch and event.pressed \
			and not joystick.owns_touch(event.index) and not action.owns_touch(event.index):
		hide_caption()
	_handle_pinch(event)
	if event is InputEventMouseButton and event.pressed:  # rueda del ratón (solo pruebas en el editor)
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			stage.zoom_step(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			stage.zoom_step(-1)


func _notification(what: int) -> void:
	# botón «atrás» de Android: cierra lo que esté abierto o abre el menú
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if settings:
			settings.close()
		elif _cinematic:
			world.end_view()
		elif caption.visible:
			hide_caption()
		else:
			open_settings()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if world:
			world.save_player_position()


# ------------------------------------------------------------------ acciones
func open_settings() -> void:
	if settings:
		return
	joystick.enabled = false
	settings = SettingsPanel.new()
	settings.closed.connect(func() -> void:
		settings = null
		joystick.enabled = true)
	settings.character_changed.connect(func() -> void:
		world.player.appearance.apply(Settings.character_preset()))
	root.add_child(settings)


func show_caption(text: String) -> void:
	if text.is_empty():
		return
	caption_label.text = text
	caption.visible = true
	_caption_time = 4.0 + text.length() * 0.05
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(caption, "modulate:a", 1.0, 0.25)


func hide_caption() -> void:
	_caption_time = 0.0
	var tw := create_tween()
	tw.tween_property(caption, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func() -> void: caption.visible = false)


func _on_target(target: PlacedObject) -> void:
	var show := target != null
	if show:
		var it := target.interaction()
		action.label = world.interaction_label()
		action.icon = {"sit": TouchButton.Icon.SEAT, "view": TouchButton.Icon.EYE,
				"toggle_light": TouchButton.Icon.LIGHT}.get(it.get("type", ""), TouchButton.Icon.HAND)
		action.queue_redraw()
	if show == _action_visible:
		return
	_action_visible = show
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(action, "modulate:a", 1.0 if show else 0.0, 0.18)


func _on_cinematic_started(text: String) -> void:
	_cinematic = true
	joystick.enabled = false
	hide_caption()
	stage.push_temp_zoom(0)
	cine_label.text = text
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(cine_top, "offset_bottom", 74.0, 0.8)
	tw.tween_property(cine_bottom, "offset_top", -110.0, 0.8)
	for c in [menu, joystick, clock_chip]:
		tw.tween_property(c, "modulate:a", 0.0, 0.4)
	tw.tween_property(cine_label, "modulate:a", 1.0, 1.6).set_delay(0.8)
	tw.tween_property(cine_hint, "modulate:a", 1.0, 1.0).set_delay(2.4)


func _on_cinematic_finished() -> void:
	_cinematic = false
	joystick.enabled = true
	stage.pop_temp_zoom()
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cine_top, "offset_bottom", 0.0, 0.5)
	tw.tween_property(cine_bottom, "offset_top", 0.0, 0.5)
	tw.tween_property(cine_label, "modulate:a", 0.0, 0.3)
	tw.tween_property(cine_hint, "modulate:a", 0.0, 0.3)
	for c in [menu, joystick, clock_chip]:
		tw.tween_property(c, "modulate:a", 1.0, 0.4)


# ---------------------------------------------------------------- auxiliares
func _handle_pinch(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and not joystick.owns_touch(t.index) and not action.owns_touch(t.index):
			_pinch[t.index] = t.position
			if _pinch.size() == 2:
				_pinch_start = _pinch_distance()
		else:
			_pinch.erase(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if _pinch.has(d.index):
			_pinch[d.index] = d.position
			if _pinch.size() == 2 and _pinch_start > 0.0:
				var ratio := _pinch_distance() / _pinch_start
				if ratio > 1.3:
					stage.zoom_step(1)
					_pinch_start = _pinch_distance()
				elif ratio < 0.77:
					stage.zoom_step(-1)
					_pinch_start = _pinch_distance()


func _pinch_distance() -> float:
	var pts := _pinch.values()
	return (pts[0] as Vector2).distance_to(pts[1])


func _update_clock() -> void:
	clock_label.text = "%s  ·  %s" % [WorldClock.clock_text(), WorldClock.phase_name()]


func _bar(top: bool) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.06, 0.06, 0.14, 0.92)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.anchor_left = 0.0
	r.anchor_right = 1.0
	if top:
		r.anchor_top = 0.0
		r.anchor_bottom = 0.0
	else:
		r.anchor_top = 1.0
		r.anchor_bottom = 1.0
	root.add_child(r)
	return r


func _apply_safe_area() -> void:
	var win := Vector2(get_viewport().get_window().size)
	var logical := get_viewport().get_visible_rect().size
	if win.x <= 0.0:
		return
	var k := logical.x / win.x
	var sa := Rect2(DisplayServer.get_display_safe_area())
	var screen := Vector2(DisplayServer.screen_get_size())
	if sa.size.x <= 0.0 or screen.x <= 0.0 or not OS.has_feature("mobile"):
		return
	safe.add_theme_constant_override("margin_left", int(sa.position.x * k))
	safe.add_theme_constant_override("margin_top", int(sa.position.y * k))
	safe.add_theme_constant_override("margin_right", int((screen.x - sa.end.x) * k))
	safe.add_theme_constant_override("margin_bottom", int((screen.y - sa.end.y) * k))


func _build_title_card() -> void:
	title_card = Control.new()
	title_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.07, 0.17, 0.55)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_card.add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	var t := Label.new()
	t.text = "Nuestro pequeño universo"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_override("font", UiTheme.font(800))
	t.add_theme_font_size_override("font_size", 62)
	t.add_theme_color_override("font_color", UiTheme.CREAM)
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	t.add_theme_constant_override("shadow_offset_y", 4)
	box.add_child(t)
	var sub := Label.new()
	sub.text = "Toca para entrar"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_override("font", UiTheme.font(400))
	sub.add_theme_font_size_override("font_size", 26)
	sub.add_theme_color_override("font_color", Color(UiTheme.CREAM, 0.8))
	box.add_child(sub)
	title_card.add_child(box)
	root.add_child(title_card)
	joystick.enabled = false
	var tw := title_card.create_tween().set_loops()
	tw.tween_property(sub, "modulate:a", 0.4, 1.2)
	tw.tween_property(sub, "modulate:a", 1.0, 1.2)


func _dismiss_title() -> void:
	var card := title_card
	title_card = null
	joystick.enabled = true
	AudioDirector.play("chime", -10.0)
	var tw := create_tween()
	tw.tween_property(card, "modulate:a", 0.0, 0.8)
	tw.tween_callback(card.queue_free)
