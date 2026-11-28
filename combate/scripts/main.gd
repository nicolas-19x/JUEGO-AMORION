extends Node
## Flujo del juego: menú → selección de enfrentamiento → combate → resultado.
## Orquesta el paso de simulación en un orden fijo (entradas → luchadores →
## contactos → separación → efectos → cámara) para que todo sea predecible.

const PLAYER_PALETTE := {
	"skin": Color(0.62, 0.42, 0.31), "top": Color(0.88, 0.86, 0.81), "pants": Color(0.15, 0.17, 0.23),
	"wrap": Color(0.86, 0.82, 0.73), "accent": Color(0.08, 0.48, 0.5), "hair": Color(0.07, 0.05, 0.05),
	"shoe": Color(0.12, 0.12, 0.14), "sole": Color(0.9, 0.88, 0.84), "bun": true, "rim": Color(1.0, 0.74, 0.5),
	"bulk": 0.97, "jaw": 0.92, "model": "res://assets/characters/nico/nico.res",
}
const FOE_PALETTE := {
	"skin": Color(0.86, 0.68, 0.57), "pants": Color(0.1, 0.09, 0.1), "wrap": Color(0.62, 0.12, 0.12),
	"accent": Color(0.66, 0.13, 0.12), "hair": Color(0.14, 0.12, 0.11), "shoe": Color(0.08, 0.07, 0.07),
	"beard": true, "rim": Color(1.0, 0.55, 0.42), "sole": Color(0.2, 0.18, 0.17),
	"bulk": 1.1, "jaw": 1.08,
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
var _kick_held := false
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
const REC_FRAMES := 210
var _rec: Array = []
var _frame_hits: Array = []
var _replay_pos := 0.0
var _replay_end := 0
var _replay_ang := 0.0
var _bars: Array[ColorRect] = []
var _replay_label: Label
var _blood_btn: Button
var _quality_btn: Button
var game_speed := 1.0
var high_quality := true
const TUNE := [
	["Pausa de impacto", "hitstop", 0.0, 2.0, 1.0],
	["Velocidad del juego", "speed", 0.75, 1.25, 1.0],
	["Sacudida de cámara", "shake", 0.0, 2.0, 1.0],
	["Vibración", "haptics", 0.0, 1.5, 1.0],
	["Ventana de combo", "buffer", 0.15, 0.5, 0.3],
]
var tune := {"hitstop": 1.0, "speed": 1.0, "shake": 1.0, "haptics": 1.0, "buffer": 0.3}
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
	player.name = "Nico"
	world.add_child(player)
	player.setup("NICO", PLAYER_PALETTE, Vector3(0, 0, 1.4), Vector3(0, 0, -1))
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
	_apply_quality()
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
				Sfx.play("gong", -3.0, 1.0, 0.0)
				Sfx.announcer("vo_combate", -2.0)
		"replay":
			_replay_update(delta)
			return
		"fight", "ko", "result":
			pass
	sim_step(delta * game_speed)


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
	_record()
	if phase == "ko" and phase_t > 2.6:
		if _rec.size() > 60 and not scripted:
			_start_replay()
		else:
			_show_result()
	hud.queue_redraw()


# ---------------------------------------------------------------------------
# Repetición del KO
# ---------------------------------------------------------------------------

func _record() -> void:
	if phase != "fight" and phase != "ko":
		return
	_rec.append({"p": [player.global_transform, player.last_apply], "f": [foe.global_transform, foe.last_apply],
		"hits": _frame_hits.duplicate()})
	_frame_hits.clear()
	while _rec.size() > REC_FRAMES:
		_rec.pop_front()


func _start_replay() -> void:
	_set_phase("replay")
	Engine.time_scale = 1.0
	slowmo_t = 0.0
	_replay_pos = 0.0
	_replay_end = _rec.size() - 1
	var victim := foe if foe.hp <= 0.0 else player
	# de lado respecto a la línea entre los dos, por el lado con más espacio
	var line := foe.global_position - player.global_position
	line.y = 0
	var perp := line.normalized().cross(Vector3.UP)
	var mid := (foe.global_position + player.global_position) * 0.5
	if (mid + perp * 3.0).length() > (mid - perp * 3.0).length():
		perp = -perp
	_replay_ang = atan2(perp.x, perp.z) - 0.25
	cam.replay_mode = true
	hud.visible = false
	touch.visible = false
	for b in _bars:
		b.visible = true
	_replay_label.visible = true
	_replay_label.modulate.a = 1.0
	Sfx.play("ui_tap", -10.0, 0.7, 0.0)
	set_meta("replay_victim", victim)


func _replay_update(delta: float) -> void:
	# a cámara lenta: 0,4× al principio, más lenta aún cerca del golpe final
	var near_end := clampf((_replay_end - _replay_pos) / 40.0, 0.0, 1.0)
	_replay_pos += lerpf(0.18, 0.45, near_end)
	var i := clampi(int(_replay_pos), 0, _replay_end)
	var fr: Dictionary = _rec[i]
	player.replay_frame(fr.p[0], fr.p[1], delta * 0.4)
	foe.replay_frame(fr.f[0], fr.f[1], delta * 0.4)
	for h in fr.hits:
		fx.impact(h.point, h.dir, h.level, "hit")
		if FighterRig.blood_mode > 0 and h.region == "head":
			fx.blood(h.point, h.dir, 0.8 + h.level * 0.4)
	fr.hits = []
	fx.process_fx(delta * 0.4, cam)
	var victim: Fighter = get_meta("replay_victim")
	var c: Vector3 = victim.rig.points.get("chest", victim.global_position)
	var mid := ((player.global_position + foe.global_position) * 0.5).lerp(c, 0.4)
	mid.y = 1.0
	_replay_ang += delta * 0.12
	var pos := mid + Basis(Vector3.UP, _replay_ang) * Vector3(0, 0.0, 3.0) + Vector3.UP * 0.35
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(mid, pos, 1 | 8))
	if hit:
		pos = (hit.position as Vector3) + (mid - pos).normalized() * 0.25
	cam.global_position = cam.global_position.lerp(pos, minf(1.0, delta * 4.0)) if phase_t > 0.05 else pos
	cam.look_at(mid, Vector3.UP)
	cam.fov = 42.0
	_replay_label.modulate.a = 0.6 + 0.4 * sin(phase_t * 4.0)
	if _replay_pos >= _replay_end:
		_end_replay()


func _end_replay() -> void:
	cam.replay_mode = false
	for b in _bars:
		b.visible = false
	_replay_label.visible = false
	# dejar a los luchadores en su último estado real
	var last: Dictionary = _rec[_rec.size() - 1]
	player.replay_frame(last.p[0], last.p[1], 0.016)
	foe.replay_frame(last.f[0], last.f[1], 0.016)
	_rec.clear()
	_show_result()


func _input(event: InputEvent) -> void:
	if phase == "replay" and phase_t > 0.4:
		if (event is InputEventScreenTouch and event.pressed) or (event is InputEventKey and event.pressed):
			_end_replay()
			get_viewport().set_input_as_handled()


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
	var kg := Input.is_physical_key_pressed(KEY_L)
	if kg and not _kb_guard:
		_on_guard_down()
	elif not kg and _kb_guard:
		_on_guard_up()
	_kb_guard = kg
	c.guard = _guard_held or kg
	# mantener PATADA carga la patada frontal
	c.attack_held = _kick_held or Input.is_physical_key_pressed(KEY_K)


func _unhandled_key_input(event: InputEvent) -> void:
	var e := event as InputEventKey
	if not e or not e.pressed or e.echo or phase != "fight":
		return
	match e.physical_keycode:
		KEY_J:
			_on_attack_down()
		KEY_K:
			_on_kick_down()
		KEY_SPACE:
			_on_dodge_down()
		KEY_I:
			player.ctrl.special = true
		KEY_ESCAPE, KEY_P:
			_toggle_pause()


func _on_attack_down() -> void:
	_attack_held = true
	if phase == "fight":
		player.ctrl.punch = true


func _on_kick_down() -> void:
	_kick_held = true
	if phase == "fight":
		player.ctrl.kick = true


func _on_kick_up() -> void:
	_kick_held = false


func _on_dodge_down() -> void:
	if phase != "fight":
		return
	var c := player.ctrl
	var mv: Vector3 = c.move
	c.dodge = mv.normalized() if mv.length() > 0.5 else Vector3.ZERO
	c.dodge_pressed = true


func _on_attack_up() -> void:
	_attack_held = false


func _on_guard_down() -> void:
	_guard_held = true
	if phase == "fight":
		player.ctrl.guard_pressed = true


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
	# zona de impacto: de las rodillas a la cabeza (las patadas bajas también cuentan)
	var q1: Vector3 = b.rig.points.hips.lerp(b.global_position, 0.6)
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
	# punto de contacto: donde está el puño/pie, ligeramente hacia la superficie del cuerpo
	var contact: Vector3 = (r[0] as Vector3).lerp(r[1], 0.25)
	var info := a.resolve_hit(b, h, contact, lv)
	_on_hit(info, lv)


## Audio de un impacto: banco según zona y fuerza, base grave sintetizada,
## capa húmeda si hay sangre, y la reacción vocal de quien lo recibe.
func _hit_audio(info: Dictionary, lvl: int) -> void:
	var victim: Fighter = info.victim
	var region: String = info.get("region", "body")
	var bank := "hit_l" if lvl <= 1 else ("hit_m" if lvl == 2 else "hit_h")
	if region == "legs":
		bank = "hit_k"
	elif region == "body" and lvl <= 3:
		bank = "hit_b"
	if info.move == "shove":
		bank = "hit_b"
	var db := -3.0 + minf(lvl, 4) * 0.8
	Sfx.play(bank, db, 1.0 + (0.04 if victim == foe else -0.03), 0.05)
	var syn := "syn_hit_l" if lvl <= 1 else ("syn_hit_m" if lvl == 2 else "syn_hit_h")
	Sfx.play(syn, -14.0 + lvl * 1.5, 1.0, 0.08)
	if lvl >= 2 and FighterRig.blood_mode > 0 and info.move != "shove":
		Sfx.play("syn_wet", -11.0 + lvl * 2.0, 1.0, 0.1)
	if lvl >= 4 or info.get("counter", false):
		Sfx.duck(-5.0, 0.35, 0.8)
	# voz de quien recibe el golpe
	var who := "player" if victim == player else "foe"
	if info.move == "shove":
		return
	if region == "body" and lvl >= 2:
		Sfx.voice(who, "winded" if lvl >= 3 else "pain", -4.0, 0.18)
	elif region == "legs":
		Sfx.voice(who, "pain", -5.0, 0.18, 0.9)
	elif lvl >= 2 or randf() < 0.55:
		Sfx.voice(who, "pain", -4.0 + minf(lvl, 4) * 0.5, 0.18)


func _on_evade(who: Fighter, attacker: Fighter) -> void:
	attacker.evaded = true
	who.counter_t = 0.75
	Sfx.play("whoosh_p", -3.0, 0.8)
	if who == player:
		Haptics.play("evade")
	cam.kick_fov(2.0)
	if who == player:
		Engine.time_scale = 0.45
		slowmo_t = 0.28
		_flash_text("¡CONTRA!")


func _on_guard_crushed(who: Fighter) -> void:
	Sfx.play("hit_h", -6.0, 0.8)
	Sfx.voice("player" if who == player else "foe", "winded", -3.0, 0.1)
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
	if info.result == "hit":
		var d := lv.normalized() if lv.length() > 0.1 else Vector3.FORWARD
		_frame_hits.append({"point": info.point, "dir": d, "level": int(info.level), "region": info.get("region", "")})
		# remate de cámara: el golpe que derriba a cámara lenta y desde un lado
		if info.attacker == player and info.get("reaction", "") == "launch" and phase == "fight":
			cam.finisher(info.victim, info.attacker)
			Engine.time_scale = 0.35
			slowmo_t = 0.4
	var level: int = info.level
	var dir: Vector3 = lv.normalized() if lv.length() > 0.1 else ((info.victim as Fighter).global_position - (info.attacker as Fighter).global_position).normalized()
	match info.result:
		"parry":
			fx.impact(info.point, dir, level, "parry")
			Sfx.play("parry", -2.0)
			Sfx.play("syn_parry", -10.0)
			cam.add_trauma(0.25)
			cam.kick_fov(3.0)
			Haptics.play("parry", info.victim != player)
		"block":
			fx.impact(info.point, dir, level, "block")
			Sfx.play("block", -4.0 + level)
			Sfx.play("syn_block", -13.0)
			Sfx.voice("player" if info.victim == player else "foe", "effort", -9.0, 0.3, 0.9)
			cam.add_trauma(0.08 + 0.04 * level)
			Haptics.play("block", info.victim == player)
		"guard_break":
			fx.impact(info.point, dir, 3, "block")
			fx.impact(info.point, dir, 2, "hit")
			Sfx.play("block", 0.0, 0.8)
			Sfx.play("hit_m", -4.0)
			Sfx.play("syn_hit_h", -10.0)
			cam.add_trauma(0.35)
			cam.kick_fov(3.0)
			Haptics.play("guard_break", info.victim == player)
		_:
			var lvl: int = level + (1 if info.get("counter", false) else 0)
			fx.impact(info.point, dir, lvl, "hit")
			var victim: Fighter = info.victim
			if info.move != "shove" and FighterRig.blood_mode > 0:
				_blood_for_hit(info, dir, lvl)
			if info.move == "uppercut" and info.get("counter", false):
				Engine.time_scale = 0.3
				slowmo_t = 0.45
				cam.kick_fov(6.0)
			_hit_audio(info, lvl)
			cam.add_trauma([0.0, 0.14, 0.22, 0.38, 0.5, 0.6][clampi(lvl, 0, 5)])
			if lvl >= 3:
				cam.kick_fov(2.5 + lvl)
			var pat := "light" if lvl <= 1 else ("medium" if lvl == 2 else "heavy")
			if info.get("counter", false) and lvl >= 3:
				pat = "counter"
			Haptics.play(pat, info.victim == player)
			if info.attacker == player:
				_combo_n = foe.combo_taken
				_combo_show = 1.2


func _blood_for_hit(info: Dictionary, dir: Vector3, lvl: int) -> void:
	var victim: Fighter = info.victim
	var k := 0.45 if FighterRig.blood_mode == 1 else 1.0
	var region: String = info.get("region", "")
	var d := (dir + Vector3.UP * 0.25).normalized()
	if region == "head":
		var amount := (0.5 + lvl * 0.45 + victim.bleed * 0.9) * k
		fx.blood(info.point, d, amount)
		# salpica el pecho, los brazos y la cara de quien golpea
		var att: Fighter = info.attacker
		if victim.bleed > 0.15:
			for i in 1 + int(lvl / 2):
				var tgt := ["chest", "hand_l", "hand_r", "head"][randi() % 4] as String
				var pt: Vector3 = att.rig.points.get(tgt, att.global_position)
				att.rig.add_blood(pt + Vector3(randf_range(-0.07, 0.07), randf_range(-0.05, 0.08), randf_range(-0.07, 0.07)), 0.5 * k, 0.4)
		# y la propia cara de la víctima se llena de sangre
		victim.rig.add_blood(info.point, 0.6 * k, 0.3)
		# golpe fuerte a la cara: escupe sangre
		if (lvl >= 3 or info.get("counter", false) or info.reaction == "ko") and victim.bleed > 0.1:
			var mouth: Vector3 = victim.rig.points.get("nose", info.point) + Vector3.DOWN * 0.05
			fx.spit(mouth, d)
			Sfx.voice("player" if victim == player else "foe", "spit", -3.0, 0.5)
	elif region == "body" and lvl >= 2:
		fx.blood(info.point, d, (0.2 + lvl * 0.2) * k)
		if victim.body_dmg > 25.0 and randf() < 0.5:
			fx.spit(victim.rig.points.get("nose", info.point), -victim.global_transform.basis.z * 0.6 + Vector3.DOWN * 0.4)
	if info.reaction == "ko":
		fx.blood(info.point, d, 2.6 * k)


var _breath_at := {}


func _events(f: Fighter) -> void:
	# respiración agitada cuando le queda poca vida (más seguida y fuerte cuanto peor)
	if phase == "fight" and f.state != "ko" and f.hp < f.max_hp * 0.4 and f.freeze <= 0.0:
		var now := Time.get_ticks_msec() / 1000.0
		if now >= float(_breath_at.get(f, 0.0)):
			var worse := clampf(1.0 - f.hp / (f.max_hp * 0.4), 0.0, 1.0)
			_breath_at[f] = now + lerpf(7.5, 4.5, worse)
			Sfx.voice("player" if f == player else "foe", "breath", -15.0 + worse * 6.0, 1.0)

	# goteo de sangre de nariz y ceja
	if f.bleed > 0.08 and FighterRig.blood_mode > 0:
		var t: float = _drip_t.get(f, 0.0) - get_physics_process_delta_time()
		if t <= 0.0:
			t = randf_range(0.5, 1.4) / (0.4 + f.bleed)
			fx.drip(f.rig.points.get("nose", f.global_position + Vector3.UP * 1.6))
			# la sangre baja por la barbilla al pecho
			if f.bleed > 0.3 and randf() < 0.4:
				var chest: Vector3 = f.rig.points.chest
				f.rig.add_blood(chest + Vector3.UP * 0.12 - f.global_transform.basis.z * 0.12 + f.global_transform.basis.x * randf_range(-0.07, 0.07), 0.35)
		_drip_t[f] = t
	# caída al suelo en las reacciones de derribo
	if f.move.is_empty():
		return
	var n: String = f.move.get("name", "")
	# charco bajo la cabeza de quien yace sangrando
	if FighterRig.blood_mode > 0 and ((n == "launch" and f.move_t > 0.55 and f.move_t < 1.3) or (n == "ko" and f.move_t > 0.55)):
		if f.bleed > 0.05 or n == "ko":
			var grow := get_physics_process_delta_time() * (0.25 if n == "ko" else 0.12) * (0.4 + f.bleed)
			var key := "%d_%d" % [f.get_instance_id(), int((f.time - f.move_t) * 10.0)]
			fx.pool(key, f.rig.points.get("head", f.global_position), grow * (0.5 if FighterRig.blood_mode == 1 else 1.0))
	if (n == "launch" or n == "ko") and f.get_meta("fell_at", -1.0) != f.move_t:
		var prev: float = f.get_meta("prev_t", 0.0)
		if prev < 0.52 and f.move_t >= 0.52:
			Sfx.play("fall", -2.0)
			Sfx.play("syn_fall", -9.0)
			fx.dust(f.rig.points.hips, 14, 1.4)
			cam.add_trauma(0.22)
			Haptics.play("fall", f == player)
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
	if not (player.sync_target or foe.sync_target):
		var d := foe.global_position - player.global_position
		d.y = 0
		var l := d.length()
		if l < Fighter.SEPARATION and l > 0.001:
			var push := d / l * (Fighter.SEPARATION - l) * 0.5
			player.global_position -= push
			foe.global_position += push
	for f: Fighter in [player, foe]:
		_keep_inside(f)


## Nadie sale del patio ni atraviesa paredes o la jardinera, tampoco tumbado.
func _keep_inside(f: Fighter) -> void:
	var p := Arena.constrain(f.global_position, 0.32)
	var n: String = f.move.get("name", "")
	var lying := (n == "launch" and f.move_t > 0.25 and f.move_t < 1.7) or (n == "ko" and f.move_t > 0.25)
	if lying:
		# el cuerpo tumbado ocupa ~0,9 m hacia atrás (cabeza) y ~0,8 m hacia delante (pies)
		var back := f.global_transform.basis.z
		back.y = 0
		back = back.normalized()
		for tip_len in [0.95, -0.85]:
			var tip: Vector3 = p + back * tip_len
			var fixed := Arena.constrain(tip, 0.14)
			p += fixed - tip
		p = Arena.constrain(p, 0.32)
	elif n == "wall_splat" or n == "dazed":
		p = Arena.constrain(p, 0.4)
	f.global_position = Vector3(p.x, 0, p.z)


func _on_footstep(f: Fighter, strength: float) -> void:
	if phase == "menu":
		return
	Sfx.play("step", -22.0 + strength * 6.0, 1.0, 0.12)


func _on_whoosh(f: Fighter, kind: int) -> void:
	Sfx.play("whoosh_k" if kind >= 2 else "whoosh_p", -7.0 + kind * 2.0, 1.0 - kind * 0.05)
	# esfuerzo al golpear: grito en los golpes fuertes, soplido en los demás
	var who := "player" if f == player else "foe"
	var mv: String = f.move.get("name", "")
	if mv in ["spin_kick", "push_kick", "uppercut", "clinch_knee"]:
		Sfx.voice(who, "scream", -3.0, 0.4)
	elif f.string_n > 2 or randf() < 0.6:
		Sfx.voice(who, "effort", -6.0, 0.3)


func _on_wall(f: Fighter, point: Vector3, strength: float) -> void:
	Sfx.play("wall", 0.0)
	Sfx.play("syn_wall", -8.0)
	Sfx.voice("player" if f == player else "foe", "winded", -2.0, 0.1)
	Sfx.duck(-7.0, 0.5, 1.0)
	fx.dust(point, 20, 1.6)
	if FighterRig.blood_mode > 0:
		fx.wall_stain(point + Vector3.DOWN * 0.15, f.global_transform.basis.z, (0.4 + f.bleed * 0.8) * (0.5 if FighterRig.blood_mode == 1 else 1.0))
		f.bleed = minf(1.0, f.bleed + 0.25)
	fx.impact(point, Vector3.UP, 3, "hit")
	cam.add_trauma(0.55)
	cam.kick_fov(5.0)
	Haptics.play("wall", f == player)
	for rb in arena.props:
		var dd := rb.global_position.distance_to(f.global_position)
		if dd < 2.2:
			rb.apply_central_impulse((rb.global_position - f.global_position).normalized() * strength * 3.0 + Vector3.UP * 2.0)


func _on_ko(who: Fighter) -> void:
	_set_phase("ko")
	Engine.time_scale = 0.3
	slowmo_t = 1.1
	Sfx.play("ko", 0.0)
	Sfx.play("syn_ko", -8.0)
	Sfx.voice("player" if who == player else "foe", "pain", -2.0, 0.0, 0.85)
	Sfx.set_music("off", 1.2)
	cam.cinematic(who)
	Haptics.play("ko", who == player)
	touch.enabled = false
	touch.release_all()
	_attack_held = false
	_kick_held = false
	_guard_held = false





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
	Sfx.set_music("menu", 1.2)


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
	_rec.clear()
	cam.replay_mode = false
	cam.shot_t = -1.0
	for b in _bars:
		b.visible = false
	if _replay_label:
		_replay_label.visible = false
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
	_banner_show("NICO  vs  CENIZA", 1.3)
	Sfx.play("ui_tap", -6.0, 1.0, 0.0)
	Sfx.set_music("combat", 2.2)
	if not _shown_hint:
		_shown_hint = true
		_hint.text = "Machaca GOLPE para encadenar puños · PATADA en mitad de la serie la remata · Hacia el rival + PATADA: patada frontal · Atrás + GOLPE: empujón\nDEFENSA: mantener / justo a tiempo = parada · ESQUIVA: si el golpe te roza, ¡CONTRA!"
		_hint.modulate.a = 1.0
		var tw := create_tween()
		tw.tween_interval(8.0)
		tw.tween_property(_hint, "modulate:a", 0.0, 1.0)


func _show_result() -> void:
	_set_phase("result")
	_result_root.visible = true
	var won := foe.hp <= 0.0
	Sfx.play("win" if won else "lose", -2.0, 1.0, 0.0)
	Sfx.announcer("vo_victoria" if won else "vo_derrota", -1.0)
	Sfx.set_music("menu", 3.0)
	(_result_root.get_node("Title") as Label).text = "VICTORIA" if won else "DERROTA"
	(_result_root.get_node("Sub") as Label).text = "Ceniza ha caído." if won else "Nico ha caído."


func _toggle_pause() -> void:
	if phase != "fight" and phase != "intro":
		return
	paused = not paused
	_pause_root.visible = paused
	touch.release_all()
	_attack_held = false
	_kick_held = false
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
	touch.kick_down.connect(_on_kick_down)
	touch.kick_up.connect(_on_kick_up)
	touch.dodge_down.connect(_on_dodge_down)
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
	for k in 2:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0, 1)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_preset(Control.PRESET_TOP_WIDE if k == 0 else Control.PRESET_BOTTOM_WIDE)
		bar.custom_minimum_size = Vector2(0, 74)
		bar.size = Vector2(4000, 74)
		if k == 1:
			bar.position.y = -74
			bar.anchor_top = 1.0
			bar.anchor_bottom = 1.0
			bar.offset_top = -74
			bar.offset_bottom = 0
		else:
			bar.offset_bottom = 74
		bar.visible = false
		ui.add_child(bar)
		_bars.append(bar)
	_replay_label = _label("REPETICIÓN  ·  toca para saltar", 22, Color(1, 0.9, 0.8))
	_replay_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_replay_label.position = Vector2(40, -60)
	_replay_label.visible = false
	ui.add_child(_replay_label)
	_hint = _label("", 19, Color(1, 0.95, 0.88))
	_hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hint.position = Vector2(-560, 96)
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
	col.add_child(_label("Nico  vs  Ceniza  ·  Azotea del Farol", 28, Color(1, 1, 1)))
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
	_quality_btn = _button("", 20)
	_quality_btn.custom_minimum_size = Vector2(470, 48)
	_quality_btn.pressed.connect(func():
		high_quality = not high_quality
		_apply_quality()
		_update_quality_btn()
		_save_prefs()
		Sfx.play("ui_tap", -8.0, 1.0, 0.0))
	col.add_child(_quality_btn)
	_update_quality_btn()
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
	(_pause_root.get_node("Sub") as Label).text = "Teclado: WASD mover · J golpe · K patada · L defensa · Espacio esquiva · I remate"
	var pb := _pause_root.get_node("Box") as VBoxContainer
	var cont := _button("CONTINUAR", 28)
	cont.pressed.connect(_toggle_pause)
	pb.add_child(cont)
	var pm := _button("MENÚ", 24)
	pm.pressed.connect(_enter_menu)
	pb.add_child(pm)
	# ajustes del combate en vivo: para afinar la sensación jugando
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 6)
	grid.set_anchors_preset(Control.PRESET_CENTER)
	grid.position = Vector2(-330, 165)
	grid.size = Vector2(660, 220)
	_pause_root.add_child(grid)
	for t in TUNE:
		var key: String = t[1]
		var lab := _label(t[0], 18, Color(1, 0.9, 0.8))
		lab.custom_minimum_size = Vector2(210, 34)
		grid.add_child(lab)
		var sl := HSlider.new()
		sl.min_value = t[2]
		sl.max_value = t[3]
		sl.step = 0.05 if key != "buffer" else 0.01
		sl.value = tune[key]
		sl.custom_minimum_size = Vector2(320, 34)
		sl.focus_mode = Control.FOCUS_NONE
		grid.add_child(sl)
		var val := _label("%.2f" % tune[key], 18, Color(1, 0.8, 0.6))
		val.custom_minimum_size = Vector2(70, 34)
		grid.add_child(val)
		sl.value_changed.connect(func(v: float):
			tune[key] = v
			val.text = "%.2f" % v
			_apply_tune()
			_save_prefs())
	var reset := _button("Valores por defecto", 18)
	reset.pressed.connect(func():
		for t2 in TUNE:
			tune[t2[1]] = t2[4]
		_apply_tune()
		_save_prefs()
		for i in grid.get_child_count():
			var n := grid.get_child(i)
			if n is HSlider:
				(n as HSlider).value = TUNE[i / 3][4])
	pb.add_child(reset)
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
	box.position = Vector2(-180, -70)
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


func _update_quality_btn() -> void:
	_quality_btn.text = "Calidad gráfica: " + ("Alta" if high_quality else "Baja (móviles modestos)")


func _update_blood_btn() -> void:
	_blood_btn.text = "Sangre: " + ["Apagada", "Reducida", "Normal"][FighterRig.blood_mode]


func _load_prefs() -> void:
	var cf := ConfigFile.new()
	if cf.load(PREFS) == OK:
		FighterRig.blood_mode = int(cf.get_value("juego", "sangre", 2))
		difficulty = int(cf.get_value("juego", "dificultad", 1))
		high_quality = bool(cf.get_value("juego", "calidad_alta", true))
		for k in tune:
			tune[k] = float(cf.get_value("ajustes", k, tune[k]))
	_apply_tune()


func _apply_tune() -> void:
	Fighter.hitstop_scale = tune.hitstop
	game_speed = tune.speed
	CombatCamera.shake_scale = tune.shake
	Haptics.intensity = tune.haptics
	Fighter.BUFFER_TIME = tune.buffer
	_apply_quality()


## Calidad baja para móviles modestos: sombras más pequeñas, sin brillo,
## menos partículas y manchas, sin antialiasing.
func _apply_quality() -> void:
	ImpactFx.low_quality = not high_quality
	ImpactFx.MAX_STAINS = 90 if high_quality else 40
	RenderingServer.directional_shadow_atlas_set_size(4096 if high_quality else 2048, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_LOW if high_quality else RenderingServer.SHADOW_QUALITY_HARD)
	get_viewport().msaa_3d = Viewport.MSAA_2X if high_quality else Viewport.MSAA_DISABLED
	if arena and arena.env:
		arena.env.glow_enabled = high_quality


func _save_prefs() -> void:
	var cf := ConfigFile.new()
	cf.set_value("juego", "sangre", FighterRig.blood_mode)
	cf.set_value("juego", "dificultad", difficulty)
	cf.set_value("juego", "calidad_alta", high_quality)
	for k in tune:
		cf.set_value("ajustes", k, tune[k])
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
