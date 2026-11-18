class_name BuildDrawer
extends PanelContainer
## Cajón inferior del modo construcción: pestañas del catálogo, tarjetas con el
## dibujo de cada objeto, materiales de terreno y lo que habéis guardado.

signal item_chosen(item_id: String, variant: int)
signal inventory_chosen(uid: String)
signal material_chosen(material: int)
signal collapsed_changed(collapsed: bool)

const CARD := Vector2(140, 128)
const MATERIAL_NAMES := {"water": "Agua", "sand": "Arena", "grass": "Césped",
		"dirt": "Camino", "cobble": "Adoquín", "wood": "Madera"}
const MATERIAL_ORDER := ["grass", "dirt", "sand", "cobble", "wood", "water"]

var world: World
var tab_id := "naturaleza"
var collapsed := false

var _tabs_box: HBoxContainer
var _cards_scroll: ScrollContainer
var _cards: HBoxContainer
var _tab_group := ButtonGroup.new()
var _tab_buttons: Dictionary = {}
var _card_buttons: Dictionary = {}  # clave -> Button
var _selected_key := ""
var _collapse_btn: Button


func _ready() -> void:
	var sb := UiTheme.panel_box(Color(UiTheme.CREAM, 0.97), 30, 0)
	sb.corner_radius_bottom_left = 0
	sb.corner_radius_bottom_right = 0
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 12
	sb.content_margin_bottom = 16
	add_theme_stylebox_override("panel", sb)
	mouse_filter = MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	v.add_child(header)
	var tabs_scroll := ScrollContainer.new()
	tabs_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	tabs_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs_scroll.custom_minimum_size = Vector2(0, 58)
	header.add_child(tabs_scroll)
	_tabs_box = HBoxContainer.new()
	_tabs_box.add_theme_constant_override("separation", 6)
	tabs_scroll.add_child(_tabs_box)
	var all_tabs: Array = Catalog.tabs.duplicate()
	all_tabs.append({"id": "terreno", "name": "Terreno"})
	all_tabs.append({"id": "guardado", "name": "Guardado"})
	for t in all_tabs:
		var b := _tab_button(String(t["name"]))
		b.pressed.connect(show_tab.bind(String(t["id"])))
		_tabs_box.add_child(b)
		_tab_buttons[t["id"]] = b
	_collapse_btn = Button.new()
	_collapse_btn.custom_minimum_size = Vector2(64, 52)
	_collapse_btn.icon = Catalog.texture("res://assets/interface/chevron.png")
	_collapse_btn.expand_icon = false
	_collapse_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_collapse_btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_collapse_btn.add_theme_constant_override("icon_max_width", 28)
	_collapse_btn.pressed.connect(func() -> void: set_collapsed(not collapsed))
	header.add_child(_collapse_btn)

	_cards_scroll = ScrollContainer.new()
	_cards_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_cards_scroll.custom_minimum_size = Vector2(0, CARD.y + 6)
	_cards_scroll.scroll_deadzone = 12
	v.add_child(_cards_scroll)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 12)
	_cards_scroll.add_child(_cards)
	if world:
		world.inventory_changed.connect(_on_inventory_changed)
	show_tab(tab_id)


func set_collapsed(on: bool) -> void:
	collapsed = on
	_cards_scroll.visible = not on
	_collapse_btn.icon = Catalog.texture("res://assets/interface/chevron_up.png" if on else "res://assets/interface/chevron.png")
	AudioDirector.play("build_drawer", -10.0)
	collapsed_changed.emit(on)


func show_tab(id: String) -> void:
	tab_id = id
	if _tab_buttons.has(id):
		(_tab_buttons[id] as Button).button_pressed = true
	if collapsed:
		set_collapsed(false)
	for c in _cards.get_children():
		c.queue_free()
	_card_buttons.clear()
	match id:
		"terreno":
			for mid in MATERIAL_ORDER:
				var mi := Catalog.material_index(mid)
				_add_card("mat:%d" % mi, _material_icon(mid), MATERIAL_NAMES.get(mid, mid), "",
						func() -> void: material_chosen.emit(mi))
		"guardado":
			_fill_inventory()
		_:
			for it in Catalog.items_in_tab(id):
				var item_id: String = it["id"]
				var n := Catalog.variant_count(it)
				_add_card("item:" + item_id, Catalog.texture(it["sprite"]), String(it["name"]),
						("%d variantes" % n) if n > 1 else "",
						func() -> void: item_chosen.emit(item_id, 0))
	_refresh_selection()


func select_key(key: String) -> void:
	_selected_key = key
	_refresh_selection()


func clear_selection() -> void:
	select_key("")


func _fill_inventory() -> void:
	if world == null or world.inventory.is_empty():
		var empty := Label.new()
		empty.text = "Aquí aparecerá lo que guardéis.\nToca un objeto de la isla y pulsa «Guardar»."
		empty.add_theme_font_override("font", UiTheme.font(400))
		empty.add_theme_font_size_override("font_size", 22)
		empty.add_theme_color_override("font_color", UiTheme.INK_SOFT)
		empty.custom_minimum_size = Vector2(560, CARD.y)
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_cards.add_child(empty)
		return
	# agrupar por objeto y variante, conservando el más reciente para colocarlo
	var groups: Dictionary = {}
	var order: Array = []
	for d in world.inventory:
		var key := "%s#%d" % [d["item"], int(d.get("variant", 0))]
		if not groups.has(key):
			groups[key] = []
			order.append(key)
		(groups[key] as Array).append(d)
	for key in order:
		var list: Array = groups[key]
		var d: Dictionary = list[-1]
		var base := Catalog.get_item(String(d["item"]))
		if base.is_empty():
			continue
		var resolved := Catalog.resolve(base, int(d.get("variant", 0)))
		var uid: String = d["uid"]
		_add_card("inv:" + key, Catalog.texture(resolved["sprite"]), String(base["name"]),
				"×%d" % list.size(), func() -> void: inventory_chosen.emit(uid))


func _on_inventory_changed() -> void:
	var b: Button = _tab_buttons.get("guardado")
	if b:
		var n := world.inventory.size()
		b.text = "Guardado" + (" · %d" % n if n > 0 else "")
	if tab_id == "guardado":
		show_tab("guardado")


func _add_card(key: String, tex: Texture2D, title: String, note: String, on_press: Callable) -> void:
	var b := Button.new()
	b.custom_minimum_size = CARD
	b.mouse_filter = MOUSE_FILTER_PASS  # permite arrastrar la fila para desplazarse
	b.focus_mode = FOCUS_NONE
	b.pressed.connect(func() -> void:
		AudioDirector.play("ui_tap", -8.0)
		_selected_key = key
		_refresh_selection()
		on_press.call())
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	box.offset_top = 8
	box.offset_bottom = -8
	box.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	b.add_child(box)
	# icono a escala entera (1×–3×) para que el pixel art se vea nítido y parejo
	var holder := CenterContainer.new()
	holder.size_flags_vertical = SIZE_EXPAND_FILL
	holder.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(holder)
	if tex:
		var sc := clampf(floorf(minf(88.0 / tex.get_width(), 70.0 / tex.get_height())), 1.0, 3.0)
		var icon := TextureRect.new()
		icon.texture = tex
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = (tex.get_size() * sc).min(Vector2(96, 72))
		icon.mouse_filter = MOUSE_FILTER_IGNORE
		holder.add_child(icon)
	var l := Label.new()
	l.text = title
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size = Vector2(CARD.x - 12, 0)
	l.add_theme_font_size_override("font_size", 16)
	l.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_child(l)
	if note != "":
		var n := Label.new()
		n.text = note
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.add_theme_font_override("font", UiTheme.font(400))
		n.add_theme_font_size_override("font_size", 14)
		n.add_theme_color_override("font_color", UiTheme.INK_SOFT)
		n.mouse_filter = MOUSE_FILTER_IGNORE
		box.add_child(n)
	_cards.add_child(b)
	_card_buttons[key] = b


func _refresh_selection() -> void:
	for key in _card_buttons:
		var b: Button = _card_buttons[key]
		var selected: bool = key == _selected_key
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			var sb := StyleBoxFlat.new()
			sb.set_corner_radius_all(22)
			sb.anti_aliasing = true
			sb.bg_color = UiTheme.CREAM_DEEP if not selected else Color("#f6dcc8")
			if state == "pressed" or state == "hover_pressed":
				sb.bg_color = sb.bg_color.darkened(0.06)
			if selected:
				sb.border_color = UiTheme.ACCENT
				sb.set_border_width_all(4)
			b.add_theme_stylebox_override(state, sb)


func _tab_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.button_group = _tab_group
	b.focus_mode = FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 52)
	b.add_theme_font_size_override("font_size", 21)
	var off := StyleBoxFlat.new()
	off.bg_color = Color(0, 0, 0, 0)
	off.set_corner_radius_all(26)
	off.content_margin_left = 18
	off.content_margin_right = 18
	var on := off.duplicate() as StyleBoxFlat
	on.bg_color = UiTheme.ACCENT
	b.add_theme_stylebox_override("normal", off)
	b.add_theme_stylebox_override("hover", off)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	b.add_theme_color_override("font_color", UiTheme.INK_SOFT)
	b.add_theme_color_override("font_hover_color", UiTheme.INK)
	b.add_theme_color_override("font_pressed_color", UiTheme.CREAM)
	b.add_theme_color_override("font_hover_pressed_color", UiTheme.CREAM)
	return b


func _material_icon(mid: String) -> Texture2D:
	if mid == "water":
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color("#2f78a6"))
		for x in 16:
			img.set_pixel(x, 5, Color("#7fc8d6"))
			if x % 3 != 0:
				img.set_pixel(x, 11, Color("#4a9fc0"))
		return ImageTexture.create_from_image(img)
	var m: Dictionary = Catalog.materials[Catalog.material_index(mid)]
	var at := AtlasTexture.new()
	at.atlas = Catalog.texture(m["atlas"])
	at.region = Rect2(15 * 16, 0, 16, 16)
	return at
