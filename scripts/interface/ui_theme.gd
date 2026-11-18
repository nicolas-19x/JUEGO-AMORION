class_name UiTheme
extends RefCounted
## Identidad visual de la interfaz: cálida, minimalista y legible en el móvil.
## El mundo es pixel art; la interfaz se dibuja nítida a resolución nativa.

const CREAM := Color("#fbf3e4")
const CREAM_DEEP := Color("#efe1c9")
const INK := Color("#3b2a2e")
const INK_SOFT := Color("#7d6866")
const ACCENT := Color("#c8705a")
const ACCENT_DEEP := Color("#a4523f")
const SAGE := Color("#5e8f74")
const NIGHT := Color("#1d2147")

static var _theme: Theme
static var _fonts: Dictionary = {}


static func font(weight := 700) -> Font:
	if not _fonts.has(weight):
		_fonts[weight] = load("res://assets/fonts/nunito-latin-%d-normal.woff2" % weight)
	return _fonts[weight]


## Icono pixel art a escala entera, nítido dentro de la interfaz.
static func pixel_icon(path: String, scale: int) -> TextureRect:
	var r := TextureRect.new()
	r.texture = load(path)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.custom_minimum_size = r.texture.get_size() * scale
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func panel_box(bg := CREAM, radius := 26, margin := 28.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	sb.shadow_color = Color(0.07, 0.05, 0.12, 0.28)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 5)
	sb.anti_aliasing = true
	return sb


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font(700)
	t.default_font_size = 26
	t.set_stylebox("panel", "PanelContainer", panel_box())
	t.set_color("font_color", "Label", INK)
	# botones
	for state in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(20)
		sb.content_margin_left = 22
		sb.content_margin_right = 22
		sb.content_margin_top = 12
		sb.content_margin_bottom = 12
		sb.bg_color = {"normal": CREAM_DEEP, "hover": CREAM_DEEP.lightened(0.15), "pressed": ACCENT,
				"hover_pressed": ACCENT, "disabled": CREAM_DEEP.darkened(0.05)}[state]
		sb.anti_aliasing = true
		t.set_stylebox(state, "Button", sb)
		t.set_stylebox(state, "OptionButton", sb)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	for k in ["font_color", "font_hover_color", "font_focus_color"]:
		t.set_color(k, "Button", INK)
		t.set_color(k, "OptionButton", INK)
	t.set_color("font_pressed_color", "Button", CREAM)
	t.set_color("font_hover_pressed_color", "Button", CREAM)
	t.set_color("font_disabled_color", "Button", INK_SOFT)
	# menú desplegable
	t.set_stylebox("panel", "PopupMenu", panel_box(CREAM, 18, 14))
	t.set_color("font_color", "PopupMenu", INK)
	t.set_color("font_hover_color", "PopupMenu", ACCENT_DEEP)
	t.set_font_size("font_size", "PopupMenu", 28)
	t.set_constant("v_separation", "PopupMenu", 18)
	var hover := StyleBoxFlat.new()
	hover.bg_color = CREAM_DEEP
	hover.set_corner_radius_all(12)
	t.set_stylebox("hover", "PopupMenu", hover)
	# deslizadores grandes para el pulgar
	var track := StyleBoxFlat.new()
	track.bg_color = CREAM_DEEP.darkened(0.08)
	track.set_corner_radius_all(8)
	track.content_margin_top = 7
	track.content_margin_bottom = 7
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = SAGE
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var knob := _circle_texture(40, ACCENT, CREAM)
	t.set_icon("grabber", "HSlider", knob)
	t.set_icon("grabber_highlight", "HSlider", knob)
	_theme = t
	return t


static func _circle_texture(d: int, fill: Color, ring: Color) -> Texture2D:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var r := d / 2.0
	for y in d:
		for x in d:
			var dist := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var a := clampf(r - dist, 0.0, 1.0)
			var c := ring if dist > r - 5.0 else fill
			img.set_pixel(x, y, Color(c, a))
	return ImageTexture.create_from_image(img)
