class_name SettingsPanel
extends Control
## Ajustes: volumen por categoría (con silencio), hora del mundo y personaje.

signal closed
signal character_changed

const TIME_MODES := [["real", "Hora real del teléfono"], ["dawn", "Amanecer"], ["day", "Día"],
		["sunset", "Atardecer"], ["night", "Noche"], ["cycle", "Ciclo rápido (6 min)"]]


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	theme = UiTheme.get_theme()
	var dim := ColorRect.new()
	dim.color = Color(0.07, 0.06, 0.16, 0.45)
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(700, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Ajustes"
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_font_override("font", UiTheme.font(800))
	box.add_child(title)

	box.add_child(_volume_row("Música", "music"))
	box.add_child(_volume_row("Efectos", "sfx"))
	box.add_child(_volume_row("Ambiente", "ambient"))

	box.add_child(_option_row("Hora del mundo", TIME_MODES, "time_mode", func(_v: String) -> void: pass))
	var chars: Array = []
	for p in Catalog.appearance.get("presets", []):
		chars.append([p["id"], p["name"]])
	box.add_child(_option_row("Personaje", chars, "character", func(_v: String) -> void: character_changed.emit()))

	var back := Button.new()
	back.text = "Volver a la isla"
	back.custom_minimum_size = Vector2(0, 72)
	back.add_theme_font_size_override("font_size", 28)
	back.pressed.connect(close)
	box.add_child(back)
	AudioDirector.play("ui_open", -8.0)


func close() -> void:
	AudioDirector.play("ui_tap", -8.0)
	closed.emit()
	queue_free()


func _volume_row(text: String, key: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(230, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = Settings.get_value("volume_" + key)
	s.size_flags_horizontal = SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(0, 56)
	s.value_changed.connect(func(v: float) -> void: Settings.set_value("volume_" + key, v, false))
	s.drag_ended.connect(func(_c: bool) -> void: Settings.save())
	row.add_child(s)
	var mute := Button.new()
	mute.toggle_mode = true
	mute.button_pressed = Settings.get_value("mute_" + key)
	mute.text = "Silencio"
	mute.custom_minimum_size = Vector2(150, 56)
	mute.add_theme_font_size_override("font_size", 20)
	mute.toggled.connect(func(on: bool) -> void: Settings.set_value("mute_" + key, on))
	row.add_child(mute)
	return row


func _option_row(text: String, options: Array, key: String, on_change: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(230, 0)
	row.add_child(l)
	var ob := OptionButton.new()
	ob.size_flags_horizontal = SIZE_EXPAND_FILL
	ob.custom_minimum_size = Vector2(0, 64)
	ob.add_theme_font_size_override("font_size", 24)
	var current: String = str(Settings.get_value(key))
	for i in options.size():
		ob.add_item(options[i][1], i)
		if options[i][0] == current:
			ob.select(i)
	ob.item_selected.connect(func(i: int) -> void:
		Settings.set_value(key, options[i][0])
		on_change.call(options[i][0]))
	row.add_child(ob)
	return row
