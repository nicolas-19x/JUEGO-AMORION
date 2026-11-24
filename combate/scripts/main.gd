extends Node
## Flujo del juego: menú → selección de enfrentamiento → combate → resultado.
## Orquesta el paso de simulación en un orden fijo (entradas → luchadores →
## contactos → separación → efectos → cámara) para que todo sea predecible.

const PLAYER_PALETTE := {
	"skin": Color(0.62, 0.42, 0.31), "top": Color(0.88, 0.86, 0.81), "pants": Color(0.15, 0.17, 0.23),
	"wrap": Color(0.86, 0.82, 0.73), "accent": Color(0.08, 0.48, 0.5), "hair": Color(0.07, 0.05, 0.05),
	"shoe": Color(0.12, 0.12, 0.14), "bun": true, "rim": Color(1.0, 0.74, 0.5),
}
const FOE_PALETTE := {
	"skin": Color(0.86, 0.68, 0.57), "pants": Color(0.1, 0.09, 0.1), "wrap": Color(0.62, 0.12, 0.12),
	"accent": Color(0.66, 0.13, 0.12), "hair": Color(0.14, 0.12, 0.11), "shoe": Color(0.08, 0.07, 0.07),
	"beard": true, "rim": Color(1.0, 0.55, 0.42),
}
const LEVEL_NAMES := ["Aprendiz", "Duelo", "Maestro"]

var world: Node3D
var arena: Arena
var player: Fighter
var foe: Fighter
var cam: CombatCamera
var fx: ImpactFx
var ai: AiBrain
var touch: TouchControls
var hud: Control
var ui: CanvasLayer

var phase := "menu"   # menu, intro, fight, ko, result
var phase_t := 0.0
var difficulty := 1
var paused := false
var hitstop_global := 0.0
var slowmo_t := 0.0
var _attack_held := false
var _guard_held := false
var _kb_guard := false
var _menu_root: Control
var _result_root: Control
var _pause_root: Control
var _banner: Label
var _hint: Label
var _shown_hint := false
var _ghost := [100.0, 100.0]
var _combo_show := 0.0
var _combo_n := 0
var _menu_yaw := 0.0
var _hit_log: Array = []
var _blood_btn: Button
var _drip_t := {}
const PREFS := "user://prefs.cfg"


func _ready() -> void:
	world = Node3D.new()
	world.name = "World"
	add_child(world)
	arena = Arena.new()
	world.add_child(arena)
	arena.build()
	player = Fighter.new()
	player.name = "Luz"
	world.add_child(player)
	player.setup("LUZ", PLAYER_PALETTE, Vector3(0, 0, 1.4), Vector3(0, 0, -1))
	player.is_player = true
	foe = Fighter.new()
	foe.name = "Ceniza"
	world.add_child(foe)
	foe.setup("CENIZA", FOE_PALETTE, Vector3(0, 0, -1.4), Vector3(0, 0, 1))
	player.opponent = foe
	foe.opponent = player
	for f in [player, foe]:
		f.footstep.connect(_on_footstep)
		f.whoosh.connect(_on_whoosh)
		f.wall_impact.connect(_on_wall)
		f.knocked_out.connect(_on_ko)
		f.guard_crushed.connect(_on_guard_crushed)
	fx = ImpactFx.new()
	world.add_child(fx)
	cam = CombatCamera.new()
	world.add_child(cam)
	cam.player = player
	cam.foe = foe
	cam.current = true
	_load_prefs()
	_build_ui()
	Sfx.start_music()
	_enter_menu()


# ---------------------------------------------------------------------------
# Bucle principal
# ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if paused:
		return
	phase_t += delta / maxf(Engine.time_scale, 0.01)
	if slowmo_t > 0.0:
		slowmo_t -= delta / maxf(Engine.time_scale, 0.01)
		if slowmo_t <= 0.0:
			Engine.time_scale = 1.0
	match phase:
		"menu":
			_menu_update(delta)
			return
		"intro":
			if phase_t > 1.5:
				_set_phase("fight")
				_banner_show("¡COMBATE!", 0.7)
				Sfx.play("ui_go", -4.0, 1.0, 0.0)
		"fight", "ko", "result":
			pass
	sim_step(delta)


## Un paso completo de simulación (lo usan también las pruebas automáticas).
var scripted := false  # pruebas: las entradas las pone el guion


func sim_step(delta: float) -> void:
	if scripted:
		pass
	elif phase == "fight":
		_player_input()
		ai.update(delta)
	else:
		_idle_ctrl(player)
		_idle_ctrl(foe)
	player.step(delta)
	foe.step(delta)
	_check_hits(player, foe, delta)
	_check_hits(foe, player, delta)
	_separate()
	_events(player)
	_events(foe)
	_trails()
	fx.process_fx(delta, cam)
	cam.update(delta)
	touch.counter_glow = phase == "fight" and player.counter_t > 0.0
	touch.special_visible = phase == "fight" and player.can_act() and foe.is_vulnerable_to_special() \
		and player.global_position.distance_to(foe.global_position) < 2.2
	if phase == "ko" and phase_t > 2.6:
		_show_result()
	hud.queue_redraw()


func _idle_ctrl(f: Fighter) -> void:
	f.ctrl.move = Vector3.ZERO
	f.ctrl.guard = false
	f.ctrl.attack_held = false


func _player_input() -> void:
	var c := player.ctrl
	var v := touch.stick
	var kb := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	for k in [[KEY_A, Vector2.LEFT], [KEY_D, Vector2.RIGHT], [KEY_W, Vector2.UP], [KEY_S, Vector2.DOWN]]:
		if Input.is_physical_key_pressed(k[0]):
			kb += k[1]
	if kb.length() > 0.1:
		v = kb.limit_length(1.0)
	# relativo a la cámara
	var cf := -cam.global_transform.basis.z
	cf.y = 0
	cf = cf.normalized()
	var cr := cf.cross(Vector3.UP)
	c.move = (cr * v.x - cf * v.y)
	var kg := Input.is_physical_key_pressed(KEY_K)
	if kg and not _kb_guard:
		_on_guard_down()
	elif not kg and _kb_guard:
		_on_guard_up()
	_kb_guard = kg
	c.guard = _guard_held or kg
	c.attack_held = _attack_held or Input.is_physical_key_pressed(KEY_J) or Input.is_physical_key_pressed(KEY_L)


func _unhandled_key_input(event: InputEvent) -> void:
	var e := event as InputEventKey
	if not e or not e.pressed or e.echo or phase != "fight":
		return
	match e.physical_keycode:
		KEY_J:
			_on_attack_down()
		KEY_L:
			player.ctrl.heavy = true
		KEY_I:
			player.ctrl.special = true
		KEY_ESCAPE, KEY_P:
			_toggle_pause()


func _on_attack_down() -> void:
	_attack_held = true
	if phase != "fight":
		return
	var c := player.ctrl
	var mv: Vector3 = c.move
	var to_foe := (foe.global_position - player.global_position).normalized()
	if mv.length() > 0.75 and mv.normalized().dot(to_foe) > 0.72 and player.state != "attack":
		c.heavy = true
	else:
		c.light = true


func _on_attack_up() -> void:
	_attack_held = false


func _on_guard_down() -> void:
	_guard_held = true
	if phase != "fight":
		return
	var c := player.ctrl
	var mv: Vector3 = c.move
	if mv.length() > 0.5:
		c.dodge = mv.normalized()
	else:
		c.guard_pressed = true


func _on_guard_up() -> void:
	_guard_held = false


func _on_special() -> void:
	if phase == "fight":
		player.ctrl.special = true


# ---------------------------------------------------------------------------
# Contactos y eventos
# ---------------------------------------------------------------------------

func _check_hits(a: Fighter, b: Fighter, delta: float) -> void:
	var h := a.active_hit()
	if h.is_empty() or b.state == "ko" or a.evaded:
		return
	var limb: String = h.limb
	var p: Vector3 = a.rig.points[limb]
	var lv: Vector3 = a.limb_vel.get(limb, Vector3.ZERO)
	var pp := p - lv * delta
	var q1: Vector3 = b.rig.points.hips
	var q2: Vector3 = b.rig.points.head
	var r := Geometry3D.get_closest_points_between_segments(pp, p, q1, q2)
	var d := (r[0] as Vector3).distance_to(r[1])
	if d > float(h.r) + 0.17:
		# esquiva en el último momento: el golpe pasa rozando → contraataque
		if b.in_iframes() and d < float(h.r) + 0.45 and b.move.get("name", "") == "dodge":
			_on_evade(b, a)
		return
	if b.in_iframes():
		_on_evade(b, a)
		return
	var contact: Vector3 = (r[1] as Vector3) + ((r[0] as Vector3) - (r[1] as Vector3)).normalized() * 0.16
	var info := a.resolve_hit(b, h, contact, lv)
	_on_hit(info, lv)


func _on_evade(who: Fighter, attacker: Fighter) -> void:
	attacker.evaded = true
	who.counter_t = 0.75
	Sfx.play("whoosh", -4.0, 0.8)
	cam.kick_fov(2.0)
	if who == player:
		Engine.time_scale = 0.45
		slowmo_t = 0.28
		_flash_text("¡CONTRA!")


func _on_guard_crushed(who: Fighter) -> void:
	Sfx.play("hit_h", -6.0, 0.8)
	cam.add_trauma(0.3)
	if who == foe:
		_flash_text("GUARDIA ROTA")


func _flash_text(t: String) -> void:
	_banner.text = t
	_banner.add_theme_font_size_override("font_size", 44)
	_banner.modulate.a = 1.0
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_interval(0.45)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.3)


func _on_hit(info: Dictionary, lv: Vector3) -> void:
	_hit_log.append(info)
	var level: int = info.level
	var dir: Vector3 = lv.normalized() if lv.length() > 0.1 else ((info.victim as Fighter).global_position - (info.attacker as Fighter).global_position).normalized()
	match info.result:
		"parry":
			fx.impact(info.point, dir, level, "parry")
			Sfx.play("parry", -2.0)
			cam.add_trauma(0.25)
			cam.kick_fov(3.0)
			_haptic(30, 0.6)
		"block":
			fx.impact(info.point, dir, level, "block")
			Sfx.play("block", -4.0 + level)
			cam.add_trauma(0.08 + 0.04 * level)
			_haptic(12, 0.3)
		"guard_break":
			fx.impact(info.point, dir, 3, "block")
			fx.impact(info.point, dir, 2, "hit")
			Sfx.play("block", 0.0, 0.8)
			Sfx.play("hit_m", -4.0)
			cam.add_trauma(0.35)
			cam.kick_fov(3.0)
			_haptic(40, 0.7)
		_:
			var lvl: int = level + (1 if info.get("counter", false) else 0)
			fx.impact(info.point, dir, lvl, "hit")
			var victim: Fighter = info.victim
			if info.move != "shove" and FighterRig.blood_mode > 0:
				var head: bool = info.get("region", "") == "head"
				var amount := (lvl - 1) * 0.5 + (0.6 if head else 0.2) + victim.bleed * 0.6
				if FighterRig.blood_mode == 1:
					amount *= 0.4
				if amount > 0.35:
					fx.blood(info.point, dir + Vector3.UP * 0.25, amount)
			if info.move == "uppercut" and info.get("counter", false):
				Engine.time_scale = 0.3
				slowmo_t = 0.45
				cam.kick_fov(6.0)
			var bank := "hit_l" if lvl <= 1 else ("hit_m" if lvl == 2 else "hit_h")
			Sfx.play(bank, -2.0 + lvl, 1.0 + (0.05 if info.victim == foe else -0.04))
			if lvl >= 2 and FighterRig.blood_mode > 0 and info.move != "shove":
				Sfx.play("wet", -10.0 + lvl * 2.0, 1.0, 0.1)
			cam.add_trauma([0.0, 0.14, 0.22, 0.38, 0.5, 0.6][clampi(lvl, 0, 5)])
			if lvl >= 3:
				cam.kick_fov(2.5 + lvl)
			_haptic([0, 16, 24, 38, 55, 70][clampi(lvl, 0, 5)], [0.0, 0.35, 0.5, 0.75, 0.9, 1.0][clampi(lvl, 0, 5)])
			if info.attacker == player:
				_combo_n = foe.combo_taken
				_combo_show = 1.2


func _events(f: Fighter) -> void:
	# goteo de sangre de nariz y ceja
	if f.bleed > 0.08 and FighterRig.blood_mode > 0:
		var t: float = _drip_t.get(f, 0.0) - get_physics_process_delta_time()
		if t <= 0.0:
			t = randf_range(0.5, 1.4) / (0.4 + f.bleed)
			fx.drip(f.rig.points.get("nose", f.global_position + Vector3.UP * 1.6))
		_drip_t[f] = t
	# caída al suelo en las reacciones de derribo
	if f.move.is_empty():
		return
	var n: String = f.move.get("name", "")
	if (n == "launch" or n == "ko") and f.get_meta("fell_at", -1.0) != f.move_t:
		var prev: float = f.get_meta("prev_t", 0.0)
		if prev < 0.52 and f.move_t >= 0.52:
			Sfx.play("fall", -3.0)
			fx.dust(f.rig.points.hips, 14, 1.4)
			cam.add_trauma(0.22)
			_haptic(35, 0.5)
	f.set_meta("prev_t", f.move_t)


func _trails() -> void:
	for f: Fighter in [player, foe]:
		if f.state != "attack" or not f.move.has("hit"):
			continue
		var h: Dictionary = f.move.hit
		if f.move_t < float(h.from) - 0.06 or f.move_t > float(h.to) + 0.05:
			continue
		var limb: String = h.limb
		var p: Vector3 = f.rig.points[limb]
		var joint := limb.replace("hand", "elbow").replace("foot", "knee")
		if limb.begins_with("knee"):
			joint = "hips"
		var j: Vector3 = f.rig.points.get(joint, p)
		var col := Color(1.0, 0.8, 0.55) if f == player else Color(1.0, 0.45, 0.35)
		fx.trail(f.name + limb, p, p.lerp(j, 0.4), col)


func _separate() -> void:
	if player.sync_target or foe.sync_target:
		return
	var d := foe.global_position - player.global_position
	d.y = 0
	var l := d.length()
	if l < Fighter.SEPARATION and l > 0.001:
		var push := d / l * (Fighter.SEPARATION - l) * 0.5
		player.global_position -= push
		foe.global_position += push
	for f: Fighter in [player, foe]:
		var p := f.global_position
		var lim := Arena.HALF - 0.3
		p.x = clampf(p.x, -lim, lim)
		p.z = clampf(p.z, -lim, lim)
		f.global_position = p


func _on_footstep(f: Fighter, strength: float) -> void:
	if phase == "menu":
		return
	Sfx.play("step", -24.0 + strength * 6.0, 1.0, 0.12)


func _on_whoosh(_f: Fighter, kind: int) -> void:
	Sfx.play("whoosh", -9.0 + kind * 2.0, 1.0 - kind * 0.08)


func _on_wall(f: Fighter, point: Vector3, strength: float) -> void:
	Sfx.play("wall", 0.0)
	fx.dust(point, 20, 1.6)
	if FighterRig.blood_mode > 0 and f.bleed > 0.15:
		fx.wall_stain(point + Vector3.DOWN * 0.2, f.global_transform.basis.z, 0.5 + f.bleed * 0.4)
	fx.impact(point, Vector3.UP, 3, "hit")
	cam.add_trauma(0.55)
	cam.kick_fov(5.0)
	_haptic(60, 0.9)
	for rb in arena.props:
		var dd := rb.global_position.distance_to(f.global_position)
		if dd < 2.2:
			rb.apply_central_impulse((rb.global_position - f.global_position).normalized() * strength * 3.0 + Vector3.UP * 2.0)


func _on_ko(who: Fighter) -> void:
	_set_phase("ko")
	Engine.time_scale = 0.3
	slowmo_t = 1.1
	Sfx.play("ko", 0.0)
	Sfx.set_drums(-80.0, 1.2)
	cam.cinematic(who)
	_haptic(120, 1.0)
	touch.enabled = false
	touch.release_all()
	_attack_held = false
	_guard_held = false


func _haptic(ms: int, amp: float) -> void:
	if ms > 0 and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms, amp)


# ---------------------------------------------------------------------------
# Fases
# ---------------------------------------------------------------------------

func _set_phase(p: String) -> void:
	phase = p
	phase_t = 0.0


func _enter_menu() -> void:
	_set_phase("menu")
	Engine.time_scale = 1.0
	paused = false
	player.reset(Vector3(-0.5, 0, 0.9), Vector3(0.5, 0, -0.9))
	foe.reset(Vector3(0.5, 0, -0.9), Vector3(-0.5, 0, 0.9))
	arena.reset_props()
	fx.clear_stains()
	cam.cine_t = -1.0
	_menu_root.visible = true
	_result_root.visible = false
	_pause_root.visible = false
	touch.visible = false
	hud.visible = false
	Sfx.set_drums(-80.0, 0.5)


func _menu_update(delta: float) -> void:
	_idle_ctrl(player)
	_idle_ctrl(foe)
	player.step(delta)
	foe.step(delta)
	_menu_yaw += delta * 0.12
	var c := Vector3(0, 1.1, 0)
	var pos := c + Basis(Vector3.UP, _menu_yaw) * Vector3(0, 0.5, 4.6)
	cam.global_position = pos
	# los luchadores quedan en el tercio derecho; el texto, a la izquierda
	var right := (c - pos).cross(Vector3.UP).normalized()
	cam.look_at(c + Vector3(0, 0.1, 0) - right * 1.35, Vector3.UP)
	cam.fov = 50.0
	fx.process_fx(delta, cam)


func start_fight() -> void:
	Engine.time_scale = 1.0
	player.reset(Vector3(0, 0, 1.5), Vector3(0, 0, -1))
	foe.reset(Vector3(0, 0, -1.5), Vector3(0, 0, 1))
	arena.reset_props()
	fx.clear_stains()
	ai = AiBrain.new(foe, player, difficulty)
	cam.cine_t = -1.0
	cam.trauma = 0.0
	cam.snap()
	_ghost = [100.0, 100.0]
	_hit_log.clear()
	_menu_root.visible = false
	_result_root.visible = false
	touch.visible = true
	touch.enabled = true
	hud.visible = true
	_set_phase("intro")
	_banner_show("LUZ  vs  CENIZA", 1.3)
	Sfx.play("ui_tap", -6.0, 1.0, 0.0)
	Sfx.set_drums(-17.0, 2.0)
	if not _shown_hint:
		_shown_hint = true
		_hint.text = "GOLPE: combo (pegado al rival sale un gancho) · Hacia el rival + GOLPE: patada fuerte · Atrás + GOLPE: empujón\nDEFENSA: cubrirse (la barra blanca se llena) · justo a tiempo: parada · con dirección lateral: esquiva → ¡CONTRA!"
		_hint.modulate.a = 1.0
		var tw := create_tween()
		tw.tween_interval(8.0)
		tw.tween_property(_hint, "modulate:a", 0.0, 1.0)


func _show_result() -> void:
	_set_phase("result")
	_result_root.visible = true
	var won := foe.hp <= 0.0
	(_result_root.get_node("Title") as Label).text = "VICTORIA" if won else "DERROTA"
	(_result_root.get_node("Sub") as Label).text = "Ceniza ha caído." if won else "Luz ha caído."


func _toggle_pause() -> void:
	if phase != "fight" and phase != "intro":
		return
	paused = not paused
	_pause_root.visible = paused
	touch.release_all()
	_attack_held = false
	_guard_held = false


# ---------------------------------------------------------------------------
# Interfaz
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.draw.connect(_draw_hud)
	ui.add_child(hud)
	touch = TouchControls.new()
	ui.add_child(touch)
	touch.attack_down.connect(_on_attack_down)
	touch.attack_up.connect(_on_attack_up)
	touch.guard_down.connect(_on_guard_down)
	touch.guard_up.connect(_on_guard_up)
	touch.special_down.connect(_on_special)
	touch.pause_down.connect(_toggle_pause)

	_banner = _label("", 64, Color(1, 0.94, 0.86))
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.position = Vector2(-400, -160)
	_banner.size = Vector2(800, 90)
	_banner.modulate.a = 0.0
	ui.add_child(_banner)
	_hint = _label("", 19, Color(1, 0.95, 0.88))
	_hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hint.position = Vector2(-560, 76)
	_hint.size = Vector2(1120, 60)
	_hint.modulate.a = 0.0
	ui.add_child(_hint)

	# menú principal
	_menu_root = Control.new()
	_menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(_menu_root)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.05, 0.03, 0.07, 0.35)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_root.add_child(shade)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	col.position = Vector2(80, -230)
	col.size = Vector2(520, 460)
	col.add_theme_constant_override("separation", 14)
	_menu_root.add_child(col)
	col.add_child(_label("CONTACTO", 84, Color(1, 0.93, 0.84)))
	col.add_child(_label("Un enfrentamiento. Que cada golpe cuente.", 22, Color(1, 0.8, 0.62, 0.9)))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	col.add_child(spacer)
	col.add_child(_label("ENFRENTAMIENTO", 16, Color(1, 0.85, 0.7, 0.7)))
	col.add_child(_label("Luz  vs  Ceniza  ·  Azotea del Farol", 28, Color(1, 1, 1)))
	var diff_row := HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 10)
	col.add_child(diff_row)
	var group := ButtonGroup.new()
	for i in 3:
		var b := _button(LEVEL_NAMES[i], 22)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == difficulty
		b.custom_minimum_size = Vector2(150, 58)
		b.pressed.connect(func(): difficulty = i; _save_prefs(); Sfx.play("ui_tap", -8.0, 1.0 + i * 0.1, 0.0))
		diff_row.add_child(b)
	_blood_btn = _button("", 20)
	_blood_btn.custom_minimum_size = Vector2(470, 48)
	_blood_btn.pressed.connect(_cycle_blood)
	col.add_child(_blood_btn)
	_update_blood_btn()
	var go := _button("COMBATIR", 32)
	go.custom_minimum_size = Vector2(470, 84)
	go.pressed.connect(start_fight)
	col.add_child(go)

	# resultado
	_result_root = _overlay_panel("Title", "Sub")
	var rb := _result_root.get_node("Box") as VBoxContainer
	var again := _button("REVANCHA", 28)
	again.pressed.connect(start_fight)
	rb.add_child(again)
	var menu := _button("MENÚ", 24)
	menu.pressed.connect(_enter_menu)
	rb.add_child(menu)
	_result_root.visible = false

	# pausa
	_pause_root = _overlay_panel("Title", "Sub")
	(_pause_root.get_node("Title") as Label).text = "PAUSA"
	(_pause_root.get_node("Sub") as Label).text = "Teclado: WASD mover · J golpe · L fuerte · K defensa · I remate"
	var pb := _pause_root.get_node("Box") as VBoxContainer
	var cont := _button("CONTINUAR", 28)
	cont.pressed.connect(_toggle_pause)
	pb.add_child(cont)
	var pm := _button("MENÚ", 24)
	pm.pressed.connect(_enter_menu)
	pb.add_child(pm)
	_pause_root.visible = false


func _overlay_panel(title_name: String, sub_name: String) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(root)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.04, 0.02, 0.05, 0.55)
	root.add_child(shade)
	var t := _label("", 72, Color(1, 0.93, 0.84))
	t.name = title_name
	t.set_anchors_preset(Control.PRESET_CENTER)
	t.position = Vector2(-400, -220)
	t.size = Vector2(800, 90)
	root.add_child(t)
	var s := _label("", 22, Color(1, 0.82, 0.66))
	s.name = sub_name
	s.set_anchors_preset(Control.PRESET_CENTER)
	s.position = Vector2(-500, -120)
	s.size = Vector2(1000, 40)
	root.add_child(s)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-180, -50)
	box.size = Vector2(360, 200)
	box.add_theme_constant_override("separation", 12)
	root.add_child(box)
	return root


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if size >= 60 and text == "" else HORIZONTAL_ALIGNMENT_LEFT
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if text == "":
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _button(text: String, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_NONE
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.06, 0.1, 0.72)
	normal.border_color = Color(1, 0.75, 0.5, 0.6)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.16, 0.1, 0.12, 0.85)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.85, 0.48, 0.28, 0.9)
	pressed.border_color = Color(1, 0.88, 0.7, 1)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_color_override("font_color", Color(1, 0.93, 0.85))
	b.add_theme_color_override("font_pressed_color", Color(0.1, 0.05, 0.05))
	return b


func _cycle_blood() -> void:
	FighterRig.blood_mode = (FighterRig.blood_mode + 2) % 3
	_update_blood_btn()
	_save_prefs()
	Sfx.play("ui_tap", -8.0, 1.0, 0.0)
	for f in [player, foe]:
		(f as Fighter).rig.update_face(0.1)


func _update_blood_btn() -> void:
	_blood_btn.text = "Sangre: " + ["Apagada", "Reducida", "Normal"][FighterRig.blood_mode]


func _load_prefs() -> void:
	var cf := ConfigFile.new()
	if cf.load(PREFS) == OK:
		FighterRig.blood_mode = int(cf.get_value("juego", "sangre", 2))
		difficulty = int(cf.get_value("juego", "dificultad", 1))


func _save_prefs() -> void:
	var cf := ConfigFile.new()
	cf.set_value("juego", "sangre", FighterRig.blood_mode)
	cf.set_value("juego", "dificultad", difficulty)
	cf.save(PREFS)


func _banner_show(text: String, hold: float) -> void:
	_banner.add_theme_font_size_override("font_size", 64)
	_banner.text = text
	_banner.modulate.a = 1.0
	_banner.scale = Vector2.ONE
	var tw := create_tween()
	tw.tween_interval(hold)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.35)


func _draw_hud() -> void:
	var vp := hud.get_viewport_rect().size
	var font := ThemeDB.fallback_font
	var w := minf(440.0, vp.x * 0.34)
	var y := 30.0
	for i in 2:
		var f: Fighter = player if i == 0 else foe
		var frac := clampf(f.hp / f.max_hp, 0.0, 1.0)
		_ghost[i] = move_toward(_ghost[i], f.hp, (40.0 if _ghost[i] - f.hp < 3 else 26.0) * get_physics_process_delta_time())
		var gfrac := clampf(_ghost[i] / f.max_hp, 0.0, 1.0)
		var left := i == 0
		var x0 := 40.0 if left else vp.x - 40.0 - w
		var sk := 14.0
		_bar(x0, y, w, 16, 1.0, Color(0.05, 0.04, 0.06, 0.6), left, sk)
		_bar(x0, y, w, 16, gfrac, Color(1, 0.92, 0.85, 0.75), left, sk)
		var hc := Color(1.0, 0.68, 0.38) if left else Color(0.92, 0.3, 0.26)
		if frac < 0.3:
			hc = hc.lerp(Color(1, 0.2, 0.15), 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.01))
		_bar(x0, y, w, 16, frac, hc, left, sk)
		# equilibrio: barra fina bajo la vida; parpadea cerca de romperse
		var pf := clampf(f.posture / 100.0, 0.0, 1.0)
		var pc := Color(0.95, 0.9, 0.78, 0.85)
		if pf > 0.75:
			pc = pc.lerp(Color(1, 0.35, 0.2), 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02))
		_bar(x0, y + 20, w * 0.7 if left else w, 6, 0.0, Color(0, 0, 0, 0), left, 4)
		var pw := w * 0.6
		var px := x0 if left else x0 + w - pw
		_bar(px, y + 21, pw, 6, 1.0, Color(0.05, 0.04, 0.06, 0.5), left, 4)
		_bar(px, y + 21, pw, 6, pf, pc, left, 4)
		var name_x := x0 if left else x0 + w - font.get_string_size(f.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		hud.draw_string(font, Vector2(name_x, y + 50), f.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.93, 0.85, 0.9))
	if _combo_show > 0.0:
		_combo_show -= get_physics_process_delta_time()
		if _combo_n >= 2:
			var a := clampf(_combo_show * 2.0, 0.0, 1.0)
			hud.draw_string(font, Vector2(46, 120), "%d GOLPES" % _combo_n, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 0.8, 0.5, a))


func _bar(x: float, y: float, w: float, h: float, frac: float, c: Color, left: bool, sk: float) -> void:
	if frac <= 0.0:
		return
	var fw := w * frac
	var pts: PackedVector2Array
	if left:
		pts = PackedVector2Array([Vector2(x + sk, y), Vector2(x + fw, y), Vector2(x + fw - sk, y + h), Vector2(x, y + h)])
		if fw < sk:
			pts = PackedVector2Array([Vector2(x, y), Vector2(x + fw, y), Vector2(x + fw, y + h), Vector2(x, y + h)])
	else:
		var xs := x + w - fw
		pts = PackedVector2Array([Vector2(xs, y), Vector2(x + w - sk, y), Vector2(x + w, y + h), Vector2(xs + sk, y + h)])
		if fw < sk:
			pts = PackedVector2Array([Vector2(xs, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(xs, y + h)])
	hud.draw_colored_polygon(pts, c)
